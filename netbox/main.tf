locals {
  # Jedes Objekt, das dieses Root anlegt, traegt den Tag. Der Abgleich von
  # Ansible laesst alles damit in Ruhe. Ueber die Referenz statt ueber
  # default_tags im Provider, damit der Tag sicher vor allem anderen existiert.
  tags = [netbox_tag.opentofu.slug]

  inventory = var.guests != null ? var.guests : lookup(
    data.terraform_remote_state.proxmox[0].outputs, "netbox_inventory", null
  )
  guests = local.inventory == null ? {} : local.inventory

  host_names = [for name, d in var.devices : name if d.hosts_guests]
  host_name  = length(local.host_names) > 0 ? local.host_names[0] : null

  manufacturers = toset([for d in var.devices : d.manufacturer])
  device_roles  = toset([for d in var.devices : d.role])
  device_types = {
    for d in var.devices : "${d.manufacturer}|${d.model}" => {
      manufacturer = d.manufacturer
      model        = d.model
    }...
  }

  guest_roles = {
    lxc  = { name = "LXC-Container", color = "4caf50" }
    qemu = { name = "Virtuelle Maschine", color = "2196f3" }
  }

  device_macs = { for name, d in var.devices : name => d if d.mac != null }
  device_ips  = { for name, d in var.devices : name => d if d.ipv4 != null }
  guest_macs  = { for name, g in local.guests : name => g if g.mac != null && g.mac != "" }
  guest_ips   = { for name, g in local.guests : name => g if g.ipv4 != null }

  guest_disks = merge([
    for name, g in local.guests : {
      for disk in g.disks : "${name}|${disk.name}" => {
        guest   = name
        name    = disk.name
        size_mb = disk.size_gb * 1024
      }
    }
  ]...)
}

###############################################################################
# Grundgeruest
###############################################################################

resource "netbox_tag" "opentofu" {
  name        = "opentofu"
  slug        = "opentofu"
  color_hex   = "7b42bc"
  description = "Von OpenTofu verwaltet (tofu-Repo). Hier nicht von Hand aendern - der naechste apply setzt es zurueck."
}

resource "netbox_site" "home" {
  name     = var.site_name
  status   = "active"
  timezone = var.time_zone
  tags     = local.tags
}

resource "netbox_prefix" "lan" {
  prefix  = var.prefix
  status  = "active"
  site_id = netbox_site.home.id
  tags    = local.tags
}

resource "netbox_ip_range" "dhcp" {
  count = var.dhcp_range == null ? 0 : 1

  start_address = var.dhcp_range.start
  end_address   = var.dhcp_range.end
  status        = "active"
  description   = "DHCP der FritzBox"
  tags          = local.tags
}

###############################################################################
# Feste Geraete
###############################################################################

resource "netbox_manufacturer" "this" {
  for_each = local.manufacturers

  name = each.value
  tags = local.tags
}

resource "netbox_device_type" "this" {
  for_each = local.device_types

  manufacturer_id = netbox_manufacturer.this[each.value[0].manufacturer].id
  model           = each.value[0].model
  tags            = local.tags
}

resource "netbox_device_role" "this" {
  for_each = local.device_roles

  name = each.value
  tags = local.tags
}

resource "netbox_device" "this" {
  for_each = var.devices

  name           = each.key
  device_type_id = netbox_device_type.this["${each.value.manufacturer}|${each.value.model}"].id
  role_id        = netbox_device_role.this[each.value.role].id
  site_id        = netbox_site.home.id
  status         = "active"
  serial         = each.value.serial
  description    = each.value.description
  # Der Proxmox-Host gehoert zum Cluster; NetBox zeigt dann bei ihm die Gaeste.
  cluster_id = each.value.hosts_guests ? netbox_cluster.proxmox.id : null
  tags       = local.tags
}

resource "netbox_device_interface" "this" {
  for_each = var.devices

  device_id = netbox_device.this[each.key].id
  name      = each.value.interface
  type      = each.value.interface_type
  tags      = local.tags
}

resource "netbox_mac_address" "device" {
  for_each = local.device_macs

  mac_address         = upper(each.value.mac)
  device_interface_id = netbox_device_interface.this[each.key].id
  tags                = local.tags
}

resource "netbox_device_interface_primary_mac_address" "this" {
  for_each = local.device_macs

  device_interface_id = netbox_device_interface.this[each.key].id
  mac_address_id      = netbox_mac_address.device[each.key].id
}

resource "netbox_ip_address" "device" {
  for_each = local.device_ips

  ip_address          = each.value.ipv4
  status              = "active"
  dns_name            = each.value.dns_name
  device_interface_id = netbox_device_interface.this[each.key].id
  tags                = local.tags
}

resource "netbox_primary_ip" "device" {
  for_each = local.device_ips

  device_id     = netbox_device.this[each.key].id
  ip_address_id = netbox_ip_address.device[each.key].id
}

###############################################################################
# Proxmox
###############################################################################

resource "netbox_cluster_type" "proxmox" {
  name = "Proxmox VE"
  tags = local.tags
}

resource "netbox_cluster" "proxmox" {
  name            = var.cluster_name
  cluster_type_id = netbox_cluster_type.proxmox.id
  site_id         = netbox_site.home.id
  status          = "active"
  tags            = local.tags

  lifecycle {
    precondition {
      condition     = local.inventory != null
      error_message = "Im State des Haupt-Roots fehlt der Output netbox_inventory. Dort einmal `tofu apply` laufen lassen (aendert nur die Outputs), dann hier wieder."
    }
  }
}

###############################################################################
# Gaeste aus dem Haupt-Root
###############################################################################

resource "netbox_device_role" "guest" {
  for_each = local.guest_roles

  name      = each.value.name
  color_hex = each.value.color
  vm_role   = true
  tags      = local.tags
}

resource "netbox_virtual_machine" "this" {
  for_each = local.guests

  name       = each.key
  cluster_id = netbox_cluster.proxmox.id
  site_id    = netbox_site.home.id
  # Am Host nur, wenn er als Geraet eingetragen ist und der Gast auf ihm laeuft.
  device_id     = each.value.node_name == local.host_name ? netbox_device.this[local.host_name].id : null
  role_id       = netbox_device_role.guest[each.value.type].id
  status        = each.value.started ? "active" : "offline"
  start_on_boot = each.value.start_on_boot ? "on" : "off"
  vcpus         = each.value.cpu_cores
  memory_mb     = each.value.memory_mb
  serial        = tostring(each.value.vm_id)
  description   = "${upper(each.value.type)} ${each.value.vm_id}, ${each.value.os_type}"
  comments      = each.value.description
  tags          = local.tags
}

resource "netbox_virtual_disk" "this" {
  for_each = local.guest_disks

  virtual_machine_id = netbox_virtual_machine.this[each.value.guest].id
  name               = each.value.name
  size_mb            = each.value.size_mb
  tags               = local.tags
}

resource "netbox_virtual_machine_interface" "this" {
  for_each = local.guests

  virtual_machine_id = netbox_virtual_machine.this[each.key].id
  name               = each.value.type == "lxc" ? "eth0" : "net0"
  tags               = local.tags
}

resource "netbox_mac_address" "guest" {
  for_each = local.guest_macs

  mac_address                  = upper(each.value.mac)
  virtual_machine_interface_id = netbox_virtual_machine_interface.this[each.key].id
  tags                         = local.tags
}

resource "netbox_virtual_machine_interface_primary_mac_address" "this" {
  for_each = local.guest_macs

  virtual_machine_interface_id = netbox_virtual_machine_interface.this[each.key].id
  mac_address_id               = netbox_mac_address.guest[each.key].id
}

resource "netbox_ip_address" "guest" {
  for_each = local.guest_ips

  ip_address                   = each.value.ipv4
  status                       = "active"
  virtual_machine_interface_id = netbox_virtual_machine_interface.this[each.key].id
  tags                         = local.tags
}

resource "netbox_primary_ip" "guest" {
  for_each = local.guest_ips

  virtual_machine_id = netbox_virtual_machine.this[each.key].id
  ip_address_id      = netbox_ip_address.guest[each.key].id
}
