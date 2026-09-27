variable "dns_zone" {
  description = "Domain name of the Route53 hosted zone to create, e.g. `example.com`."
  type        = string
}

variable "gsuite_cnames" {
  description = "Subdomains to CNAME to `ghs.googlehosted.com` for Google Workspace custom URLs."
  type        = list(string)
  default     = ["mail", "cal", "docs"]
}

variable "mx_records" {
  description = "MX record values. The default is Google's legacy five-record set; Google now also accepts the single record `1 SMTP.GOOGLE.COM.`."
  type        = list(string)
  default = [
    "1 ASPMX.L.GOOGLE.COM.",
    "5 ALT1.ASPMX.L.GOOGLE.COM.",
    "5 ALT2.ASPMX.L.GOOGLE.COM.",
    "10 ALT3.ASPMX.L.GOOGLE.COM.",
    "10 ALT4.ASPMX.L.GOOGLE.COM.",
  ]
}

variable "ttl" {
  description = "TTL in seconds for the MX, CNAME and DKIM records."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags to apply to the hosted zone."
  type        = map(string)
  default     = {}
}

variable "dkim_record" {
  description = "DKIM TXT record value from the Google Admin console, e.g. `v=DKIM1; k=rsa; p=MIIB...`. No record is created when null."
  type        = string
  default     = null

  validation {
    condition     = var.dkim_record == null || can(regex("^v=DKIM1;", var.dkim_record))
    error_message = "The dkim_record must start with \"v=DKIM1;\"."
  }
}

variable "dkim_selector" {
  description = "DKIM selector prefix. The record is created at `<selector>._domainkey`."
  type        = string
  default     = "google"
}

variable "spf_record" {
  description = "SPF TXT record value published at the zone apex, e.g. `v=spf1 include:_spf.google.com ~all`. No SPF is published when null."
  type        = string
  default     = null

  validation {
    condition     = var.spf_record == null || can(regex("^v=spf1( |$)", coalesce(var.spf_record, "")))
    error_message = "The spf_record must start with \"v=spf1\"."
  }
}

variable "extra_apex_txt" {
  description = "Additional TXT values published at the zone apex alongside the SPF record, e.g. `google-site-verification=` or `MS=` domain-verification tokens. Route53 holds one TXT record set per name, so anything that must coexist with the SPF record has to be listed here or it is deleted."
  type        = list(string)
  default     = []
}

variable "dmarc_policy" {
  description = "DMARC policy (`p=`) for the domain: `none`, `quarantine` or `reject`. No DMARC record is created when null. A domain needs SPF or DKIM to align against before it is promoted past `none`."
  type        = string
  default     = null

  validation {
    condition     = var.dmarc_policy == null || contains(["none", "quarantine", "reject"], coalesce(var.dmarc_policy, "none"))
    error_message = "The dmarc_policy must be \"none\", \"quarantine\" or \"reject\"."
  }
}

variable "dmarc_subdomain_policy" {
  description = "DMARC policy for subdomains (`sp=`). Inherits dmarc_policy when null."
  type        = string
  default     = null

  validation {
    condition     = var.dmarc_subdomain_policy == null || contains(["none", "quarantine", "reject"], coalesce(var.dmarc_subdomain_policy, "none"))
    error_message = "The dmarc_subdomain_policy must be \"none\", \"quarantine\" or \"reject\"."
  }
}

variable "dmarc_pct" {
  description = "Percentage of mail the DMARC policy applies to (`pct=`), for ramping a policy in. Omitted when null, which receivers read as 100."
  type        = number
  default     = null

  validation {
    condition     = var.dmarc_pct == null || (coalesce(var.dmarc_pct, 100) >= 0 && coalesce(var.dmarc_pct, 100) <= 100)
    error_message = "The dmarc_pct must be between 0 and 100."
  }
}

variable "dmarc_rua" {
  description = "URIs receiving DMARC aggregate reports (`rua=`), including the scheme, e.g. `[\"mailto:dmarc@example.com\"]`. A mailbox outside this domain also needs a report-authorisation record in that domain's zone - see dmarc_report_authorisations."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for uri in var.dmarc_rua : can(regex("^[A-Za-z][A-Za-z0-9+.-]*:", uri))])
    error_message = "Each dmarc_rua entry must be a URI including the scheme, e.g. \"mailto:dmarc@example.com\"."
  }
}

variable "dmarc_ruf" {
  description = "URIs receiving DMARC failure reports (`ruf=`), including the scheme. Most receivers ignore this."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for uri in var.dmarc_ruf : can(regex("^[A-Za-z][A-Za-z0-9+.-]*:", uri))])
    error_message = "Each dmarc_ruf entry must be a URI including the scheme, e.g. \"mailto:dmarc@example.com\"."
  }
}

variable "dmarc_alignment_dkim" {
  description = "DKIM identifier alignment (`adkim=`): `r` relaxed or `s` strict. Omitted when null, which receivers read as relaxed."
  type        = string
  default     = null

  validation {
    condition     = var.dmarc_alignment_dkim == null || contains(["r", "s"], coalesce(var.dmarc_alignment_dkim, "r"))
    error_message = "The dmarc_alignment_dkim must be \"r\" or \"s\"."
  }
}

variable "dmarc_alignment_spf" {
  description = "SPF identifier alignment (`aspf=`): `r` relaxed or `s` strict. Omitted when null, which receivers read as relaxed."
  type        = string
  default     = null

  validation {
    condition     = var.dmarc_alignment_spf == null || contains(["r", "s"], coalesce(var.dmarc_alignment_spf, "r"))
    error_message = "The dmarc_alignment_spf must be \"r\" or \"s\"."
  }
}

variable "dmarc_report_authorisations" {
  description = "Other domains whose DMARC reports are sent to a mailbox in this zone. Publishes a `<domain>._report._dmarc` TXT record for each, which RFC 7489 section 7.1 requires when a domain's `rua` points outside itself. Without it receivers silently drop the reports."
  type        = list(string)
  default     = []
}

variable "allow_overwrite" {
  description = "Adopt pre-existing records instead of failing the change batch. Applies to the apex TXT, DMARC and DMARC report-authorisation records only, which are the ones commonly created by hand before Terraform takes over."
  type        = bool
  default     = false
}
