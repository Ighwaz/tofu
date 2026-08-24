output "vm_id" {
  description = "VMID der erzeugten VM."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "Name der VM."
  value       = proxmox_virtual_environment_vm.this.name
}

output "node_name" {
  description = "PVE-Node auf dem die VM laeuft."
  value       = proxmox_virtual_environment_vm.this.node_name
}

output "ipv4_addresses" {
  description = "Vom Guest-Agent gemeldete IPv4-Adressen (leer wenn der Agent deaktiviert ist)."
  value       = proxmox_virtual_environment_vm.this.ipv4_addresses
}

output "mac_addresses" {
  description = "MAC-Adressen der Netzwerkkarten."
  value       = proxmox_virtual_environment_vm.this.mac_addresses
}
