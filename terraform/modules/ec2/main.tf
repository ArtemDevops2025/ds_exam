resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-${var.environment}-k3s-sg"
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

  # Allow all internal traffic within the security group
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
    Name        = "${var.project_name}-${var.environment}-k3s-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id              = var.public_subnet_ids[0]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-master"
    Environment = var.environment
    Project     = var.project_name
    Role        = "master"
  }
}

resource "aws_instance" "k3s_worker" {
  count                  = var.instance_count - 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-worker-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Role        = "worker"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#New
# Elastic IP for master node
resource "aws_eip" "k3s_master" {
  count    = var.create_elastic_ips ? 1 : 0
  domain   = "vpc"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-master-eip"
    Environment = var.environment
    Project     = var.project_name
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
  count    = var.create_elastic_ips ? var.worker_count : 0
  domain   = "vpc"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-worker-${count.index + 1}-eip"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate Elastic IPs with worker nodes
resource "aws_eip_association" "k3s_worker" {
  count         = var.create_elastic_ips ? var.worker_count : 0
  instance_id   = aws_instance.k3s_worker[count.index].id
  allocation_id = aws_eip.k3s_worker[count.index].id
}
