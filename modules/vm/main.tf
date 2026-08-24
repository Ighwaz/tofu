locals {
  generated_user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    hostname        = var.name
    username        = var.username
    password        = var.password
    ssh_public_keys = var.ssh_public_keys
    packages        = var.packages
    package_upgrade = var.package_upgrade
  })

  user_data = var.user_data != null ? var.user_data : local.generated_user_data
}

# cloud-init user-data als Snippet auf den Node hochladen (via SSH).
resource "proxmox_virtual_environment_file" "user_data" {
  count = var.cloud_init_snippet ? 1 : 0

  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = var.node_name

  source_raw {
    data      = local.user_data
    file_name = "${var.name}-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  description = var.description
  tags        = var.tags
  node_name   = var.node_name
  vm_id       = var.vm_id
  pool_id     = var.pool_id

  on_boot         = var.on_boot
  started         = var.started
  bios            = var.bios
  machine         = var.machine
  stop_on_destroy = true

  agent {
    enabled = var.agent_enabled
    timeout = var.agent_timeout
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores   = var.cpu_cores
    sockets = var.cpu_sockets
    type    = var.cpu_type
  }

  memory {
    dedicated = var.memory
    floating  = var.memory_floating
  }

  # Boot-Disk: Klon des Cloud-Images.
  disk {
    datastore_id = var.datastore_id
    file_id      = var.image_file_id
    interface    = var.disk_interface
    size         = var.disk_size
    discard      = var.disk_discard
    iothread     = var.disk_iothread
    ssd          = var.disk_ssd
  }

  dynamic "disk" {
    for_each = { for extra in var.extra_disks : extra.interface => extra }

    content {
      datastore_id = coalesce(disk.value.datastore_id, var.datastore_id)
      interface    = disk.value.interface
      size         = disk.value.size
      discard      = disk.value.discard
      iothread     = disk.value.iothread
      ssd          = disk.value.ssd
      backup       = disk.value.backup
    }
  }

  initialization {
    datastore_id      = var.datastore_id
    user_data_file_id = one(proxmox_virtual_environment_file.user_data[*].id)

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

    # Ohne Snippet uebernimmt die native cloud-init Konfiguration der API
    # das Anlegen des Benutzers.
    dynamic "user_account" {
      for_each = var.cloud_init_snippet ? [] : [1]

      content {
        username = var.username
        keys     = var.ssh_public_keys
        password = var.password
      }
    }
  }

  dynamic "network_device" {
    for_each = var.network_devices

    content {
      bridge      = network_device.value.bridge
      model       = network_device.value.model
      vlan_id     = network_device.value.vlan_id
      mac_address = network_device.value.mac_address
      mtu         = network_device.value.mtu
      firewall    = network_device.value.firewall
    }
  }

  serial_device {}

  lifecycle {
    precondition {
      condition     = length(var.ssh_public_keys) > 0 || var.password != null
      error_message = "VM '${var.name}': Es muss mindestens ein SSH-Key oder ein Passwort gesetzt sein, sonst gibt es keinen Login."
    }

    precondition {
      condition     = !(var.disk_ssd && startswith(var.disk_interface, "virtio"))
      error_message = "VM '${var.name}': SSD-Emulation wird von virtio-Disks nicht unterstuetzt. Interface auf 'scsi0' aendern oder disk_ssd = false setzen."
    }
  }
}
