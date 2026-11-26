output "vpc_id" {
  description = "Shared VPC in the network account."
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "Shared subnets by environment and AZ index."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }
}
