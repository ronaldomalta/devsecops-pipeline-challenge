# =========================
# VPC
# =========================
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

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
  map_public_ip_on_launch = true

  tags = {
    Name = "devsecops-public-subnet"
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
# ROUTE TABLE
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
# SECURITY GROUP DA API
# =========================
resource "aws_security_group" "api_sg" {
  name        = "devsecops-api-sg"
  description = "Security Group da API Node.js"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Acesso HTTP na porta 3000"
    from_port   = 3000
    to_port     = 3000
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
    Name = "devsecops-api-sg"
  }
}

# =========================
# EC2
# =========================
resource "aws_instance" "api" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.api_sg.id]

  tags = {
    Name = "devsecops-api-server"
  }
}
# =========================
# SUBNET PRIVADA 1
# =========================
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "devsecops-private-subnet-1"
  }
}

# =========================
# SUBNET PRIVADA 2
# =========================
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "devsecops-private-subnet-2"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-db-sg"
  }
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

  publicly_accessible = false
  storage_encrypted   = true

  backup_retention_period = 7

  skip_final_snapshot = true

  tags = {
    Name = "devsecops-postgres"
  }
}