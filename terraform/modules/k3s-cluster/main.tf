# Security group for k3s cluster
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
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # k3s API
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all internal traffic between nodes
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-k3s-sg"
    Environment = var.environment
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
  owners      = ["099720109477"] # Canonical

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
      --tls-san=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
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
    Environment = var.environment
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
    curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.private_ip}:6443 K3S_TOKEN=${random_password.k3s_token.result} sh -
  EOF

  depends_on = [aws_instance.k3s_master]

  tags = {
    Name        = "${var.project_name}-k3s-worker-${count.index + 1}"
    Environment = var.environment
    Role        = "worker"
  }
}
