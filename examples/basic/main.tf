provider "aws" {
  region = "eu-west-1"
}

module "google_workspace_dns" {
  source = "../.."

  dns_zone = "example.com"
}

output "name_servers" {
  value = module.google_workspace_dns.name_servers
}
