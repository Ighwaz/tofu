output "vms" {
  description = "Uebersicht der erzeugten VMs."
  value = {
    for name, vm in module.vm : name => {
      vm_id          = vm.vm_id
      node_name      = vm.node_name
      ipv4_addresses = vm.ipv4_addresses
      mac_addresses  = vm.mac_addresses
    }
  }
}

output "vm_ipv4" {
  description = "Erste nicht-loopback IPv4-Adresse je VM (benoetigt aktiven QEMU-Guest-Agent)."
  value = {
    for name, vm in module.vm : name => try(
      [for addresses in vm.ipv4_addresses : addresses[0] if length(addresses) > 0 && addresses[0] != "127.0.0.1"][0],
      null
    )
  }
}

output "downloaded_images" {
  description = "Auf den Nodes bereitgestellte Cloud-Images."
  value       = { for key, image in proxmox_download_file.cloud_image : key => image.id }
}

output "containers" {
  description = "Uebersicht der erzeugten LXC-Container."
  value = {
    for name, ct in module.lxc : name => {
      vm_id     = ct.vm_id
      node_name = ct.node_name
    }
  }
}

output "downloaded_templates" {
  description = "Auf den Nodes bereitgestellte LXC-Templates."
  value       = { for key, template in proxmox_download_file.container_template : key => template.id }
}
