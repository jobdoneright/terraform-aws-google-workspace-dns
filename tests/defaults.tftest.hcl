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

run "no_dkim_by_default" {
  command = plan

  assert {
    condition     = length(aws_route53_record.dkim) == 0
    error_message = "No DKIM record should be created without dkim_record."
  }
}

run "dkim_short_key" {
  command = plan

  variables {
    dkim_record   = "v=DKIM1; k=rsa; p=ABC123"
    dkim_selector = "gw"
  }

  assert {
    condition     = aws_route53_record.dkim[0].name == "gw._domainkey"
    error_message = "DKIM record name should use dkim_selector."
  }

  assert {
    condition     = aws_route53_record.dkim[0].records == toset(["v=DKIM1; k=rsa; p=ABC123"])
    error_message = "Short DKIM value should not be split."
  }
}

run "dkim_long_key_is_split" {
  command = plan

  variables {
    dkim_record = "v=DKIM1; k=rsa; p=${join("", [for i in range(40) : "ABCDEFGHIJ"])}"
  }

  assert {
    condition = aws_route53_record.dkim[0].records == toset([
      "v=DKIM1; k=rsa; p=${join("", [for i in range(23) : "ABCDEFGHIJ"])}ABCDEFG\"\"HIJ${join("", [for i in range(16) : "ABCDEFGHIJ"])}"
    ])
    error_message = "DKIM value over 255 characters should be split into 255-character chunks."
  }
}

run "dkim_rejects_invalid_value" {
  command = plan

  variables {
    dkim_record = "p=ABC123"
  }

  expect_failures = [var.dkim_record]
}
