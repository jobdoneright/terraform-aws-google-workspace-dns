# terraform-aws-google-workspace-dns

Terraform module that creates a Route53 hosted zone with the MX and CNAME records for a domain using Google Workspace (formerly G Suite).

It creates:

- a Route53 hosted zone for `dns_zone`
- Google's MX records at the zone apex
- CNAMEs to `ghs.googlehosted.com` for `mail`, `cal` and `docs` (configurable)
- an optional DKIM TXT record at `google._domainkey`
- an optional SPF record, plus any other TXT values, at the zone apex
- an optional DMARC record at `_dmarc`, with report-authorisation records for
  other domains reporting into this zone

## Usage

```hcl
module "google_workspace_dns" {
  source  = "jobdoneright/google-workspace-dns/aws"
  version = "~> 0.3"

  dns_zone = "example.com"
}
```

Delegate the domain to the zone by setting the `name_servers` output at your registrar.

To use Google's current single MX record, add:

```hcl
  mx_records = ["1 SMTP.GOOGLE.COM."]
```

To publish DKIM, generate a key in the Google Admin console (Apps > Google Workspace > Gmail > Authenticate email) and pass the TXT value:

```hcl
  dkim_record = "v=DKIM1; k=rsa; p=MIIBIjANBgkqh..."
```

Values over 255 characters, such as 2048-bit keys, are split into chunks as Route53 requires. Set `dkim_selector` if you chose a prefix other than `google`.

See [examples/basic](examples/basic) and [examples/email-auth](examples/email-auth).

## SPF and the apex TXT record set

Route53 holds one TXT record set per name. `spf_record` and `extra_apex_txt` are published as a single set at the apex, so every apex TXT value has to be listed in one of them:

```hcl
  spf_record     = "v=spf1 include:_spf.google.com ~all"
  extra_apex_txt = ["google-site-verification=abc123", "MS=ms34090815"]
```

Leaving a domain-verification token out of `extra_apex_txt` deletes it. Values at other names, such as a `send.example.com` SPF record for a third-party sender, are unaffected.

## DMARC

`dmarc_policy` publishes `_dmarc`. Nothing is published while it is null.

```hcl
  dmarc_policy = "none"
  dmarc_rua    = ["mailto:dmarc@example.com"]
```

That yields `v=DMARC1; p=none; rua=mailto:dmarc@example.com`. `p=none` asks receivers to report rather than act, so it cannot affect deliverability.

Promote past `none` only once the domain has SPF or DKIM to align against, and only after reading the aggregate reports. `dmarc_pct` ramps a policy in:

```hcl
  dmarc_policy = "quarantine"
  dmarc_pct    = 25
```

`dmarc_subdomain_policy`, `dmarc_alignment_dkim`, `dmarc_alignment_spf` and `dmarc_ruf` set `sp=`, `adkim=`, `aspf=` and `ruf=`. Tags are emitted in RFC 7489 order.

### Reporting across domains

RFC 7489 §7.1 requires the reporting domain to authorise each sender when `rua` points at a mailbox outside the domain being reported on. Without it receivers silently drop the reports. Set `dmarc_report_authorisations` on the module instance owning the reporting mailbox:

```hcl
module "primary" {
  dns_zone                    = "example.com"
  dmarc_policy                = "none"
  dmarc_rua                   = ["mailto:dmarc@example.com"]
  dmarc_report_authorisations = ["example.org", "example.net"]
}
```

That publishes `example.org._report._dmarc.example.com` and `example.net._report._dmarc.example.com`.

## Adopting records created by hand

Set `allow_overwrite = true` where an apex TXT, `_dmarc` or report-authorisation record already exists outside Terraform. Without it the change batch fails on the existing record.

## Record naming

The apex TXT and DMARC records are named by fully-qualified domain name; the MX, CNAME and DKIM records use names relative to the zone. Both resolve identically. `aws_route53_record.name` forces replacement when it changes, so neither convention can be switched without destroying and recreating the record.

## Upgrading from the untagged module

Version 0.1.0 renames resources and switches the CNAMEs from `count` to `for_each`. `moved` blocks migrate state automatically for the default `gsuite_cnames` list. With a custom list, move each record by hand:

```sh
terraform state mv 'module.<name>.aws_route53_record.gsuite_cnames[0]' 'module.<name>.aws_route53_record.cname["<subdomain>"]'
```

Terraform 1.1 or later is required.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.1 |
| aws | >= 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 4.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_route53_record.apex_txt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.dkim](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.dmarc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.dmarc_report_authorisation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.mx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| dns\_zone | Domain name of the Route53 hosted zone to create, e.g. `example.com`. | `string` | n/a | yes |
| allow\_overwrite | Adopt pre-existing records instead of failing the change batch. Applies to the apex TXT, DMARC and DMARC report-authorisation records only, which are the ones commonly created by hand before Terraform takes over. | `bool` | `false` | no |
| dkim\_record | DKIM TXT record value from the Google Admin console, e.g. `v=DKIM1; k=rsa; p=MIIB...`. No record is created when null. | `string` | `null` | no |
| dkim\_selector | DKIM selector prefix. The record is created at `<selector>._domainkey`. | `string` | `"google"` | no |
| dmarc\_alignment\_dkim | DKIM identifier alignment (`adkim=`): `r` relaxed or `s` strict. Omitted when null, which receivers read as relaxed. | `string` | `null` | no |
| dmarc\_alignment\_spf | SPF identifier alignment (`aspf=`): `r` relaxed or `s` strict. Omitted when null, which receivers read as relaxed. | `string` | `null` | no |
| dmarc\_pct | Percentage of mail the DMARC policy applies to (`pct=`), for ramping a policy in. Omitted when null, which receivers read as 100. | `number` | `null` | no |
| dmarc\_policy | DMARC policy (`p=`) for the domain: `none`, `quarantine` or `reject`. No DMARC record is created when null. A domain needs SPF or DKIM to align against before it is promoted past `none`. | `string` | `null` | no |
| dmarc\_report\_authorisations | Other domains whose DMARC reports are sent to a mailbox in this zone. Publishes a `<domain>._report._dmarc` TXT record for each, which RFC 7489 section 7.1 requires when a domain's `rua` points outside itself. Without it receivers silently drop the reports. | `list(string)` | `[]` | no |
| dmarc\_rua | URIs receiving DMARC aggregate reports (`rua=`), including the scheme, e.g. `["mailto:dmarc@example.com"]`. A mailbox outside this domain also needs a report-authorisation record in that domain's zone - see dmarc\_report\_authorisations. | `list(string)` | `[]` | no |
| dmarc\_ruf | URIs receiving DMARC failure reports (`ruf=`), including the scheme. Most receivers ignore this. | `list(string)` | `[]` | no |
| dmarc\_subdomain\_policy | DMARC policy for subdomains (`sp=`). Inherits dmarc\_policy when null. | `string` | `null` | no |
| extra\_apex\_txt | Additional TXT values published at the zone apex alongside the SPF record, e.g. `google-site-verification=` or `MS=` domain-verification tokens. Route53 holds one TXT record set per name, so anything that must coexist with the SPF record has to be listed here or it is deleted. | `list(string)` | `[]` | no |
| gsuite\_cnames | Subdomains to CNAME to `ghs.googlehosted.com` for Google Workspace custom URLs. | `list(string)` | <pre>[<br/>  "mail",<br/>  "cal",<br/>  "docs"<br/>]</pre> | no |
| mx\_records | MX record values. The default is Google's legacy five-record set; Google now also accepts the single record `1 SMTP.GOOGLE.COM.`. | `list(string)` | <pre>[<br/>  "1 ASPMX.L.GOOGLE.COM.",<br/>  "5 ALT1.ASPMX.L.GOOGLE.COM.",<br/>  "5 ALT2.ASPMX.L.GOOGLE.COM.",<br/>  "10 ALT3.ASPMX.L.GOOGLE.COM.",<br/>  "10 ALT4.ASPMX.L.GOOGLE.COM."<br/>]</pre> | no |
| spf\_record | SPF TXT record value published at the zone apex, e.g. `v=spf1 include:_spf.google.com ~all`. No SPF is published when null. | `string` | `null` | no |
| tags | Tags to apply to the hosted zone. | `map(string)` | `{}` | no |
| ttl | TTL in seconds for the MX, CNAME and DKIM records. | `number` | `3600` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| name\_servers | Name servers to delegate the domain to at the registrar. |
| r53\_zone\_id | ID of the Route53 hosted zone. |
<!-- END_TF_DOCS -->

## Releasing

Releases are managed by [release-please](https://github.com/googleapis/release-please). Merge commits to `master` using [Conventional Commits](https://www.conventionalcommits.org/) (`fix:`, `feat:`, `feat!:`). release-please opens a release PR that bumps the version and updates `CHANGELOG.md`. Merging that PR tags `vX.Y.Z` and creates a GitHub release, which the Terraform and OpenTofu registries pick up.

## License

[MIT](LICENSE)
