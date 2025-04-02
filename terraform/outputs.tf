output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# Output the connection information
output "k3s_master_ip" {
  value = module.k3s_cluster.master_public_ip
}

output "k3s_worker_ips" {
  value = module.k3s_cluster.worker_public_ips
}

output "kubeconfig_command" {
  value = module.k3s_cluster.kubeconfig_command
}

/*
output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = module.ec2.instance_ids
}

output "instance_public_ips" {
  description = "Public IPs of EC2 instances"
  value       = module.ec2.instance_public_ips
}
*/

