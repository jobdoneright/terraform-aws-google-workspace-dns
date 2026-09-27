mock_provider "aws" {}

variables {
  dns_zone = "example.com"
}

run "no_apex_txt_by_default" {
  command = plan

  assert {
    condition     = length(aws_route53_record.apex_txt) == 0
    error_message = "No apex TXT record should be created without spf_record or extra_apex_txt."
  }
}

run "spf_only" {
  command = plan

  variables {
    spf_record = "v=spf1 include:_spf.google.com ~all"
  }

  assert {
    condition     = aws_route53_record.apex_txt[0].name == "example.com"
    error_message = "Apex TXT record should be named by FQDN, matching the zone apex."
  }

  assert {
    condition     = aws_route53_record.apex_txt[0].records == toset(["v=spf1 include:_spf.google.com ~all"])
    error_message = "Apex TXT should hold the SPF value alone when extra_apex_txt is empty."
  }
}

run "spf_carries_extra_apex_values" {
  command = plan

  variables {
    spf_record     = "v=spf1 include:_spf.google.com ~all"
    extra_apex_txt = ["google-site-verification=abc123", "MS=ms34090815"]
  }

  assert {
    condition = aws_route53_record.apex_txt[0].records == toset([
      "v=spf1 include:_spf.google.com ~all",
      "google-site-verification=abc123",
      "MS=ms34090815",
    ])
    error_message = "Apex TXT should hold the SPF value and every extra_apex_txt value."
  }
}

run "extra_apex_values_without_spf" {
  command = plan

  variables {
    extra_apex_txt = ["google-site-verification=abc123"]
  }

  assert {
    condition     = aws_route53_record.apex_txt[0].records == toset(["google-site-verification=abc123"])
    error_message = "Apex TXT should be created for extra_apex_txt alone."
  }
}

run "spf_rejects_invalid_value" {
  command = plan

  variables {
    spf_record = "include:_spf.google.com ~all"
  }

  expect_failures = [var.spf_record]
}
