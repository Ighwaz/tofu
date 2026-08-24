# OpenTofu für Proxmox VE

Deployt Debian- und Ubuntu-VMs auf einer Proxmox-VE-Instanz — auf Basis offizieller
Cloud-Images und cloud-init. VMs werden deklarativ in `terraform.tfvars` beschrieben,
die passenden Images lädt OpenTofu automatisch auf den PVE-Storage.

Provider: [`bpg/proxmox`](https://search.opentofu.org/provider/bpg/proxmox/latest)

## Aufbau

```
.
├── versions.tf              # OpenTofu- und Provider-Versionen, Backend-Vorlage
├── providers.tf             # Proxmox-Provider (API + SSH)
├── variables.tf             # Eingabevariablen
├── locals.tf                # Image-Katalog, Zusammenführen der VM-Defaults
├── main.tf                  # Image-Download + Aufruf des VM-Moduls je VM
├── outputs.tf               # VMIDs, IP-Adressen
├── terraform.tfvars.example # Beispielkonfiguration zum Kopieren
└── modules/vm/              # Wiederverwendbares Modul für eine cloud-init-VM
```

## Voraussetzungen auf dem Proxmox-Host

1. **API-Token anlegen** (empfohlen statt Passwort):

   ```bash
   pveum user add tofu@pve
   pveum aclmod / -user tofu@pve -role PVEAdmin
   pveum user token add tofu@pve provider --privsep 0
   ```

   Die ausgegebene Token-Secret nur einmal sichtbar — direkt notieren.

2. **Snippets aktivieren** auf dem Datastore, der die cloud-init-Dateien aufnimmt:
   `Datacenter → Storage → local → Edit → Content` und `Snippets` anhaken.

3. **SSH-Zugriff auf die Nodes**: Der Provider lädt die cloud-init-user-data per SSH
   (`scp`) hoch. Ein SSH-Key für `root@<node>` im SSH-Agent reicht.
   Wer keine Snippets nutzen will, setzt `cloud_init_snippet = false` — dann läuft
   alles über die API, es werden aber **keine Pakete installiert** (auch kein
   `qemu-guest-agent`, dann zusätzlich `agent_enabled = false` setzen).

## Loslegen

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars                     # Node-Name, Storage, SSH-Key, VMs eintragen

export TF_VAR_proxmox_api_token='tofu@pve!provider=xxxxxxxx-...'

tofu init
tofu plan
tofu apply
```

Danach:

```bash
tofu output vm_ipv4
ssh tofu@<ip>
```

Die beim `init` erzeugte `.terraform.lock.hcl` gehört ins Git — sie pinnt die
Provider-Version reproduzierbar.

## VMs definieren

Jeder Eintrag in `vms` ist eine VM; der Key ist Name und Hostname. Alles, was dort
nicht gesetzt ist, kommt aus `vm_defaults`:

```hcl
vm_defaults = {
  node_name       = "pve"
  image           = "debian-12"
  datastore_id    = "local-lvm"
  cpu_cores       = 2
  memory          = 2048
  disk_size       = 20
  username        = "tofu"
  ssh_public_keys = ["ssh-ed25519 AAAA... user@workstation"]
}

vms = {
  "debian-test" = {
    image = "debian-12"
  }

  "ubuntu-web" = {
    image     = "ubuntu-24.04"
    vm_id     = 1201
    cpu_cores = 4
    memory    = 4096
    disk_size = 40

    ip_configs = [{
      ipv4_address = "192.168.1.50/24"
      ipv4_gateway = "192.168.1.1"
    }]

    packages = ["qemu-guest-agent", "curl", "vim"]
  }
}
```

Eine neue VM = ein neuer Eintrag, danach `tofu apply`. Löschen des Eintrags
zerstört die VM.

## Verfügbare Images

| Key | Image |
| --- | --- |
| `debian-11` | Debian 11 (bullseye) genericcloud amd64 |
| `debian-12` | Debian 12 (bookworm) genericcloud amd64 |
| `debian-13` | Debian 13 (trixie) genericcloud amd64 |
| `ubuntu-22.04` | Ubuntu 22.04 LTS (jammy) server cloudimg amd64 |
| `ubuntu-24.04` | Ubuntu 24.04 LTS (noble) server cloudimg amd64 |

Alle Einträge zeigen auf die `latest`/`current`-URLs der Distributionen. Eigene oder
gepinnte Images gehen über `image_catalog`:

```hcl
image_catalog = {
  "ubuntu-25.04" = {
    url       = "https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-amd64.img"
    file_name = "ubuntu-25.04-server-cloudimg-amd64.img"
  }
}
```

Der Dateiname muss auf `.img` oder `.iso` enden — Proxmox akzeptiert im
Content-Type `iso` nichts anderes, auch wenn der Inhalt ein qcow2 ist.
Ein Image wird pro Node einmal geladen, auf dem es gebraucht wird.

## Wichtige Optionen pro VM

| Feld | Bedeutung | Default |
| --- | --- | --- |
| `node_name` | Ziel-Node | aus `vm_defaults` |
| `image` | Key aus dem Image-Katalog | `debian-12` |
| `vm_id` | feste VMID | automatisch |
| `cpu_cores`, `cpu_sockets`, `cpu_type` | CPU | 2 / 1 / `x86-64-v2-AES` |
| `memory`, `memory_floating` | RAM in MiB, Ballooning-Minimum | 2048 / 0 |
| `disk_size`, `datastore_id`, `disk_interface` | Boot-Disk | 20 GiB / `local-lvm` / `virtio0` |
| `extra_disks` | weitere Datendisks | `[]` |
| `network_devices` | Bridge, VLAN, MAC, MTU | `vmbr0` |
| `ip_configs` | `dhcp` oder CIDR + Gateway | `dhcp` |
| `dns_servers`, `dns_domain` | cloud-init DNS | Node-Vorgabe |
| `username`, `ssh_public_keys`, `password` | Login im Gast | `tofu`, Keys aus Defaults |
| `packages`, `package_upgrade` | cloud-init Paketinstallation | `["qemu-guest-agent"]`, `false` |
| `user_data` | komplette eigene cloud-config | generiert |
| `tags`, `pool_id`, `on_boot`, `started` | PVE-Metadaten | `["opentofu"]`, –, `true`, `true` |
| `bios`, `machine` | `seabios`/`ovmf`, z. B. `q35` | `seabios`, PVE-Default |
| `agent_enabled`, `agent_timeout` | QEMU-Guest-Agent | `true`, `15m` |

## Hinweise und Stolperfallen

- **`disk_size` muss mindestens so groß sein wie das Image** (Debian ~2 GiB,
  Ubuntu ~3,5 GiB). Vergrößern geht später, Verkleinern nicht.
- **SSD-Emulation** (`disk_ssd = true`) funktioniert nicht mit `virtio*`-Interfaces;
  dafür `disk_interface = "scsi0"` verwenden.
- **Guest-Agent**: `agent_enabled = true` lässt `apply` warten, bis der Agent
  antwortet. Das setzt voraus, dass `qemu-guest-agent` installiert wird — also
  `cloud_init_snippet = true` und das Paket in `packages`. Sonst läuft der Apply in
  den Timeout.
- **Passwörter** stehen im State im Klartext. Besser nur SSH-Keys verwenden und das
  API-Token über `TF_VAR_proxmox_api_token` setzen statt in eine Datei zu schreiben.
- **Änderung von `image`, `disk_interface` oder `datastore_id`** ersetzt die VM
  (Disk wird neu erstellt).
- Der State liegt standardmäßig lokal in `terraform.tfstate` und enthält
  Zugangsdaten — nicht einchecken (ist per `.gitignore` ausgeschlossen). Für den
  Mehrbenutzerbetrieb den Backend-Block in `versions.tf` ausfüllen.

## Modul direkt verwenden

`modules/vm` lässt sich auch einzeln einbinden:

```hcl
module "buildhost" {
  source = "./modules/vm"

  name          = "buildhost"
  node_name     = "pve"
  image_file_id = "local:iso/debian-12-genericcloud-amd64.img"

  cpu_cores       = 8
  memory          = 16384
  disk_size       = 100
  ssh_public_keys = ["ssh-ed25519 AAAA..."]
}
```
