# Ein LXC-Container braucht keinen SSH-Zugang zum Node - der ist nur fuer
# cloud-init-Snippets von VMs noetig. Deshalb bleibt dieser Provider-Block
# kleiner als der im Hauptverzeichnis.
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure
  api_token = var.proxmox_api_token
}
