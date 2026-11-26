# S3 gateway endpoint: free, private access to S3 for everything in the shared VPC (no NAT, no
# internet). It changes the owner's route table, so only the network account can add it.
data "aws_iam_policy_document" "s3_endpoint" {
  # data perimeter: only buckets of this organization are reachable through the endpoint
  statement {
    actions   = ["s3:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceOrgID"
      values   = [data.aws_organizations_organization.this.id]
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  provider = aws.network

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.this.main_route_table_id] # the subnets use the main table
  policy            = data.aws_iam_policy_document.s3_endpoint.json

  tags = { Name = "s3" }
}
