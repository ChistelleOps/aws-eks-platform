resource "aws_route53_zone" "main" {
  name = "christelconsult.com"

  tags = {
    Name = "christelconsult.com"
  }
}
resource "aws_acm_certificate" "main" {
  domain_name               = "christelconsult.com"
  subject_alternative_names = ["*.christelconsult.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "christelconsult.com"
  }
}
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn

  validation_record_fqdns = [
    for record in aws_route53_record.acm_validation :
    record.fqdn
  ]
}

# Find the ALB created by the AWS Load Balancer Controller
data "aws_lb" "platform_public" {
  tags = {
    "ingress.k8s.aws/stack" = "platform-public"
  }
}

# DNS records for applications running on EKS
resource "aws_route53_record" "platform_apps" {
  for_each = toset([
    "api",
    "www"
  ])

  zone_id = aws_route53_zone.main.zone_id
  name    = "${each.key}.christelconsult.com"
  type    = "A"

  alias {
    name                   = data.aws_lb.platform_public.dns_name
    zone_id                = data.aws_lb.platform_public.zone_id
    evaluate_target_health = true
  }
}

