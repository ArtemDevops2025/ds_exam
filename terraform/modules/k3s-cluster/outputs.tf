
output "master_private_ip" {
  description = "Private IP of the k3s master node"
  value       = aws_instance.k3s_master.private_ip
}


output "worker_private_ips" {
  description = "Private IPs of the k3s worker nodes"
  value       = aws_instance.k3s_worker[*].private_ip
}

output "k3s_token" {
  description = "k3s token"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig from master node"
  value       = "ssh -i YOUR_KEY_PATH ubuntu@${aws_instance.k3s_master.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' > kubeconfig.yaml && sed -i 's/127.0.0.1/${aws_instance.k3s_master.public_ip}/g' kubeconfig.yaml"
}


#my commands to ssh  ----------------------------!!!!!!
output "kubeconfig_instructions" {
  description = "Instructions for setting up kubeconfig"
  value       = <<-EOT
    To set up your kubeconfig:
    
    1. Run the command above, replacing YOUR_KEY_PATH with your SSH key file path
    2. Export the kubeconfig: export KUBECONFIG=$(pwd)/kubeconfig.yaml
    3. Verify connection: kubectl get nodes
  EOT
}

output "k3s_master_ssh_command" {
  description = "Command to SSH into the k3s master node"
  value       = "ssh -i YOUR_KEY_PATH ubuntu@${aws_instance.k3s_master.public_ip}"
}


#NEW Elastic IP
output "master_public_ip" {
  description = "Public IP of the K3s master node"
  value       = var.create_elastic_ips ? aws_eip.k3s_master[0].public_ip : aws_instance.k3s_master.public_ip  # Updated resource name
}

output "worker_public_ips" {
  description = "Public IPs of the K3s worker nodes"
  value       = var.create_elastic_ips ? aws_eip.k3s_worker[*].public_ip : aws_instance.k3s_worker[*].public_ip
}
