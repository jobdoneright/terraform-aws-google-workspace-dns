mock_provider "aws" {}

variables {
  dns_zone = "example.com"
}

run "defaults" {
  command = plan

  assert {
    condition     = aws_route53_zone.this.name == "example.com"
    error_message = "Zone name should match dns_zone."
  }

  assert {
    condition     = length(aws_route53_record.mx.records) == 5
    error_message = "Default MX set should have five records."
  }

  assert {
    condition     = toset(keys(aws_route53_record.cname)) == toset(["mail", "cal", "docs"])
    error_message = "Default CNAMEs should be mail, cal and docs."
  }
}

run "custom_records" {
  command = plan

  variables {
    gsuite_cnames = ["mail"]
    mx_records    = ["1 SMTP.GOOGLE.COM."]
    ttl           = 300
  }

  assert {
    condition     = aws_route53_record.mx.records == toset(["1 SMTP.GOOGLE.COM."])
    error_message = "MX records should be overridable."
  }

  assert {
    condition     = keys(aws_route53_record.cname) == ["mail"] && aws_route53_record.cname["mail"].ttl == 300
    error_message = "CNAME list and TTL should be overridable."
  }
}
