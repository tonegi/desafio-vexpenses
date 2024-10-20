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
O código define o provedor AWS na região `us-east-1`:
```hcl
provider "aws" {
  region = "us-east-1"
}
