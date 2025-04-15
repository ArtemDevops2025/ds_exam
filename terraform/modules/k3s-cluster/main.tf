# Security group for k3s cluster
locals {
  resource_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-k3s-sg"
  description = "Security group for k3s cluster"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # k3s API
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "K3s API server"
  }

  # NodePort services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NodePort Services"
  }

  # ICMP (ping)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ping"
  }

  # Allow all internal traffic between nodes
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Allow all traffic between cluster nodes"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-k3s-sg"
  }
}

# Generate random token for k3s
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create master node
resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id              = var.subnet_ids[0]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    # Install required packages
    apt-get update
    apt-get install -y curl unzip

    # Install k3s
    curl -sfL https://get.k3s.io | sh -s - server \
      --token=${random_password.k3s_token.result} \
      --disable=traefik \
      --tls-san=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) \
      --cluster-domain=${var.environment}.local \
      --node-label=environment=${var.environment}
    
    # Wait for k3s to be ready
    until kubectl get nodes; do
      echo "Waiting for k3s to be ready..."
      sleep 5
    done
    
    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    
    # Save kubeconfig for remote access
    mkdir -p /home/ubuntu/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
    sed -i "s/127.0.0.1/$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/g" /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube
  EOF

  tags = {
    Name        = "${var.project_name}-k3s-master"
    Role        = "master"
  }
}

# Create worker nodes
resource "aws_instance" "k3s_worker" {
  count                  = var.node_count > 1 ? var.node_count - 1 : 0
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    # Install required packages
    apt-get update
    apt-get install -y curl
    
    # Install k3s agent
    curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.private_ip}:6443 K3S_TOKEN=${random_password.k3s_token.result} sh -s - --node-label=environment=${var.environment}

    # Create environment marker
    echo "${var.environment}" > /home/ubuntu/environment.txt

  EOF

  depends_on = [aws_instance.k3s_master]

  tags = {
    Name        = "${var.project_name}-k3s-worker-${count.index + 1}"
    Role        = "worker"
  }
}

# Elastic IP for master node
resource "aws_eip" "k3s_master" {
  count    = var.create_elastic_ips ? 1 : 0
  domain   = "vpc"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-master-eip"
  }
}

# Associate Elastic IP with master node
resource "aws_eip_association" "k3s_master" {
  count         = var.create_elastic_ips ? 1 : 0
  instance_id   = aws_instance.k3s_master.id
  allocation_id = aws_eip.k3s_master[0].id
}

# Elastic IPs for worker nodes
resource "aws_eip" "k3s_worker" {
  count    = var.create_elastic_ips ? var.node_count - 1 : 0
  domain   = "vpc"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-worker-${count.index + 1}-eip"
  }
}

# Associate Elastic IPs with worker nodes
resource "aws_eip_association" "k3s_worker" {
  count         = var.create_elastic_ips ? var.node_count - 1 : 0
  instance_id   = aws_instance.k3s_worker[count.index].id
  allocation_id = aws_eip.k3s_worker[count.index].id
}
