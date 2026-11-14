# Ein einzelner Container fuer MinIO. Mehr steht hier bewusst nicht drin:
# Je weniger in diesem State liegt, desto weniger haengt daran, dass er
# lokal bleibt.
#
# Die Software richtet dieses Verzeichnis NICHT ein - OpenTofu stellt den
# Container hin, installiert wird mit Ansible (oder einmalig von Hand).
# Siehe bootstrap/README.md.
module "minio" {
  source = "../modules/lxc"

  name             = var.name
  node_name        = var.node_name
  vm_id            = var.vm_id
  template_file_id = var.template_file_id
  os_type          = "debian"
  description      = "MinIO - S3-Backend fuer den OpenTofu-State. Angelegt aus bootstrap/."
  tags             = ["opentofu", "bootstrap", "minio"]

  cpu_cores    = var.cpu_cores
  memory       = var.memory
  swap         = var.swap
  datastore_id = var.datastore_id
  disk_size    = var.disk_size

  # Eigenes Volume fuer die Buckets, getrennt von der Root-Disk: Ein
  # vollgelaufenes Dateisystem legt dann nicht gleich den ganzen Container
  # lahm. backup = true, weil hier der State liegt.
  mount_points = [{
    path   = var.data_path
    size   = var.data_size
    volume = var.datastore_id
    backup = true
  }]

  network_interfaces = [{ bridge = var.bridge }]

  ip_configs = [{
    ipv4_address = var.ipv4_address
    ipv4_gateway = var.ipv4_gateway
  }]

  dns_servers = var.dns_servers
  dns_domain  = var.dns_domain

  ssh_public_keys = var.ssh_public_keys

  # Der State-Speicher soll nicht versehentlich mitgeloescht werden.
  protection = var.protection
}
