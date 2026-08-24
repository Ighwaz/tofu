resource "proxmox_virtual_environment_container" "this" {
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = var.description
  tags        = var.tags
  pool_id     = var.pool_id

  unprivileged  = var.unprivileged
  start_on_boot = var.start_on_boot
  started       = var.started
  protection    = var.protection

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  dynamic "mount_point" {
    for_each = { for mount in var.mount_points : mount.path => mount }

    content {
      volume    = coalesce(mount_point.value.volume, var.datastore_id)
      size      = mount_point.value.size
      path      = mount_point.value.path
      backup    = mount_point.value.backup
      read_only = mount_point.value.read_only
    }
  }

  dynamic "features" {
    for_each = var.features.nesting || var.features.fuse || var.features.keyctl || length(var.features.mount) > 0 ? [1] : []

    content {
      nesting = var.features.nesting
      fuse    = var.features.fuse
      keyctl  = var.features.keyctl
      mount   = length(var.features.mount) > 0 ? var.features.mount : null
    }
  }

  initialization {
    hostname = var.name

    dynamic "ip_config" {
      for_each = var.ip_configs

      content {
        dynamic "ipv4" {
          for_each = ip_config.value.ipv4_address == null ? [] : [1]

          content {
            address = ip_config.value.ipv4_address
            gateway = ip_config.value.ipv4_address == "dhcp" ? null : ip_config.value.ipv4_gateway
          }
        }

        dynamic "ipv6" {
          for_each = ip_config.value.ipv6_address == null ? [] : [1]

          content {
            address = ip_config.value.ipv6_address
            gateway = contains(["dhcp", "auto"], ip_config.value.ipv6_address) ? null : ip_config.value.ipv6_gateway
          }
        }
      }
    }

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 || var.dns_domain != null ? [1] : []

      content {
        servers = length(var.dns_servers) > 0 ? var.dns_servers : null
        domain  = var.dns_domain
      }
    }

    user_account {
      keys     = var.ssh_public_keys
      password = var.password
    }
  }

  dynamic "network_interface" {
    for_each = { for index, nic in var.network_interfaces : index => nic }

    content {
      name        = coalesce(network_interface.value.name, "veth${network_interface.key}")
      bridge      = network_interface.value.bridge
      vlan_id     = network_interface.value.vlan_id
      mac_address = network_interface.value.mac_address
      mtu         = network_interface.value.mtu
      firewall    = network_interface.value.firewall
      rate_limit  = network_interface.value.rate_limit
    }
  }

  lifecycle {
    precondition {
      condition     = var.template_file_id != null
      error_message = "Container '${var.name}': Es muss entweder 'template' (Eintrag aus var.template_catalog) oder 'template_file_id' gesetzt sein."
    }

    precondition {
      condition     = length(var.ssh_public_keys) > 0 || var.password != null
      error_message = "Container '${var.name}': Es muss mindestens ein SSH-Key oder ein Passwort gesetzt sein, sonst gibt es keinen Login."
    }
  }
}
