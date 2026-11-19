terraform {
  required_version = ">= 1.10.0"

  required_providers {
    netbox = {
      source = "e-breuninger/netbox"
      # Provider und NetBox gehoeren zusammen: 6.0.x kennt NetBox 4.6.8 bis
      # 4.6.10. NetBox erst heben, wenn eine Provider-Version die neue
      # NetBox-Version nennt (Tabelle in der Provider-Doku), dann beides
      # zusammen. Die NetBox-Version steht in der Ansible-Rolle netbox_server.
      version = "~> 6.0.1"
    }
  }

  # Eigener State neben dem des Haupt-Roots, im selben Bucket. Getrennt, damit
  # ein Fehler gegen NetBox nie einen Plan fuer Proxmox blockiert - und
  # umgekehrt.
  backend "s3" {
    bucket = "tofu-state"
    key    = "netbox/terraform.tfstate"

    endpoints = {
      s3 = "http://192.168.178.62:9000"
    }

    # Gleiche Schalter wie im Haupt-Root, Begruendung steht dort.
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    use_path_style              = true
    use_lockfile                = true
  }

  # Zugang wie im Haupt-Root ueber AWS_ACCESS_KEY_ID und AWS_SECRET_ACCESS_KEY
  # in der Umgebung. Derselbe Dienstzugang reicht: Er darf in tofu-state.
}
