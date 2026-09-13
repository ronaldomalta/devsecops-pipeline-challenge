# =========================
# VPC
# =========================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "devsecops-vpc"
  }
}

# =========================
# SUBNET PÚBLICA
# =========================
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "devsecops-public-subnet"
  }
}

# =========================
# SUBNET PRIVADA 1
# =========================
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "devsecops-private-subnet-1"
  }
}

# =========================
# SUBNET PRIVADA 2
# =========================
resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "devsecops-private-subnet-2"
  }
}

# =========================
# INTERNET GATEWAY
# =========================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devsecops-igw"
  }
}

# =========================
# ROUTE TABLE PÚBLICA
# =========================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "devsecops-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# =========================
# DEFAULT SECURITY GROUP
# =========================
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devsecops-default-sg"
  }
}

# =========================
# SECURITY GROUP DA API
# =========================
resource "aws_security_group" "api_sg" {
  name        = "devsecops-api-sg"
  description = "Security Group da API Node.js"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Acesso a API na porta 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida HTTPS para atualizacoes"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-api-sg"
  }
}

# =========================
# SECURITY GROUP DO BANCO
# =========================
resource "aws_security_group" "db_sg" {
  name        = "devsecops-db-sg"
  description = "Security Group do PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL somente pela EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api_sg.id]
  }

  tags = {
    Name = "devsecops-db-sg"
  }
}

# =========================
# IAM ROLE DA EC2
# =========================
resource "aws_iam_role" "ec2_role" {
  name = "devsecops-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "devsecops-ec2-role"
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devsecops-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# =========================
# EC2 (SIMPLIFICADA PARA LOCALSTACK)
# =========================
resource "aws_instance" "api" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.api_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "devsecops-api-server"
  }
}

# =========================
# CLOUDWATCH - VPC FLOW LOGS
# =========================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/devsecops-flow-logs"
  retention_in_days = 365

  tags = {
    Name = "devsecops-vpc-flow-logs"
  }
}

# =========================
# IAM ROLE - VPC FLOW LOGS
# =========================
resource "aws_iam_role" "vpc_flow_logs" {
  name = "devsecops-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "devsecops-vpc-flow-logs-role"
  }
}

# =========================
# POLICY - VPC FLOW LOGS
# =========================
resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "devsecops-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "WriteVPCFlowLogs"
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      },
      {
        Sid    = "DescribeLogStreams"
        Effect = "Allow"

        Action = [
          "logs:DescribeLogStreams"
        ]

        Resource = aws_cloudwatch_log_group.vpc_flow_logs.arn
      },
      {
        Sid    = "DescribeLogGroups"
        Effect = "Allow"

        Action = [
          "logs:DescribeLogGroups"
        ]

        Resource = "*"
      }
    ]
  })
}

# =========================
# VPC FLOW LOG
# =========================
resource "aws_flow_log" "main" {
  vpc_id = aws_vpc.main.id

  traffic_type = "ALL"

  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn

  iam_role_arn = aws_iam_role.vpc_flow_logs.arn

  tags = {
    Name = "devsecops-vpc-flow-log"
  }
}


