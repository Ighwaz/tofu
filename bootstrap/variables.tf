###############################################################################
# Verbindung zum Proxmox VE Cluster
#
# Dieselben Werte wie im Hauptverzeichnis. Doppelt, weil bootstrap/ ein
# eigenes Root-Modul mit eigenem State ist und Variablen nicht erbt.
###############################################################################

variable "proxmox_endpoint" {
  description = "URL der Proxmox VE API."
  type        = string
  default     = "https://192.168.178.10:8006/"
}

variable "proxmox_api_token" {
  description = "API-Token im Format 'user@realm!tokenid=uuid'."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "TLS-Zertifikatspruefung abschalten (noetig bei selbstsigniertem PVE-Zertifikat)."
  type        = bool
  default     = true
}

###############################################################################
# Der Container
###############################################################################

variable "name" {
  description = "Name und Hostname des Containers."
  type        = string
  default     = "minio"
}

variable "node_name" {
  description = "PVE-Node."
  type        = string
  default     = "procmox"
}

variable "vm_id" {
  description = "Feste VMID. null = PVE vergibt die naechste freie."
  type        = number
  default     = 520
}

variable "template_file_id" {
  description = <<-EOT
    LXC-Template als File-ID, z. B. "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst".
    Welche Templates vorliegen, zeigt `pveam list local` auf dem Node.
  EOT
  type        = string
}

variable "cpu_cores" {
  description = "CPU-Kerne. MinIO ist genuegsam, solange nur OpenTofu-State darin liegt."
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in MiB."
  type        = number
  default     = 1024
}

variable "swap" {
  description = "Swap in MiB."
  type        = number
  default     = 512
}

variable "datastore_id" {
  description = "Storage fuer Root-Disk und Datenvolume."
  type        = string
  default     = "bigpool"
}

variable "disk_size" {
  description = "Groesse der Root-Disk in GiB."
  type        = number
  default     = 8
}

variable "data_path" {
  description = "Mountpunkt des Datenvolumes im Container - hier legt MinIO seine Buckets ab."
  type        = string
  default     = "/var/lib/minio"
}

variable "data_size" {
  description = <<-EOT
    Groesse des Datenvolumes als String mit Einheit, z. B. "20G" - so verlangt
    es die Proxmox-API. Ein OpenTofu-State ist wenige hundert KiB gross; der
    Rest ist Luft fuer Versionsstaende und spaetere Buckets.
  EOT
  type        = string
  default     = "20G"
}

###############################################################################
# Netz
#
# Die Adresse muss FEST sein, nicht per DHCP: Sie steht als Endpunkt im
# Backend-Block des Hauptverzeichnisses. Wandert sie, findet OpenTofu seinen
# eigenen State nicht mehr.
###############################################################################

variable "ipv4_address" {
  description = <<-EOT
    Feste IP mit Praefix, z. B. "192.168.178.61/24". Muss ausserhalb des
    DHCP-Bereichs deines Routers liegen, sonst vergibt der sie irgendwann ein
    zweites Mal. Freie Adresse vorher pruefen, etwa mit `ping`.
  EOT
  type        = string

  validation {
    condition     = can(cidrnetmask("${split("/", var.ipv4_address)[0]}/32")) && length(split("/", var.ipv4_address)) == 2
    error_message = "ipv4_address muss eine IPv4-Adresse mit Praefix sein, z. B. '192.168.178.61/24' - 'dhcp' geht hier nicht."
  }
}

variable "ipv4_gateway" {
  description = "Gateway."
  type        = string
  default     = "192.168.178.1"
}

variable "bridge" {
  description = "PVE-Bridge."
  type        = string
  default     = "vmbr0"
}

variable "dns_servers" {
  description = "DNS-Server im Container."
  type        = list(string)
  default     = ["192.168.178.50"]
}

variable "dns_domain" {
  description = "Such-Domain."
  type        = string
  default     = "lab.home.arpa"
}

variable "ssh_public_keys" {
  description = "Public Keys fuer root im Container."
  type        = list(string)
  default     = []
}

variable "protection" {
  description = <<-EOT
    PVE-Loeschschutz. Standardmaessig an, weil in diesem Container der State
    aller anderen Ressourcen liegt - ein versehentliches `tofu destroy` oder
    ein Fehlklick in der Oberflaeche wuerde ihn sonst mitnehmen.

    Soll der Container wirklich weg: erst hier auf false, `tofu apply`, dann
    zerstoeren. Der Umweg ist der Sinn der Sache.
  EOT
  type        = bool
  default     = true
}
