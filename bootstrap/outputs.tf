output "vm_id" {
  description = "VMID des MinIO-Containers."
  value       = module.minio.vm_id
}

output "ipv4_address" {
  description = "Feste IP des Containers, ohne Praefix - so, wie sie in den Backend-Block gehoert."
  value       = split("/", var.ipv4_address)[0]
}

output "backend_endpoint" {
  description = "Der Wert, der im Hauptverzeichnis unter endpoints.s3 eingetragen wird."
  value       = "http://${split("/", var.ipv4_address)[0]}:9000"
}
