terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.111.0, < 1.0.0"
    }
  }

  # Standardmaessig wird der State lokal in terraform.tfstate abgelegt.
  # Fuer Teams/CI hier einen Remote-Backend-Block ergaenzen, z. B.:
  #
  # backend "s3" {
  #   bucket = "tofu-state"
  #   key    = "proxmox/terraform.tfstate"
  #   region = "eu-central-1"
  # }
}
