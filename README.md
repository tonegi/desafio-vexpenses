# Desafio VExpenses - Terraform

Este projeto utiliza o Terraform para provisionar e configurar uma infraestrutura básica na AWS, criando uma instância EC2 Debian, com uma VPC, sub-rede, gateway de internet, grupos de segurança e outros recursos de rede. A seguir, uma explicação detalhada de todos os componentes configurados.

## Requisitos
- Conta AWS com permissões para criar VPC, sub-rede, EC2, gateway de internet, etc.
- Terraform instalado.

## Descrição Geral
O código provisiona uma infraestrutura na região `us-east-1` da AWS com os seguintes componentes:
- **VPC**: Rede virtual para isolar a instância EC2.
- **Sub-rede**: Rede específica dentro da VPC.
- **Internet Gateway**: Permite o tráfego de entrada/saída da Internet.
- **Tabela de Rotas**: Define a rota para a Internet.
- **Grupo de Segurança**: Controla as regras de tráfego para a instância EC2.
- **Instância EC2 Debian**: Uma máquina virtual que roda Debian 12.
- **Chave SSH**: Par de chaves para acesso seguro à instância EC2.

## Componentes

### Provedor AWS
O código define o provedor AWS na região `us-east-1`, localizada no Norte da Virgínia:
```hcl
provider "aws" {
  region = "us-east-1"
}
```

### Variáveis
O código define duas variáveis para a identificação dos recursos:
- `projeto`: Nome do projeto (padrão: `"VExpenses"`).
- `candidato`: Nome do candidato/usuário (padrão: `"SeuNome"`).

```hcl
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}
```
### Chave Privada
Cria uma chave privada de 2048 bits que será usada para acessar a instância EC2 através de acesso remoto:

```hcl
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
```

### Par de Chaves
O par de chaves é gerado usando a chave pública derivada da chave privada criada anteriormente:

```hcl
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}
```

### VPC 
Criação de uma versão virtual de uma rede física:

```hcl
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}
```

### Sub-rede
Criação da sub-rede dentro da VPC:

```hcl
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
```

### Gateway
Configuração do tráfego de entrada e saída de rede do VPC para a internet:

```hcl
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}
```

### Route Table
Cria uma rota que faz o controle de direcionamento para determinados destinos de rede:

```hcl
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
```
### Associação da Route Table
Realiza a assoiação da route table às sub-redes, permitindo-as o devido acesso à internet:

```hcl
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}
```

### Security Group
Criação de um grupo de segurança no qual permite o acesso remoto pela porta convencional 22 e atuando no tráfego de saída do EC2:

```hcl
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH de qualquer lugar e todo o tráfego de saída"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}
```

AMI
Configura a AMI com o Debian 12, utilizando seu ID específico:

```hcl
data "aws_ami" "debian12" {
  most_recent = true
  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
  owners = ["679593333241"]
}
```

### Instância EC2
Provisona uma instância EC2 t2.micro utilizando a AMI do Debian 12 e associando o grupo de segurança, par de chaves e sub-rede configurados. Além disso, associa um endereço IP público e define um script de inicialização para atualizar a máquina:

```hcl
resource "aws_instance" "debian_ec2" {
  ami           = data.aws_ami.debian12.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id
  key_name      = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
```

### Output
Exibe a chave privada gerada e o endereço de IP público do EC2:

```hcl
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
```

## Modificação e Melhoria do Código Terraform 

### 1. Alteração no valor da variável `candidato`

```hcl
variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "RafaelTonegi"
}
```

### 2. Remoção do IP público
Realizada a alteração no valor booleano em `associate_public_ip_address` de `true` para `false`. 

```hcl 
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = false 

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }
```

Assim, para permitir a conexão à internet, foi alterado o valor em `map_public_ip_on_launch`, permitindo a conexão através da sub-rede

```hcl
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true 

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
```

