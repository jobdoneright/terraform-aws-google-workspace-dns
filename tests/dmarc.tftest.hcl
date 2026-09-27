mock_provider "aws" {}

variables {
  dns_zone = "example.com"
}

run "no_dmarc_by_default" {
  command = plan

  assert {
    condition     = length(aws_route53_record.dmarc) == 0
    error_message = "No DMARC record should be created without dmarc_policy."
  }

  assert {
    condition     = length(aws_route53_record.dmarc_report_authorisation) == 0
    error_message = "No report-authorisation records should be created by default."
  }
}

run "dmarc_policy_only" {
  command = plan

  variables {
    dmarc_policy = "none"
  }

  assert {
    condition     = aws_route53_record.dmarc[0].name == "_dmarc.example.com"
    error_message = "DMARC record should be named by FQDN at _dmarc."
  }

  assert {
    condition     = aws_route53_record.dmarc[0].records == toset(["v=DMARC1; p=none"])
    error_message = "A policy with no other tags should yield just v and p."
  }
}

run "dmarc_with_reporting" {
  command = plan

  variables {
    dmarc_policy = "none"
    dmarc_rua    = ["mailto:dmarc@example.org"]
  }

  assert {
    condition     = aws_route53_record.dmarc[0].records == toset(["v=DMARC1; p=none; rua=mailto:dmarc@example.org"])
    error_message = "rua should follow the policy."
  }
}

run "dmarc_all_tags_in_rfc_order" {
  command = plan

  variables {
    dmarc_policy           = "quarantine"
    dmarc_subdomain_policy = "reject"
    dmarc_alignment_dkim   = "s"
    dmarc_alignment_spf    = "r"
    dmarc_pct              = 25
    dmarc_rua              = ["mailto:agg@example.org", "mailto:agg2@example.org"]
    dmarc_ruf              = ["mailto:fail@example.org"]
  }

  assert {
    condition = aws_route53_record.dmarc[0].records == toset([
      "v=DMARC1; p=quarantine; sp=reject; adkim=s; aspf=r; pct=25; rua=mailto:agg@example.org,mailto:agg2@example.org; ruf=mailto:fail@example.org"
    ])
    error_message = "Tags should be emitted in RFC 7489 order with multiple URIs comma-joined."
  }
}

run "dmarc_report_authorisations" {
  command = plan

  variables {
    dmarc_policy                = "none"
    dmarc_rua                   = ["mailto:dmarc@example.com"]
    dmarc_report_authorisations = ["other.example", "third.example"]
  }

  assert {
    condition     = toset(keys(aws_route53_record.dmarc_report_authorisation)) == toset(["other.example", "third.example"])
    error_message = "One report-authorisation record per authorised domain."
  }

  assert {
    condition     = aws_route53_record.dmarc_report_authorisation["other.example"].name == "other.example._report._dmarc.example.com"
    error_message = "Report-authorisation record should sit at <domain>._report._dmarc in this zone."
  }

  assert {
    condition     = aws_route53_record.dmarc_report_authorisation["other.example"].records == toset(["v=DMARC1"])
    error_message = "Report-authorisation record value should be v=DMARC1."
  }
}

run "dmarc_honours_ttl_and_allow_overwrite" {
  command = plan

  variables {
    dmarc_policy                = "none"
    dmarc_report_authorisations = ["other.example"]
    spf_record                  = "v=spf1 -all"
    ttl                         = 300
    allow_overwrite             = true
  }

  assert {
    condition     = aws_route53_record.dmarc[0].ttl == 300 && aws_route53_record.dmarc[0].allow_overwrite
    error_message = "DMARC record should honour ttl and allow_overwrite."
  }

  assert {
    condition     = aws_route53_record.apex_txt[0].allow_overwrite && aws_route53_record.dmarc_report_authorisation["other.example"].allow_overwrite
    error_message = "Apex TXT and report-authorisation records should honour allow_overwrite."
  }
}

run "dmarc_rejects_invalid_policy" {
  command = plan

  variables {
    dmarc_policy = "block"
  }

  expect_failures = [var.dmarc_policy]
}

run "dmarc_rejects_pct_out_of_range" {
  command = plan

  variables {
    dmarc_policy = "none"
    dmarc_pct    = 101
  }

  expect_failures = [var.dmarc_pct]
}

run "dmarc_rejects_rua_without_scheme" {
  command = plan

  variables {
    dmarc_policy = "none"
    dmarc_rua    = ["dmarc@example.org"]
  }

  expect_failures = [var.dmarc_rua]
}

run "dmarc_rejects_invalid_alignment" {
  command = plan

  variables {
    dmarc_policy         = "none"
    dmarc_alignment_dkim = "strict"
  }

  expect_failures = [var.dmarc_alignment_dkim]
}
