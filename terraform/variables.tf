variable "aws_region" {
  description = "Região AWS utilizada pelo projeto"
  type        = string
  default     = "us-east-1"
}
variable "db_name" {
  description = "Nome do banco PostgreSQL"
  type        = string
  default     = "agendamento_consultas"
}

variable "db_username" {
  description = "Usuario do banco PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha do banco PostgreSQL"
  type        = string
  sensitive   = true
}