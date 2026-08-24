variable "name" {
  description = "VM-Name, wird auch als cloud-init Hostname genutzt."
  type        = string
}

variable "node_name" {
  description = "PVE-Node auf dem die VM laeuft."
  type        = string
}

variable "vm_id" {
  description = "Feste VMID. null = PVE vergibt automatisch."
  type        = number
  default     = null
}

variable "description" {
  description = "Beschreibung der VM in der PVE-Oberflaeche."
  type        = string
  default     = "Managed by OpenTofu"
}

variable "tags" {
  description = "PVE-Tags."
  type        = list(string)
  default     = ["opentofu"]
}

variable "pool_id" {
  description = "Optionaler Resource-Pool."
  type        = string
  default     = null
}

variable "image_file_id" {
  description = "File-ID des Cloud-Images, z. B. 'local:iso/debian-12-genericcloud-amd64.img'."
  type        = string
}

###############################################################################
# Hardware
###############################################################################

variable "cpu_cores" {
  description = "Anzahl CPU-Kerne pro Socket."
  type        = number
  default     = 2
}

variable "cpu_sockets" {
  description = "Anzahl CPU-Sockets."
  type        = number
  default     = 1
}

variable "cpu_type" {
  description = "CPU-Typ, z. B. 'x86-64-v2-AES' oder 'host'."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "memory" {
  description = "Arbeitsspeicher in MiB."
  type        = number
  default     = 2048
}

variable "memory_floating" {
  description = "Minimaler Speicher bei Ballooning in MiB. 0 = Ballooning aus."
  type        = number
  default     = 0
}

variable "datastore_id" {
  description = "Datastore fuer die Boot-Disk und die cloud-init Disk, z. B. 'local-lvm'."
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Groesse der Boot-Disk in GiB (muss >= Image-Groesse sein)."
  type        = number
  default     = 20
}

variable "disk_interface" {
  description = "Interface der Boot-Disk, z. B. 'virtio0' oder 'scsi0'."
  type        = string
  default     = "virtio0"
}

variable "disk_discard" {
  description = "Discard/TRIM: 'on' oder 'ignore'."
  type        = string
  default     = "on"
}

variable "disk_iothread" {
  description = "IO-Thread aktivieren (nur virtio/scsi)."
  type        = bool
  default     = true
}

variable "disk_ssd" {
  description = "SSD-Emulation. Nicht unterstuetzt fuer virtio-Interfaces."
  type        = bool
  default     = false
}

variable "extra_disks" {
  description = "Weitere Datendisks."
  type        = list(object({
    interface    = string
    size         = number
    datastore_id = optional(string)
    discard      = optional(string, "on")
    iothread     = optional(bool, true)
    ssd          = optional(bool, false)
    backup       = optional(bool, true)
  }))
  default = []
}

variable "bios" {
  description = "'seabios' oder 'ovmf' (UEFI)."
  type        = string
  default     = "seabios"
}

variable "machine" {
  description = "Machine-Type, z. B. 'q35'. null = PVE-Default (i440fx)."
  type        = string
  default     = null
}

variable "on_boot" {
  description = "VM beim Start des Nodes automatisch starten."
  type        = bool
  default     = true
}

variable "started" {
  description = "VM nach dem Anlegen starten."
  type        = bool
  default     = true
}

variable "agent_enabled" {
  description = "QEMU-Guest-Agent aktivieren. Erfordert qemu-guest-agent im Gast."
  type        = bool
  default     = true
}

variable "agent_timeout" {
  description = "Wartezeit auf den Guest-Agent, z. B. '15m'."
  type        = string
  default     = "15m"
}

###############################################################################
# Netzwerk
###############################################################################

variable "network_devices" {
  description = "Netzwerkkarten der VM."
  type        = list(object({
    bridge      = optional(string, "vmbr0")
    model       = optional(string, "virtio")
    vlan_id     = optional(number)
    mac_address = optional(string)
    mtu         = optional(number)
    firewall    = optional(bool, false)
  }))
  default = [{}]
}

variable "ip_configs" {
  description = "cloud-init IP-Konfiguration je Netzwerkkarte. 'dhcp' oder CIDR (z. B. '192.168.1.10/24')."
  type        = list(object({
    ipv4_address = optional(string, "dhcp")
    ipv4_gateway = optional(string)
    ipv6_address = optional(string)
    ipv6_gateway = optional(string)
  }))
  default = [{}]
}

variable "dns_servers" {
  description = "DNS-Server fuer cloud-init. Leer = Vorgabe des Nodes."
  type        = list(string)
  default     = []
}

variable "dns_domain" {
  description = "Such-Domain fuer cloud-init."
  type        = string
  default     = null
}

###############################################################################
# cloud-init
###############################################################################

variable "username" {
  description = "Anzulegender Benutzer im Gast."
  type        = string
  default     = "tofu"
}

variable "ssh_public_keys" {
  description = "Public Keys fuer den Benutzer."
  type        = list(string)
  default     = []
}

variable "password" {
  description = "Optionales Passwort im Klartext fuer den Benutzer. Bevorzugt SSH-Keys nutzen."
  type        = string
  default     = null
  sensitive   = true
}

variable "packages" {
  description = "Pakete die cloud-init installiert. qemu-guest-agent wird fuer den Agent benoetigt."
  type        = list(string)
  default     = ["qemu-guest-agent"]
}

variable "package_upgrade" {
  description = "Beim ersten Boot ein Distributions-Upgrade durchfuehren."
  type        = bool
  default     = false
}

variable "user_data" {
  description = "Eigene cloud-config. Ersetzt die generierte user-data komplett (nur mit cloud_init_snippet = true)."
  type        = string
  default     = null
}

variable "cloud_init_snippet" {
  description = <<-EOT
    true  = user-data als Snippet hochladen (benoetigt SSH-Zugriff auf den Node und
            einen Datastore mit Content-Type 'snippets'); erlaubt Paketinstallation.
    false = nur die native cloud-init Konfiguration ueber die API (Benutzer + Keys),
            ohne Paketinstallation.
  EOT
  type    = bool
  default = true
}

variable "snippet_datastore_id" {
  description = "Datastore fuer das user-data Snippet (Content-Type 'snippets' muss aktiviert sein)."
  type        = string
  default     = "local"
}
