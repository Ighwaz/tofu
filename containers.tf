# LXC-Template je Node/Template-Kombination auf den PVE-Storage laden.
# Nur fuer Container, die 'template' (Katalog-Eintrag) statt 'template_file_id' nutzen.
resource "proxmox_download_file" "container_template" {
  for_each = local.template_downloads

  content_type        = "vztmpl"
  datastore_id        = var.template_datastore_id
  node_name           = each.value.node_name
  url                 = each.value.spec.url
  file_name           = each.value.spec.file_name
  checksum            = each.value.spec.checksum != "" ? each.value.spec.checksum : null
  checksum_algorithm  = each.value.spec.checksum_algorithm != "" ? each.value.spec.checksum_algorithm : null
  overwrite_unmanaged = true

  lifecycle {
    precondition {
      condition     = each.value.known
      error_message = "Unbekanntes Template '${each.value.template}'. In var.template_catalog definiert sind: ${join(", ", keys(var.template_catalog))}."
    }
  }
}

module "lxc" {
  source   = "./modules/lxc"
  for_each = local.containers

  name        = each.key
  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  description = each.value.description
  tags        = each.value.tags
  pool_id     = each.value.pool_id

  # Entweder das selbst heruntergeladene Template oder eine direkt angegebene
  # File-ID (Template liegt bereits per 'pveam download' auf dem Node).
  template_file_id = try(
    proxmox_download_file.container_template[
      each.value.template == null ? "ohne-katalog" : "${each.value.node_name}|${each.value.template}"
    ].id,
    each.value.template_file_id
  )

  os_type      = each.value.os_type
  unprivileged = each.value.unprivileged

  cpu_cores    = each.value.cpu_cores
  memory       = each.value.memory
  swap         = each.value.swap
  datastore_id = each.value.datastore_id
  disk_size    = each.value.disk_size
  mount_points = each.value.mount_points
  features     = each.value.features

  start_on_boot = each.value.start_on_boot
  started       = each.value.started
  protection    = each.value.protection

  network_interfaces = each.value.network_interfaces
  ip_configs         = each.value.ip_configs
  dns_servers        = each.value.dns_servers
  dns_domain         = each.value.dns_domain

  ssh_public_keys = each.value.ssh_public_keys
  password        = each.value.password
}
