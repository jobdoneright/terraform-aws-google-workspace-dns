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

# The SPF and DMARC records below are named by fully-qualified domain name,
# while the MX, CNAME and DKIM records above use names relative to the zone.
# Both forms resolve to the same record, but aws_route53_record.name forces
# replacement when it changes, so neither convention can be switched without
# destroying and recreating the record. Each is left as it was first published.

# SPF and any other apex TXT values share one record set: Route53 holds a single
# TXT record set per name, so a value left out here is deleted from the zone.
resource "aws_route53_record" "apex_txt" {
  count = var.spf_record == null && length(var.extra_apex_txt) == 0 ? 0 : 1

  zone_id = aws_route53_zone.this.zone_id
  name    = var.dns_zone
  type    = "TXT"
  ttl     = var.ttl
  records = concat(var.spf_record == null ? [] : [var.spf_record], var.extra_apex_txt)

  allow_overwrite = var.allow_overwrite
}

# Tag order follows RFC 7489 section 6.3: v first, p second, the rest in any
# order. Receivers that only read the first two tags still get a valid policy.
#
# The coalesce is only to keep this local evaluable when dmarc_policy is null;
# the record it feeds does not exist in that case.
locals {
  dmarc_record = join("; ", concat(
    ["v=DMARC1", "p=${coalesce(var.dmarc_policy, "none")}"],
    var.dmarc_subdomain_policy == null ? [] : ["sp=${var.dmarc_subdomain_policy}"],
    var.dmarc_alignment_dkim == null ? [] : ["adkim=${var.dmarc_alignment_dkim}"],
    var.dmarc_alignment_spf == null ? [] : ["aspf=${var.dmarc_alignment_spf}"],
    var.dmarc_pct == null ? [] : ["pct=${var.dmarc_pct}"],
    length(var.dmarc_rua) == 0 ? [] : ["rua=${join(",", var.dmarc_rua)}"],
    length(var.dmarc_ruf) == 0 ? [] : ["ruf=${join(",", var.dmarc_ruf)}"],
  ))
}

resource "aws_route53_record" "dmarc" {
  count = var.dmarc_policy == null ? 0 : 1

  zone_id = aws_route53_zone.this.zone_id
  name    = "_dmarc.${var.dns_zone}"
  type    = "TXT"
  ttl     = var.ttl
  records = [local.dmarc_record]

  allow_overwrite = var.allow_overwrite
}

# RFC 7489 section 7.1 external destination verification. Reports for another
# domain reach a mailbox in this zone only if this zone authorises that domain.
resource "aws_route53_record" "dmarc_report_authorisation" {
  for_each = toset(var.dmarc_report_authorisations)

  zone_id = aws_route53_zone.this.zone_id
  name    = "${each.key}._report._dmarc.${var.dns_zone}"
  type    = "TXT"
  ttl     = var.ttl
  records = ["v=DMARC1"]

  allow_overwrite = var.allow_overwrite
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
