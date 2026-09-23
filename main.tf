resource "aws_route53_zone" "this" {
  name = var.dns_zone
  tags = var.tags
}

resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.this.zone_id
  name    = ""
  type    = "MX"
  ttl     = var.ttl
  records = var.mx_records
}

resource "aws_route53_record" "cname" {
  for_each = toset(var.gsuite_cnames)

  zone_id = aws_route53_zone.this.zone_id
  name    = each.key
  type    = "CNAME"
  ttl     = var.ttl
  records = ["ghs.googlehosted.com"]
}

# Route53 limits each TXT string to 255 characters. A 2048-bit key is longer,
# so split it into chunks joined by `""`, which Route53 stores as one value.
resource "aws_route53_record" "dkim" {
  count = var.dkim_record == null ? 0 : 1

  zone_id = aws_route53_zone.this.zone_id
  name    = "${var.dkim_selector}._domainkey"
  type    = "TXT"
  ttl     = var.ttl
  records = [join("\"\"", regexall(".{1,255}", var.dkim_record))]
}

# Upgrade path from the pre-1.0 resource addresses. The CNAME moves cover the
# default gsuite_cnames list; custom lists need `terraform state mv`.
moved {
  from = aws_route53_zone.dns_zone
  to   = aws_route53_zone.this
}

moved {
  from = aws_route53_record.gmail_mx
  to   = aws_route53_record.mx
}

moved {
  from = aws_route53_record.gsuite_cnames[0]
  to   = aws_route53_record.cname["mail"]
}

moved {
  from = aws_route53_record.gsuite_cnames[1]
  to   = aws_route53_record.cname["cal"]
}

moved {
  from = aws_route53_record.gsuite_cnames[2]
  to   = aws_route53_record.cname["docs"]
}
