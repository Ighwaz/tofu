# Prueft den Output netbox_inventory, den das Root netbox/ per
# terraform_remote_state liest. Der Proxmox-Provider ist nachgebildet:
# `tofu test` braucht weder PVE noch Zugangsdaten.
#
#   tofu init -backend=false
#   tofu test

mock_provider "proxmox" {
  mock_resource "proxmox_download_file" {
    defaults = { id = "local:iso/debian-13-genericcloud-amd64.img" }
  }
  mock_resource "proxmox_virtual_environment_file" {
    defaults = { id = "local:snippets/semaphore-user-data.yaml" }
  }
}

variables {
  proxmox_api_token = "x@pve!t=00000000-0000-0000-0000-000000000000"
  lxc_defaults = {
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    ssh_public_keys  = ["ssh-ed25519 AAAA test"]
  }
  containers = {
    netbox = {
      vm_id        = 540
      memory       = 2048
      disk_size    = 16
      ip_configs   = [{ ipv4_address = "192.168.178.11/24", ipv4_gateway = "192.168.178.1" }]
      mount_points = [{ path = "/data", size = "50G" }, { path = "/x", size = "512M" }]
    }
    dhcpct = { vm_id = 541 }
  }
  vms = {
    semaphore = {
      vm_id           = 530
      ssh_public_keys = ["ssh-ed25519 AAAA test"]
      cpu_sockets     = 2
      extra_disks     = [{ interface = "scsi1", size = 10 }]
      network_devices = [{ mac_address = "BC:24:11:AA:BB:CC" }]
    }
  }
}

run "inventory" {
  command = apply

  assert {
    condition     = output.netbox_inventory["netbox"].ipv4 == "192.168.178.11/24"
    error_message = "ipv4 netbox"
  }
  assert {
    condition     = output.netbox_inventory["dhcpct"].ipv4 == null
    error_message = "dhcp muss null sein"
  }
  assert {
    condition     = length(output.netbox_inventory["netbox"].disks) == 2 && output.netbox_inventory["netbox"].disks[1].size_gb == 50
    error_message = "disks netbox: ${jsonencode(output.netbox_inventory["netbox"].disks)}"
  }
  assert {
    condition     = output.netbox_inventory["semaphore"].cpu_cores == 4 && output.netbox_inventory["semaphore"].type == "qemu"
    error_message = "vm cores/type"
  }
  assert {
    condition     = output.netbox_inventory["semaphore"].mac == "BC:24:11:AA:BB:CC"
    error_message = "vm mac: ${jsonencode(output.netbox_inventory["semaphore"].mac)}"
  }
  assert {
    condition     = output.netbox_inventory["netbox"].vm_id == 540 && output.netbox_inventory["netbox"].memory_mb == 2048
    error_message = "ct id/mem"
  }
}
