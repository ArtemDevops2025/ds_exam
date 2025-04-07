output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = concat([aws_instance.k3s_master.id], aws_instance.k3s_worker[*].id)
}

output "instance_public_ips" {
  description = "Public IPs of EC2 instances"
  value       = concat([aws_instance.k3s_master.public_ip], aws_instance.k3s_worker[*].public_ip)
}

output "master_public_ip" {
  description = "Public IP of the k3s master node"
  value       = aws_instance.k3s_master.public_ip
}

output "master_private_ip" {
  description = "Private IP of the k3s master node"
  value       = aws_instance.k3s_master.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of the k3s worker nodes"
  value       = aws_instance.k3s_worker[*].public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.k3s.id
}


#New

output "master_public_ip" {
  description = "Public IP of the K3s master node"
  value       = var.create_elastic_ips ? aws_eip.k3s_master[0].public_ip : aws_instance.k3s_master.public_ip
}

output "worker_public_ips" {
  description = "Public IPs of the K3s worker nodes"
  value       = var.create_elastic_ips ? aws_eip.k3s_worker[*].public_ip : aws_instance.k3s_worker[*].public_ip
}
