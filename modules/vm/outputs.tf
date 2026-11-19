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

output "network_mac_addresses" {
  description = "MAC-Adressen aus der Konfiguration der Netzwerkkarten, in der Reihenfolge von network_devices. Anders als mac_addresses ohne Guest-Agent und ohne Loopback."
  value       = [for device in proxmox_virtual_environment_vm.this.network_device : device.mac_address]
}
