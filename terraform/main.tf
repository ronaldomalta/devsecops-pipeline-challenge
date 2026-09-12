# =========================
# IDENTIDADE AWS
# =========================
data "aws_caller_identity" "current" {}

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
# EC2
# =========================
resource "aws_instance" "api" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.api_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  monitoring    = true
  ebs_optimized = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "devsecops-api-server"
  }
}

# =========================
# KMS DO RDS
# =========================
resource "aws_kms_key" "rds" {
  description         = "Chave KMS para criptografia do RDS e CloudWatch"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"

        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }

        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]

        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "devsecops-rds-kms"
  }
}

# =========================
# PARAMETER GROUP POSTGRESQL
# =========================
resource "aws_db_parameter_group" "postgres" {
  name   = "devsecops-postgres-params"
  family = "postgres16"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name = "devsecops-postgres-params"
  }
}

# =========================
# IAM ROLE MONITORAMENTO RDS
# =========================
resource "aws_iam_role" "rds_monitoring" {
  name = "devsecops-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "devsecops-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# =========================
# GRUPO DE SUBNETS DO RDS
# =========================
resource "aws_db_subnet_group" "postgres" {
  name = "devsecops-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  tags = {
    Name = "devsecops-db-subnet-group"
  }
}

# =========================
# POSTGRESQL - RDS
# =========================
resource "aws_db_instance" "postgres" {
  identifier = "devsecops-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 30

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  port = 5432

  db_subnet_group_name = aws_db_subnet_group.postgres.name

  vpc_security_group_ids = [
    aws_security_group.db_sg.id
  ]

  parameter_group_name = aws_db_parameter_group.postgres.name

  publicly_accessible = false

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  multi_az            = true
  deletion_protection = true

  auto_minor_version_upgrade = true

  backup_retention_period = 7

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  iam_database_authentication_enabled = true

  copy_tags_to_snapshot = true

  skip_final_snapshot = true

  tags = {
    Name = "devsecops-postgres"
  }
}

# =========================
# CLOUDWATCH - VPC FLOW LOGS
# =========================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name = "/aws/vpc/devsecops-flow-logs"

  # Checkov exige retenção de pelo menos 1 ano
  retention_in_days = 365

  kms_key_id = aws_kms_key.rds.arn

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