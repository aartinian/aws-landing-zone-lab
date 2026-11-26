output "vpc_id" {
  description = "Shared VPC in the network account."
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "Shared subnets by environment and AZ index."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }
}

output "proof_eni_ip" {
  description = "Private IP of the participant ENI in workload-dev (from the nonprod pool)."
  value       = aws_network_interface.proof.private_ip
}
