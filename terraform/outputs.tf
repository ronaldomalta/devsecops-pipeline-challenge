output "ec2_public_ip" {
  description = "IP publico da instancia EC2 da API"
  value       = aws_instance.api.public_ip
}

output "ec2_public_dns" {
  description = "DNS publico da instancia EC2 da API"
  value       = aws_instance.api.public_dns
}

output "api_url" {
  description = "URL da API"
  value       = "http://${aws_instance.api.public_ip}:3000"
}
