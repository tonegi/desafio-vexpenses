# Desafio VExpenses - Terraform

O desafio tem como objetivo a configuração de uma infraestrutura da AWS, criando uma instância EC2 utilizando Debian e com uma VPC, uma sub-rede, um gateway, um security group e a possibilidade de acesso remoto.

## Requisitos
- Conta AWS.
- Terraform.

## Análise Técnica do Código Terraform

### Provedor AWS
Define-se o provedor AWS na região `us-east-1`, localizada no Norte da Virgínia:
```hcl
provider "aws" {
  region = "us-east-1"
}
```

### Variáveis
É estabelecido a utilização de duas variáveis para a identificação dos recursos:
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
Criação de uma chave privada de 2048 bits que será usada para acessar a instância EC2 remotamente:

```hcl
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
```

### Par de Chaves
O par de chaves é gerado usando a chave pública proveniente da chave privada criada anteriormente:

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

### AMI
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
Cria-se uma instância EC2 t2.micro utilizando a imagem do Debian e se associando ao security group, ao par de chaves e à sub-rede em que estão configurados. Além disso, associa um endereço IP público e é definido um script de inicialização para atualizar a máquina:

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

Assim, foi alterado o valor em `map_public_ip_on_launch`, permitindo a conexão através da sub-rede

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
### 3. Criação de sub-redes em outras zonas de disponibilizade
Considerando a possibilidade de oscilação na zonas de disponibilidade, cria-se sub-redes em outras disposições; sendo essas a `us-east-1b` e `us-east-1c`.

```hcl
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
```
### 4. Criação de novas regras de entrada 
Em relação à versão anterior, a regra de entrada permitia o acesso remoto provindo de qualquer IP e utilizando a porta de SSH padrão, facilitando a possibilidade de uma intrusão. Assim, foi alterada a porta de entrada para uma não-convencional, assim como - sendo apenas um exemplo - a permissão de acesso vindo do meu IP; além de utilizar a máscara de sub-rede `/128` que oferece acesso apenas ao meu específico endereço.

```hcl
 ingress {
    description      = "Allow SSH from specific location"
    from_port        = 6000 # Mudança na porta de entrada
    to_port          = 6000 # Mudança na porta de saída
    protocol         = "tcp"
    cidr_blocks      = ["177.140.144.245/128"] # Inibição da conexão de qualquer IPv4 
    ipv6_cidr_blocks = ["2804:14c:123:9fba:e5ea:4e49:8a54:43fc/128"] # Inibição da conexão de qualquer IPv6
  }
```

Aqui, seguindo a mesma lógica, filtrou a regra de entrada para conexões à internet ao permitir acesso às portas HTTP e HTTPS.

```hcl

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
```
### 5. Criação de novas regras de saída 
Assim como nas regras de entrada, filtra-se a possibilidade da saída de dados para qualquer outra porta ou IP.

```hcl
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
```

### 6. Instalação no Nginx e do Fail2Ban
Foi configurada a instalação do Nginx na instância EC2 e, visando uma maior segurança contra ataques de brute force, a instalação do Fail2Ban no `user_data`.

```hcl
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
```

### Acesso ao arquivo modificado
[Código Modificado](modificado.tf)


  ## Utilização

1. Clone este repositório:
```bash
git clone https://github.com/tonegi/desafio-vexpenses.git
cd desafio-vexpenses
```

2. Inicie o Terraform:
```bash
terraform init
```

3. Visualize e aplique o plano de execução:

```bash
terraform plan
terraform apply
```

4. Confirme a criação e digitando `yes` quando solicitado.
Após a conclusão, o Terraform mostrará a `private_key` e o `ec2_public_ip`

### Acesso ao EC2
1. Para acessar o EC2, copie o IP público supracitado:
```bash
terraform output xxx.xxx.xxx.xxx/xxx
```

2. Salve a chave privada fornecida pelo Terraform:
```bash
echo "$(terraform output sua_chave)" > chave.pem
chmod 400 chave.pem
```

3. Conecte-se à instância via SSH:
```bash
ssh -i chave.pem admin@<ip_do_EC2>
```
