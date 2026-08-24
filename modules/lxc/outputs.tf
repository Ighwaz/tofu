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
