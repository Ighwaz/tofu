###############################################################################
# Verbindung
###############################################################################

variable "netbox_url" {
  description = "Adresse von NetBox, ohne /api."
  type        = string
  default     = "https://netbox.lab.home.arpa"
}

variable "netbox_ca_cert_file" {
  description = "Pfad zum CA-Zertifikat (PEM), mit dem NetBox ausgeliefert wird. null = Zertifikatsspeicher des Systems."
  type        = string
  default     = null
}

variable "netbox_request_timeout" {
  description = "Wartezeit je Anfrage an NetBox in Sekunden (Provider-Vorgabe: 10)."
  type        = number
  default     = 60
}

variable "state_endpoint" {
  description = "S3-Endpunkt mit dem State des Haupt-Roots (Silo)."
  type        = string
  default     = "http://192.168.178.62:9000"
}

###############################################################################
# Standort und Netz
###############################################################################

variable "site_name" {
  description = "Name des Standorts in NetBox."
  type        = string
  default     = "Zuhause"
}

variable "time_zone" {
  description = "Zeitzone des Standorts."
  type        = string
  default     = "Europe/Berlin"
}

variable "cluster_name" {
  description = "Name des Proxmox-Clusters in NetBox."
  type        = string
  default     = "procmox"
}

variable "prefix" {
  description = "Das Heimnetz mit Praefixlaenge."
  type        = string
  default     = "192.168.178.0/24"
}

variable "dhcp_range" {
  description = "Bereich, den der DHCP-Server vergibt (Adressen mit Praefixlaenge). null = keiner eintragen."
  type = object({
    start = string
    end   = string
  })
  default = {
    start = "192.168.178.20/24"
    end   = "192.168.178.200/24"
  }
}

###############################################################################
# Feste Geraete
###############################################################################

variable "devices" {
  description = <<-EOT
    Physische Geraete im Netz. Der Schluessel ist der Name in NetBox.
    Hersteller, Modelle und Rollen legt OpenTofu aus diesen Angaben selbst an.

    hosts_guests = true markiert den Proxmox-Host: Er kommt in den Cluster, und
    Gaeste mit gleichem node_name haengen an ihm. Sein Name muss deshalb dem
    Node-Namen in Proxmox entsprechen.
  EOT
  type = map(object({
    role           = string
    manufacturer   = string
    model          = string
    ipv4           = optional(string) # mit Praefixlaenge, z. B. 192.168.178.1/24
    mac            = optional(string)
    dns_name       = optional(string)
    interface      = optional(string, "eth0")
    interface_type = optional(string, "1000base-t")
    serial         = optional(string)
    description    = optional(string)
    hosts_guests   = optional(bool, false)
  }))
  default = {}

  validation {
    condition     = length([for name, d in var.devices : name if d.hosts_guests]) <= 1
    error_message = "Hoechstens ein Geraet darf hosts_guests = true haben (ein Node, ein Cluster)."
  }

  validation {
    condition = alltrue([
      for d in var.devices : d.ipv4 == null || can(cidrhost(d.ipv4, 0))
    ])
    error_message = "ipv4 braucht die Praefixlaenge, z. B. 192.168.178.1/24."
  }
}

###############################################################################
# Gaeste
###############################################################################

variable "guests" {
  description = <<-EOT
    Nur zum Testen: Gaeste direkt statt aus dem State des Haupt-Roots.
    Aufbau wie dessen Output netbox_inventory. Im Normalbetrieb null lassen.
  EOT
  type = map(object({
    type          = string
    vm_id         = number
    node_name     = string
    description   = string
    tags          = list(string)
    os_type       = string
    cpu_cores     = number
    memory_mb     = number
    started       = bool
    start_on_boot = bool
    disks = list(object({
      name    = string
      size_gb = number
    }))
    ipv4 = string
    mac  = string
  }))
  default = null
}
