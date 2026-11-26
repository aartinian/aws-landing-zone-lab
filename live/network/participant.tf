# proof that the share works: workload-dev creates its own security group and an ENI in a
# shared dev subnet. Here only to keep it in one PR; in a real setup the workload root reads
# the subnet ID itself (NTC Parameters, SSM), because it can't see the owner's tags.
resource "aws_security_group" "proof" {
  provider = aws.workload_dev

  name        = "shared-vpc-proof"
  description = "Participant-owned security group in the shared VPC"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  depends_on = [aws_ram_principal_association.subnets, aws_ram_resource_association.subnets]
}

resource "aws_network_interface" "proof" {
  provider = aws.workload_dev

  description     = "shared VPC proof (no instance attached)"
  subnet_id       = aws_subnet.this["dev-0"].id
  security_groups = [aws_security_group.proof.id]
}
