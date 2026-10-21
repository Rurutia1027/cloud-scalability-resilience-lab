data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  admin_cidr = "${chomp(data.http.myip.response_body)}/32"
}

resource "aws_security_group" "lab" {
  name        = "${var.name_prefix}-sg"
  description = "SSH, Grafana, and the product gateway from the operator address"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.admin_cidr]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [local.admin_cidr]
  }

  ingress {
    description = "productservice via the compose gateway"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [local.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

resource "tls_private_key" "lab" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "lab" {
  key_name   = "${var.name_prefix}-key"
  public_key = tls_private_key.lab.public_key_openssh
}

resource "local_sensitive_file" "key" {
  filename        = "${path.module}/lab-key.pem"
  content         = tls_private_key.lab.private_key_openssh
  file_permission = "0400"
}

resource "aws_instance" "lab" {
  depends_on = [aws_route_table_association.lab]

  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.lab.id
  vpc_security_group_ids      = [aws_security_group.lab.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf install -y docker
    systemctl enable --now docker
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
      https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    usermod -aG docker ec2-user
    install -d -o ec2-user -g ec2-user /opt/docker-assignment
  EOF

  tags = {
    Name = var.name_prefix
  }
}

resource "null_resource" "deploy" {
  depends_on = [aws_instance.lab, local_sensitive_file.key]

  triggers = {
    instance_id = aws_instance.lab.id
    compose     = filemd5("${path.module}/../docker/docker-compose.yml")
    watcher     = filemd5("${path.module}/../bin/scale-watch.sh")
    bootstrap   = filemd5("${path.module}/../bin/bootstrap-remote.sh")
  }

  connection {
    type        = "ssh"
    host        = aws_instance.lab.public_ip
    user        = "ec2-user"
    private_key = tls_private_key.lab.private_key_openssh
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "for i in $(seq 1 30); do sudo docker info >/dev/null 2>&1 && exit 0; sleep 10; done; echo 'docker did not start' >&2; exit 1",
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      rsync -az \
        -e "ssh -i ${local_sensitive_file.key.filename} -o StrictHostKeyChecking=accept-new" \
        --exclude .git \
        --exclude tf/.terraform \
        --exclude 'tf/terraform.tfstate*' \
        --exclude tf/lab-key.pem \
        --exclude '**/target' \
        ${path.module}/../ ec2-user@${aws_instance.lab.public_ip}:/opt/docker-assignment/
    EOT
  }

  provisioner "remote-exec" {
    inline = [
      "sudo /opt/docker-assignment/bin/bootstrap-remote.sh",
    ]
  }
}
