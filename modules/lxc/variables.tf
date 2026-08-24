variable "name" {
  description = "Container-Name, wird auch als Hostname gesetzt."
  type        = string
}

variable "node_name" {
  description = "PVE-Node auf dem der Container laeuft."
  type        = string
}

variable "vm_id" {
  description = "Feste VMID. null = PVE vergibt automatisch."
  type        = number
  default     = null
}

variable "description" {
  description = "Beschreibung des Containers in der PVE-Oberflaeche."
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

variable "template_file_id" {
  description = "File-ID des LXC-Templates, z. B. 'local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst'."
  type        = string
  default     = null
}

variable "os_type" {
  description = "Betriebssystem-Typ des Templates: 'debian', 'ubuntu', 'alpine', 'centos', ..."
  type        = string
  default     = "debian"
}

variable "unprivileged" {
  description = "Unprivilegierter Container (empfohlen)."
  type        = bool
  default     = true
}

###############################################################################
# Hardware
###############################################################################

variable "cpu_cores" {
  description = "Anzahl CPU-Kerne."
  type        = number
  default     = 2
}

variable "memory" {
  description = "Arbeitsspeicher in MiB."
  type        = number
  default     = 512
}

variable "swap" {
  description = "Swap in MiB. 0 = kein Swap."
  type        = number
  default     = 512
}

variable "datastore_id" {
  description = "Datastore fuer das Root-Filesystem, z. B. 'local-lvm'."
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Groesse des Root-Filesystems in GiB."
  type        = number
  default     = 8
}

variable "mount_points" {
  description = "Zusaetzliche Mount-Points. 'volume' = Datastore fuer ein neues Volume oder ein bestehender Pfad/Volume-Name."
  type = list(object({
    path      = string
    size      = string
    volume    = optional(string)
    backup    = optional(bool, false)
    read_only = optional(bool, false)
  }))
  default = []
}

variable "features" {
  description = "LXC-Features. nesting wird z. B. fuer Docker im Container gebraucht; Aenderungen erfordern meist root@pam."
  type = object({
    nesting = optional(bool, false)
    fuse    = optional(bool, false)
    keyctl  = optional(bool, false)
    mount   = optional(list(string), [])
  })
  default = {}
}

variable "start_on_boot" {
  description = "Container beim Start des Nodes automatisch starten."
  type        = bool
  default     = true
}

variable "started" {
  description = "Container nach dem Anlegen starten."
  type        = bool
  default     = true
}

variable "protection" {
  description = "Loeschschutz in PVE aktivieren."
  type        = bool
  default     = false
}

###############################################################################
# Netzwerk
###############################################################################

variable "network_interfaces" {
  description = "Netzwerkkarten des Containers. Ohne 'name' wird veth0, veth1, ... vergeben."
  type = list(object({
    name        = optional(string)
    bridge      = optional(string, "vmbr0")
    vlan_id     = optional(number)
    mac_address = optional(string)
    mtu         = optional(number)
    firewall    = optional(bool, false)
    rate_limit  = optional(number)
  }))
  default = [{}]
}

variable "ip_configs" {
  description = "IP-Konfiguration je Netzwerkkarte. 'dhcp' oder CIDR (z. B. '192.168.1.10/24')."
  type = list(object({
    ipv4_address = optional(string, "dhcp")
    ipv4_gateway = optional(string)
    ipv6_address = optional(string)
    ipv6_gateway = optional(string)
  }))
  default = [{}]
}

variable "dns_servers" {
  description = "DNS-Server. Leer = Vorgabe des Nodes."
  type        = list(string)
  default     = []
}

variable "dns_domain" {
  description = "Such-Domain."
  type        = string
  default     = null
}

###############################################################################
# Zugang
###############################################################################

variable "ssh_public_keys" {
  description = "Public Keys fuer root im Container."
  type        = list(string)
  default     = []
}

variable "password" {
  description = "Optionales root-Passwort im Klartext. Bevorzugt SSH-Keys nutzen."
  type        = string
  default     = null
  sensitive   = true
}
