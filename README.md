# terraform-aws-google-workspace-dns

Terraform module that creates a Route53 hosted zone with the MX and CNAME records for a domain using Google Workspace (formerly G Suite).

It creates:

- a Route53 hosted zone for `dns_zone`
- Google's MX records at the zone apex
- CNAMEs to `ghs.googlehosted.com` for `mail`, `cal` and `docs` (configurable)

## Usage

```hcl
module "google_workspace_dns" {
  source  = "jobdoneright/google-workspace-dns/aws"
  version = "~> 0.1"

  dns_zone = "example.com"
}
```

Delegate the domain to the zone by setting the `name_servers` output at your registrar.

To use Google's current single MX record, add:

```hcl
  mx_records = ["1 SMTP.GOOGLE.COM."]
```

See [examples/basic](examples/basic).

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
| [aws_route53_record.cname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.mx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| dns\_zone | Domain name of the Route53 hosted zone to create, e.g. `example.com`. | `string` | n/a | yes |
| gsuite\_cnames | Subdomains to CNAME to `ghs.googlehosted.com` for Google Workspace custom URLs. | `list(string)` | <pre>[<br/>  "mail",<br/>  "cal",<br/>  "docs"<br/>]</pre> | no |
| mx\_records | MX record values. The default is Google's legacy five-record set; Google now also accepts the single record `1 SMTP.GOOGLE.COM.`. | `list(string)` | <pre>[<br/>  "1 ASPMX.L.GOOGLE.COM.",<br/>  "5 ALT1.ASPMX.L.GOOGLE.COM.",<br/>  "5 ALT2.ASPMX.L.GOOGLE.COM.",<br/>  "10 ALT3.ASPMX.L.GOOGLE.COM.",<br/>  "10 ALT4.ASPMX.L.GOOGLE.COM."<br/>]</pre> | no |
| tags | Tags to apply to the hosted zone. | `map(string)` | `{}` | no |
| ttl | TTL in seconds for the MX and CNAME records. | `number` | `3600` | no |

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
