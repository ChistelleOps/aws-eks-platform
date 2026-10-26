output "hosted_zone_id" {
  description = "Route 53 public hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "AWS nameservers to configure at IONOS"
  value       = aws_route53_zone.main.name_servers
}