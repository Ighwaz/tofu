provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  # Empfohlen: API-Token ("user@realm!tokenid=uuid").
  api_token = var.proxmox_api_token

  # Alternative (oder zusaetzlich, z. B. fuer Aktionen die kein Token erlaubt):
  username = var.proxmox_username
  password = var.proxmox_password

  # SSH wird vom Provider fuer Datei-Uploads (cloud-init Snippets) und
  # einige Storage-Operationen benoetigt.
  ssh {
    agent    = var.proxmox_ssh_agent
    username = var.proxmox_ssh_username
    # Zwei Wege zum Schluessel: als Text (fuer CI-Secrets) oder als Datei
    # (lokal bequemer). Der Text hat Vorrang. pathexpand loest ein fuehrendes
    # "~" auf - file() selbst kann das nicht und wuerde daran scheitern.
    private_key = var.proxmox_ssh_private_key != null ? var.proxmox_ssh_private_key : (
      var.proxmox_ssh_private_key_file != null ? file(pathexpand(var.proxmox_ssh_private_key_file)) : null
    )

    dynamic "node" {
      for_each = var.proxmox_ssh_nodes
      content {
        name    = node.value.name
        address = node.value.address
        port    = node.value.port
      }
    }
  }
}
