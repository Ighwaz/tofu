output "vm_id" {
  description = "VMID des erzeugten Containers."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "name" {
  description = "Name/Hostname des Containers."
  value       = var.name
}

output "node_name" {
  description = "PVE-Node auf dem der Container laeuft."
  value       = proxmox_virtual_environment_container.this.node_name
}

output "mac_addresses" {
  description = "MAC-Adressen der Netzwerkkarten, in der Reihenfolge von network_interfaces (Proxmox vergibt sie, wenn keine gesetzt ist)."
  value       = [for nic in proxmox_virtual_environment_container.this.network_interface : nic.mac_address]
}
