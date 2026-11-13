locals {
  # Stabiler Geraetepfad je Zusatzplatte. /dev/sdb waere je nach
  # Erkennungsreihenfolge eine andere Platte; ueber die Serial, die jede Disk
  # oben mitbekommt, ist der Pfad eindeutig. Das Praefix haengt am Bustyp:
  # virtio-blk meldet sich anders als ein SCSI-Geraet.
  disk_by_id_prefix = {
    scsi   = "scsi-0QEMU_QEMU_HARDDISK_"
    virtio = "virtio-"
    sata   = "ata-QEMU_HARDDISK_"
  }

  # Nur Platten, die ein Dateisystem UND einen Mountpunkt nennen, richtet
  # cloud-init ein. Alles andere bleibt unangetastet in der VM haengen.
  managed_disks = [
    for extra in var.extra_disks : {
      device     = "/dev/disk/by-id/${lookup(local.disk_by_id_prefix, replace(extra.interface, "/[0-9]+$/", ""), "scsi-0QEMU_QEMU_HARDDISK_")}drive-${extra.interface}"
      filesystem = extra.filesystem
      mount      = extra.mount
      # Kosmetisches Dateisystem-Label aus dem Mountpunkt. min() deckelt die
      # Laenge, ohne bei kurzen Pfaden ueber das Stringende hinauszugreifen.
      label = substr(
        replace(extra.mount, "/[^A-Za-z0-9]/", ""),
        0,
        min(12, length(replace(extra.mount, "/[^A-Za-z0-9]/", "")))
      )
    }
    if extra.filesystem != null && extra.mount != null
  ]

  generated_user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    hostname        = var.name
    username        = var.username
    password        = var.password
    ssh_public_keys = var.ssh_public_keys
    packages        = var.packages
    package_upgrade = var.package_upgrade
    managed_disks   = local.managed_disks
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
  scsi_hardware   = var.scsi_hardware
  tablet_device   = var.tablet_device
  migrate         = var.migrate
  hotplug         = var.hotplug
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
    units   = var.cpu_units
    numa    = var.cpu_numa
    flags   = var.cpu_flags
  }

  memory {
    dedicated = var.memory
    floating  = var.memory_floating
  }

  # Bei UEFI braucht die VM eine EFI-Disk, sonst findet sie nichts zum Booten.
  # Wird automatisch angelegt, wenn bios = "ovmf" gesetzt ist.
  dynamic "efi_disk" {
    for_each = var.bios == "ovmf" ? [1] : []

    content {
      datastore_id      = var.datastore_id
      file_format       = var.disk_file_format
      type              = var.efi_disk_type
      pre_enrolled_keys = var.efi_disk_pre_enrolled_keys
    }
  }

  # Boot-Disk: Klon des Cloud-Images.
  disk {
    datastore_id = var.datastore_id
    file_id      = var.image_file_id
    interface    = var.disk_interface
    size         = var.disk_size
    file_format  = var.disk_file_format
    discard      = var.disk_discard
    iothread     = var.disk_iothread
    ssd          = var.disk_ssd
    aio          = var.disk_aio
    cache        = var.disk_cache
    # Feste Serial, damit der Gast die Platte unter einem stabilen Pfad unter
    # /dev/disk/by-id findet - unabhaengig von der Reihenfolge der Erkennung.
    serial = "drive-${var.disk_interface}"
  }

  dynamic "disk" {
    for_each = { for extra in var.extra_disks : extra.interface => extra }

    content {
      datastore_id = coalesce(disk.value.datastore_id, var.datastore_id)
      interface    = disk.value.interface
      size         = disk.value.size
      file_format  = try(coalesce(disk.value.file_format, var.disk_file_format), null)
      discard      = disk.value.discard
      iothread     = disk.value.iothread
      ssd          = disk.value.ssd
      backup       = disk.value.backup
      aio          = var.disk_aio
      cache        = var.disk_cache
      serial       = "drive-${disk.value.interface}"
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
      # Multiqueue: eine Queue je Kern verteilt die Netzlast auf mehrere
      # vCPUs. Ohne das haengt der ganze Verkehr an einem Kern.
      queues = coalesce(network_device.value.queues, var.cpu_cores)
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

    precondition {
      condition     = length([for extra in var.extra_disks : extra if extra.ssd && startswith(extra.interface, "virtio")]) == 0
      error_message = "VM '${var.name}': Eine Zusatzplatte auf einem virtio-Interface kann kein ssd = true haben. Interface auf scsi aendern oder ssd = false setzen."
    }

    precondition {
      condition     = length([for extra in var.extra_disks : extra if(extra.filesystem == null) != (extra.mount == null)]) == 0
      error_message = "VM '${var.name}': Bei einer Zusatzplatte sind 'filesystem' und 'mount' nur gemeinsam sinnvoll - cloud-init braucht beides, um sie einzurichten."
    }
  }
}
