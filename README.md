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
### Geração da Chave Privada
Cria uma chave privada de 2048 bits que será usada para acessar a instância EC2 através de acesso remoto:

```hcl
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
```

### Par de Chaves AWS
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

### Internet Gateway
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
