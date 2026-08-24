###############################################################################
# Verbindung zum Proxmox VE Cluster
###############################################################################

variable "proxmox_endpoint" {
  description = "URL der Proxmox VE API, z. B. https://pve.example.com:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "API-Token im Format 'user@realm!tokenid=uuid'. Alternativ username/password nutzen."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_username" {
  description = "Benutzer inkl. Realm, z. B. 'root@pam'. Nur noetig wenn kein API-Token genutzt wird."
  type        = string
  default     = null
}

variable "proxmox_password" {
  description = "Passwort zum Benutzer aus var.proxmox_username."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "TLS-Zertifikatspruefung abschalten (noetig bei selbstsigniertem PVE-Zertifikat)."
  type        = bool
  default     = false
}

variable "proxmox_ssh_username" {
  description = "SSH-Benutzer auf den PVE-Nodes (fuer Snippet-Uploads). Muss auf dem Node existieren, ueblicherweise 'root'."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_agent" {
  description = "SSH-Agent fuer die Authentifizierung gegenueber den PVE-Nodes verwenden."
  type        = bool
  default     = true
}

variable "proxmox_ssh_private_key_file" {
  description = "Pfad zu einem privaten SSH-Key, falls kein SSH-Agent genutzt wird."
  type        = string
  default     = null
}

variable "proxmox_ssh_nodes" {
  description = "Optionales Override der SSH-Adressen einzelner Nodes (falls DNS-Namen nicht aufloesbar sind)."
  type = list(object({
    name    = string
    address = string
    port    = optional(number, 22)
  }))
  default = []
}

###############################################################################
# Cloud-Images
###############################################################################

variable "image_datastore_id" {
  description = "Datastore fuer die heruntergeladenen Cloud-Images (Content-Type 'iso'), z. B. 'local'."
  type        = string
  default     = "local"
}

variable "image_catalog" {
  description = <<-EOT
    Zusaetzliche oder ueberschreibende Image-Definitionen. Der Key ist der Name,
    der in var.vms[*].image referenziert wird. Ergaenzt den eingebauten Katalog
    (siehe locals.tf) und ueberschreibt gleichnamige Eintraege.
  EOT
  type = map(object({
    url                = string
    file_name          = optional(string)
    checksum           = optional(string)
    checksum_algorithm = optional(string)
  }))
  default = {}
}

###############################################################################
# VM-Definitionen
###############################################################################

variable "vm_defaults" {
  description = "Vorgabewerte fuer alle VMs. Pro VM in var.vms einzeln uebersteuerbar."
  type = object({
    node_name       = string
    image           = optional(string, "debian-12")
    datastore_id    = optional(string, "local-lvm")
    cpu_cores       = optional(number, 2)
    cpu_sockets     = optional(number, 1)
    cpu_type        = optional(string, "x86-64-v2-AES")
    memory          = optional(number, 2048)
    memory_floating = optional(number, 0)
    disk_size       = optional(number, 20)
    disk_interface  = optional(string, "virtio0")
    disk_discard    = optional(string, "on")
    disk_iothread   = optional(bool, true)
    disk_ssd        = optional(bool, false)
    bios            = optional(string, "seabios")
    machine         = optional(string, null)
    on_boot         = optional(bool, true)
    started         = optional(bool, true)
    pool_id         = optional(string, null)
    tags            = optional(list(string), ["opentofu"])
    agent_enabled   = optional(bool, true)
    agent_timeout   = optional(string, "15m")

    network_devices = optional(list(object({
      bridge      = optional(string, "vmbr0")
      model       = optional(string, "virtio")
      vlan_id     = optional(number)
      mac_address = optional(string)
      mtu         = optional(number)
      firewall    = optional(bool, false)
    })), [{}])

    ip_configs = optional(list(object({
      ipv4_address = optional(string, "dhcp")
      ipv4_gateway = optional(string)
      ipv6_address = optional(string)
      ipv6_gateway = optional(string)
    })), [{}])

    dns_servers = optional(list(string), [])
    dns_domain  = optional(string, null)

    username        = optional(string, "tofu")
    ssh_public_keys = optional(list(string), [])
    password        = optional(string, null)
    packages        = optional(list(string), ["qemu-guest-agent"])
    package_upgrade = optional(bool, false)

    cloud_init_snippet   = optional(bool, true)
    snippet_datastore_id = optional(string, "local")
  })
}

variable "vms" {
  description = <<-EOT
    Map der zu erstellenden VMs. Key = VM-Name (wird auch als Hostname genutzt).
    Alle Felder sind optional; nicht gesetzte Felder kommen aus var.vm_defaults.
  EOT
  type = map(object({
    node_name       = optional(string)
    image           = optional(string)
    vm_id           = optional(number)
    description     = optional(string)
    datastore_id    = optional(string)
    cpu_cores       = optional(number)
    cpu_sockets     = optional(number)
    cpu_type        = optional(string)
    memory          = optional(number)
    memory_floating = optional(number)
    disk_size       = optional(number)
    disk_interface  = optional(string)
    disk_discard    = optional(string)
    disk_iothread   = optional(bool)
    disk_ssd        = optional(bool)
    bios            = optional(string)
    machine         = optional(string)
    on_boot         = optional(bool)
    started         = optional(bool)
    pool_id         = optional(string)
    tags            = optional(list(string))
    agent_enabled   = optional(bool)
    agent_timeout   = optional(string)

    extra_disks = optional(list(object({
      interface    = string
      size         = number
      datastore_id = optional(string)
      discard      = optional(string, "on")
      iothread     = optional(bool, true)
      ssd          = optional(bool, false)
      backup       = optional(bool, true)
    })), [])

    network_devices = optional(list(object({
      bridge      = optional(string, "vmbr0")
      model       = optional(string, "virtio")
      vlan_id     = optional(number)
      mac_address = optional(string)
      mtu         = optional(number)
      firewall    = optional(bool, false)
    })))

    ip_configs = optional(list(object({
      ipv4_address = optional(string, "dhcp")
      ipv4_gateway = optional(string)
      ipv6_address = optional(string)
      ipv6_gateway = optional(string)
    })))

    dns_servers = optional(list(string))
    dns_domain  = optional(string)

    username        = optional(string)
    ssh_public_keys = optional(list(string))
    password        = optional(string)
    packages        = optional(list(string))
    package_upgrade = optional(bool)
    user_data       = optional(string)

    cloud_init_snippet   = optional(bool)
    snippet_datastore_id = optional(string)
  }))
  default = {}
}
