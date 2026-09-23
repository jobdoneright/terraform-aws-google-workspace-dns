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
