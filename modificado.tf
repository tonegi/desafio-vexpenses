provider "aws" {
  region = "us-east-1"
}

variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "RafaelTonegi"
}

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true # Permitindo conexão à internet através da sub-rede

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}

# Criação de sub-redes em outras zonas de disponibilidade
resource "aws_subnet" "main_subnet_b" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24" # Mudança na sub-rede
  availability_zone = "us-east-1b" # Mudança na zona de disponibilidade

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet-b"
  }
}

resource "aws_subnet" "main_subnet_c" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24" # Mudança na sub-rede
  availability_zone = "us-east-1c" # Mudança na zona de disponibilidade

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet-c"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}

resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH de um IP específico e somente tráfego de saída HTTP e HTTPS"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada
  ingress {
    description      = "Allow SSH from specific location"
    from_port        = 6000 # Mudança na porta de entrada
    to_port          = 6000 # Mudança na porta de saída
    protocol         = "tcp"
    cidr_blocks      = ["177.140.144.245/128"] # Inibição da conexão de qualquer IPv4 
    ipv6_cidr_blocks = ["2804:14c:123:9fba:e5ea:4e49:8a54:43fc/128"] # Inibição da conexão de qualquer IPv6
  }

  ingress {
  description      = "Allow HTTP traffic"
  from_port        = 80 # Permitir acesso à Internet
  to_port          = 80 # Permitir acesso à Internet
  protocol         = "tcp"
  cidr_blocks      = ["0.0.0.0/0"]  
}

ingress {
  description      = "Allow HTTPS traffic"
  from_port        = 443 # Permitir acesso à internet
  to_port          = 443 # Permitir acesso à internet
  protocol         = "tcp"
  cidr_blocks      = ["0.0.0.0/0"]  
}

  # Regras de saída
egress {
    description      = "Allow HTTP outbound"
    from_port        = 80 # Permitir acesso à internet
    to_port          = 80 # Permitir acesso à internet
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

egress {
    description      = "Allow HTTPS outbound"
    from_port        = 443 # Permitir acesso à internet
    to_port          = 443 # Permitir acesso à internet
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}

data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}

resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = false 
  # Retirada do IP público. Mudança no valor booleano

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install fail2ban # Instalação Fail2Ban
              apt-get install nginx -y # Instalação do Nginx
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
