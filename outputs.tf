output "r53_zone_id" {
  description = "ID of the Route53 hosted zone."
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Name servers to delegate the domain to at the registrar."
  value       = aws_route53_zone.this.name_servers
}
