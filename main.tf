# Cloud-Image je Node/Image-Kombination auf den PVE-Storage laden.
resource "proxmox_download_file" "cloud_image" {
  for_each = local.image_downloads

  content_type        = "iso"
  datastore_id        = var.image_datastore_id
  node_name           = each.value.node_name
  url                 = each.value.spec.url
  file_name           = each.value.spec.file_name
  checksum            = each.value.spec.checksum != "" ? each.value.spec.checksum : null
  checksum_algorithm  = each.value.spec.checksum_algorithm != "" ? each.value.spec.checksum_algorithm : null
  overwrite_unmanaged = true

  lifecycle {
    precondition {
      condition     = each.value.known
      error_message = "Unbekanntes Image '${each.value.image}'. Bekannt sind: ${join(", ", keys(local.image_catalog))}. Eigene Images ueber var.image_catalog ergaenzen."
    }
  }
}

module "vm" {
  source   = "./modules/vm"
  for_each = local.vms

  name          = each.key
  node_name     = each.value.node_name
  vm_id         = each.value.vm_id
  description   = each.value.description
  tags          = each.value.tags
  pool_id       = each.value.pool_id
  image_file_id = proxmox_download_file.cloud_image["${each.value.node_name}|${each.value.image}"].id

  cpu_cores       = each.value.cpu_cores
  cpu_sockets     = each.value.cpu_sockets
  cpu_type        = each.value.cpu_type
  memory          = each.value.memory
  memory_floating = each.value.memory_floating

  datastore_id     = each.value.datastore_id
  disk_size        = each.value.disk_size
  disk_interface   = each.value.disk_interface
  disk_discard     = each.value.disk_discard
  disk_iothread    = each.value.disk_iothread
  disk_ssd         = each.value.disk_ssd
  disk_file_format = each.value.disk_file_format
  extra_disks      = each.value.extra_disks

  # Global, nicht je VM: wer das einzeln braucht, setzt es im Modulaufruf.
  disk_aio                   = var.vm_defaults.disk_aio
  disk_cache                 = var.vm_defaults.disk_cache
  scsi_hardware              = var.vm_defaults.scsi_hardware
  efi_disk_type              = var.vm_defaults.efi_disk_type
  efi_disk_pre_enrolled_keys = var.vm_defaults.efi_disk_pre_enrolled_keys
  tablet_device              = var.vm_defaults.tablet_device
  migrate                    = var.vm_defaults.migrate
  cpu_units                  = var.vm_defaults.cpu_units

  bios          = each.value.bios
  machine       = each.value.machine
  hotplug       = each.value.hotplug
  cpu_numa      = each.value.cpu_numa
  cpu_flags     = each.value.cpu_flags
  on_boot       = each.value.on_boot
  started       = each.value.started
  agent_enabled = each.value.agent_enabled
  agent_timeout = each.value.agent_timeout

  network_devices = each.value.network_devices
  ip_configs      = each.value.ip_configs
  dns_servers     = each.value.dns_servers
  dns_domain      = each.value.dns_domain

  username        = each.value.username
  ssh_public_keys = each.value.ssh_public_keys
  password        = each.value.password
  packages        = each.value.packages
  package_upgrade = each.value.package_upgrade
  user_data       = each.value.user_data

  cloud_init_snippet   = each.value.cloud_init_snippet
  snippet_datastore_id = each.value.snippet_datastore_id
}
