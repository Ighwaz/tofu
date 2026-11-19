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

# Lesestoff fuer das Root netbox/: Es holt sich diesen Output per
# terraform_remote_state und traegt jeden Gast in NetBox ein. Nur
# Konfiguration, keine Zugangsdaten - der Output landet unverschluesselt im
# State und ist fuer jeden lesbar, der den State lesen darf.
#
# ipv4 ist die fest konfigurierte Adresse mit Praefixlaenge
# ("192.168.178.11/24"), bei DHCP null: Dann weiss OpenTofu die Adresse nicht
# sicher, und NetBox bekommt sie spaeter aus dem Abgleich von Ansible.
output "netbox_inventory" {
  description = "Gaeste fuer das Root netbox/ (Name, VMID, Typ, Ressourcen, Adresse, MAC)."
  value = merge(
    {
      for name, ct in local.containers : name => {
        type          = "lxc"
        vm_id         = module.lxc[name].vm_id
        node_name     = module.lxc[name].node_name
        description   = ct.description
        tags          = ct.tags
        os_type       = ct.os_type
        cpu_cores     = ct.cpu_cores
        memory_mb     = ct.memory
        started       = ct.started
        start_on_boot = ct.start_on_boot
        disks = concat(
          [{ name = "rootfs", size_gb = ct.disk_size }],
          [
            for index, mp in ct.mount_points : {
              name    = "mp${index}"
              size_gb = tonumber(trimsuffix(upper(mp.size), "G"))
            } if can(tonumber(trimsuffix(upper(mp.size), "G")))
          ]
        )
        ipv4 = try(ct.ip_configs[0].ipv4_address == "dhcp" ? null : ct.ip_configs[0].ipv4_address, null)
        mac  = try(module.lxc[name].mac_addresses[0], null)
      }
    },
    {
      for name, vm in local.vms : name => {
        type          = "qemu"
        vm_id         = module.vm[name].vm_id
        node_name     = module.vm[name].node_name
        description   = vm.description
        tags          = vm.tags
        os_type       = vm.image
        cpu_cores     = vm.cpu_cores * vm.cpu_sockets
        memory_mb     = vm.memory
        started       = vm.started
        start_on_boot = vm.on_boot
        disks = concat(
          [{ name = "root", size_gb = vm.disk_size }],
          [for disk in vm.extra_disks : { name = disk.interface, size_gb = disk.size }]
        )
        ipv4 = try(vm.ip_configs[0].ipv4_address == "dhcp" ? null : vm.ip_configs[0].ipv4_address, null)
        mac  = try(module.vm[name].network_mac_addresses[0], null)
      }
    }
  )
}
