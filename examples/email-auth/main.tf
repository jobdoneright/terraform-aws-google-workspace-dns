provider "aws" {
  region = "eu-west-1"
}

# The domain collecting aggregate reports for the whole estate. It authorises
# the other domains to report to its mailbox.
module "primary" {
  source = "../.."

  dns_zone       = "example.com"
  spf_record     = "v=spf1 include:_spf.google.com ~all"
  extra_apex_txt = ["google-site-verification=abc123"]
  dkim_record    = "v=DKIM1; k=rsa; p=MIIBIjANBgkqh..."

  dmarc_policy                = "reject"
  dmarc_rua                   = ["mailto:dmarc@example.com"]
  dmarc_report_authorisations = ["example.org"]
}

# A second domain reporting to the primary, still at p=none while its
# aggregate reports are read.
module "secondary" {
  source = "../.."

  dns_zone     = "example.org"
  spf_record   = "v=spf1 include:_spf.google.com ~all"
  dmarc_policy = "none"
  dmarc_rua    = ["mailto:dmarc@example.com"]
}
