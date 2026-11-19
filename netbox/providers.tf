provider "netbox" {
  server_url = var.netbox_url

  # Der API-Token gehoert NICHT hierher und nicht in terraform.tfvars, sondern
  # in die Umgebung:
  #   $env:NETBOX_API_TOKEN = '...'
  # Der Provider liest ihn von dort selbst.

  # Traefik liefert das Zertifikat der eigenen CA aus. Vertraut der Rechner
  # ihr nicht systemweit, hier den Pfad zum CA-Zertifikat (nur dem
  # oeffentlichen Teil) angeben.
  ca_cert_file = var.netbox_ca_cert_file
}

# Den Zustand des Haupt-Roots lesen: Daraus kommen die Gaeste. Entfaellt, wenn
# var.guests gesetzt ist (zum Testen ohne Silo).
data "terraform_remote_state" "proxmox" {
  count   = var.guests == null ? 1 : 0
  backend = "s3"

  config = {
    bucket = "tofu-state"
    key    = "proxmox/terraform.tfstate"

    endpoints = {
      s3 = var.state_endpoint
    }

    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    use_path_style              = true
  }
}
