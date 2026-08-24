locals {
  # Eingebauter Katalog gaengiger Debian-/Ubuntu-Cloud-Images.
  # Ueber var.image_catalog erweiter- und ueberschreibbar.
  default_image_catalog = {
    "debian-11" = {
      url       = "https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
      file_name = "debian-11-genericcloud-amd64.img"
    }
    "debian-12" = {
      url       = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
      file_name = "debian-12-genericcloud-amd64.img"
    }
    "debian-13" = {
      url       = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
      file_name = "debian-13-genericcloud-amd64.img"
    }
    "ubuntu-22.04" = {
      url       = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      file_name = "ubuntu-22.04-server-cloudimg-amd64.img"
    }
    "ubuntu-24.04" = {
      url       = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      file_name = "ubuntu-24.04-server-cloudimg-amd64.img"
    }
  }

  image_catalog = merge(
    {
      for name, image in local.default_image_catalog : name => {
        url                = image.url
        file_name          = image.file_name
        checksum           = ""
        checksum_algorithm = ""
      }
    },
    {
      for name, image in var.image_catalog : name => {
        url                = image.url
        file_name          = coalesce(image.file_name, basename(image.url))
        checksum           = coalesce(image.checksum, "")
        checksum_algorithm = coalesce(image.checksum_algorithm, "")
      }
    }
  )

  # Pro VM die Defaults aus var.vm_defaults mit den VM-spezifischen Werten mischen.
  vms = {
    for name, vm in var.vms : name => {
      node_name       = coalesce(vm.node_name, var.vm_defaults.node_name, var.node_name)
      image           = coalesce(vm.image, var.vm_defaults.image)
      vm_id           = vm.vm_id
      description     = coalesce(vm.description, "Managed by OpenTofu")
      datastore_id    = coalesce(vm.datastore_id, var.vm_defaults.datastore_id)
      cpu_cores       = coalesce(vm.cpu_cores, var.vm_defaults.cpu_cores)
      cpu_sockets     = coalesce(vm.cpu_sockets, var.vm_defaults.cpu_sockets)
      cpu_type        = coalesce(vm.cpu_type, var.vm_defaults.cpu_type)
      memory          = coalesce(vm.memory, var.vm_defaults.memory)
      memory_floating = coalesce(vm.memory_floating, var.vm_defaults.memory_floating)
      disk_size       = coalesce(vm.disk_size, var.vm_defaults.disk_size)
      disk_interface  = coalesce(vm.disk_interface, var.vm_defaults.disk_interface)
      disk_discard    = coalesce(vm.disk_discard, var.vm_defaults.disk_discard)
      disk_iothread   = coalesce(vm.disk_iothread, var.vm_defaults.disk_iothread)
      disk_ssd        = coalesce(vm.disk_ssd, var.vm_defaults.disk_ssd)
      extra_disks     = vm.extra_disks
      bios            = coalesce(vm.bios, var.vm_defaults.bios)
      machine         = try(coalesce(vm.machine, var.vm_defaults.machine), null)
      on_boot         = coalesce(vm.on_boot, var.vm_defaults.on_boot)
      started         = coalesce(vm.started, var.vm_defaults.started)
      pool_id         = try(coalesce(vm.pool_id, var.vm_defaults.pool_id), null)
      tags            = vm.tags == null ? var.vm_defaults.tags : vm.tags
      agent_enabled   = coalesce(vm.agent_enabled, var.vm_defaults.agent_enabled)
      agent_timeout   = coalesce(vm.agent_timeout, var.vm_defaults.agent_timeout)

      network_devices = vm.network_devices == null ? var.vm_defaults.network_devices : vm.network_devices
      ip_configs      = vm.ip_configs == null ? var.vm_defaults.ip_configs : vm.ip_configs
      dns_servers     = vm.dns_servers == null ? var.vm_defaults.dns_servers : vm.dns_servers
      dns_domain      = try(coalesce(vm.dns_domain, var.vm_defaults.dns_domain), null)

      username        = coalesce(vm.username, var.vm_defaults.username)
      ssh_public_keys = vm.ssh_public_keys == null ? var.vm_defaults.ssh_public_keys : vm.ssh_public_keys
      password        = try(coalesce(vm.password, var.vm_defaults.password), null)
      packages        = vm.packages == null ? var.vm_defaults.packages : vm.packages
      package_upgrade = coalesce(vm.package_upgrade, var.vm_defaults.package_upgrade)
      user_data       = vm.user_data

      cloud_init_snippet   = coalesce(vm.cloud_init_snippet, var.vm_defaults.cloud_init_snippet)
      snippet_datastore_id = coalesce(vm.snippet_datastore_id, var.vm_defaults.snippet_datastore_id)
    }
  }

  # Ein Image muss auf jedem Node vorliegen, auf dem es genutzt wird
  # (bei node-lokalen Datastores wie 'local'). Daher pro Node/Image-Kombination
  # ein Download.
  image_downloads = {
    for key in distinct([for name, vm in local.vms : "${vm.node_name}|${vm.image}"]) : key => {
      node_name = split("|", key)[0]
      image     = split("|", key)[1]
      known     = contains(keys(local.image_catalog), split("|", key)[1])

      spec = lookup(local.image_catalog, split("|", key)[1], {
        url                = ""
        file_name          = ""
        checksum           = ""
        checksum_algorithm = ""
      })
    }
  }

  template_catalog = {
    for tname, tpl in var.template_catalog : tname => {
      url                = tpl.url
      file_name          = coalesce(tpl.file_name, basename(tpl.url))
      checksum           = coalesce(tpl.checksum, "")
      checksum_algorithm = coalesce(tpl.checksum_algorithm, "")
    }
  }

  # Pro Container die Defaults aus var.lxc_defaults mit den Container-Werten mischen.
  containers = {
    for name, ct in var.containers : name => {
      node_name        = coalesce(ct.node_name, var.lxc_defaults.node_name, var.node_name)
      template         = try(coalesce(ct.template, var.lxc_defaults.template), null)
      template_file_id = try(coalesce(ct.template_file_id, var.lxc_defaults.template_file_id), null)
      os_type          = coalesce(ct.os_type, var.lxc_defaults.os_type)
      vm_id            = ct.vm_id
      description      = coalesce(ct.description, "Managed by OpenTofu")
      unprivileged     = coalesce(ct.unprivileged, var.lxc_defaults.unprivileged)
      datastore_id     = coalesce(ct.datastore_id, var.lxc_defaults.datastore_id)
      disk_size        = coalesce(ct.disk_size, var.lxc_defaults.disk_size)
      cpu_cores        = coalesce(ct.cpu_cores, var.lxc_defaults.cpu_cores)
      memory           = coalesce(ct.memory, var.lxc_defaults.memory)
      swap             = coalesce(ct.swap, var.lxc_defaults.swap)
      start_on_boot    = coalesce(ct.start_on_boot, var.lxc_defaults.start_on_boot)
      started          = coalesce(ct.started, var.lxc_defaults.started)
      protection       = coalesce(ct.protection, var.lxc_defaults.protection)
      pool_id          = ct.pool_id
      tags             = ct.tags == null ? var.lxc_defaults.tags : ct.tags
      mount_points     = ct.mount_points

      network_interfaces = ct.network_interfaces == null ? var.lxc_defaults.network_interfaces : ct.network_interfaces
      ip_configs         = ct.ip_configs == null ? var.lxc_defaults.ip_configs : ct.ip_configs
      dns_servers        = ct.dns_servers == null ? var.lxc_defaults.dns_servers : ct.dns_servers
      dns_domain         = try(coalesce(ct.dns_domain, var.lxc_defaults.dns_domain), null)

      ssh_public_keys = ct.ssh_public_keys == null ? var.lxc_defaults.ssh_public_keys : ct.ssh_public_keys
      password        = try(coalesce(ct.password, var.lxc_defaults.password), null)
      features        = ct.features == null ? var.lxc_defaults.features : ct.features
    }
  }

  # Templates, die OpenTofu selbst herunterladen soll - wie bei den Cloud-Images
  # pro Node/Template-Kombination einmal.
  template_downloads = {
    for key in distinct([
      for name, ct in local.containers : "${ct.node_name}|${ct.template}" if ct.template != null
    ]) : key => {
      node_name = split("|", key)[0]
      template  = split("|", key)[1]
      known     = contains(keys(var.template_catalog), split("|", key)[1])

      spec = lookup(local.template_catalog, split("|", key)[1], {
        url                = ""
        file_name          = ""
        checksum           = ""
        checksum_algorithm = ""
      })
    }
  }
}
