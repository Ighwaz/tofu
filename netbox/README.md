# netbox — Bestand nach NetBox

Dieses Verzeichnis trägt in [NetBox](https://netbox.lab.home.arpa) ein, was
im tofu-Repo steht:

| Was | Woher |
|---|---|
| Standort, Netz `192.168.178.0/24`, DHCP-Bereich | `variables.tf` / `terraform.tfvars` |
| Feste Geräte (FritzBox, procmox, Switch, …) mit Schnittstelle, MAC, IP | `devices` in `terraform.tfvars` |
| Cluster `procmox` (Typ Proxmox VE) | fest |
| Jeder Container und jede VM aus dem Hauptverzeichnis mit VMID, CPU, RAM, Platten, MAC und fester IP | State des Hauptverzeichnisses (Output `netbox_inventory`) |

Alles davon trägt den Tag `opentofu`. Was in NetBox mit diesem Tag steht,
gehört OpenTofu: Von Hand geändert, setzt es der nächste `apply` zurück. Was
nicht im Repo steht (von Hand angelegte Gäste, Geräte aus der FritzBox), trägt
später der Abgleich von Ansible nach, mit eigenen Tags.

Provider: [`e-breuninger/netbox`](https://search.opentofu.org/provider/e-breuninger/netbox/latest)
6.0.x, passend zu NetBox 4.6.8 bis 4.6.10.

## Warum ein eigenes Verzeichnis

Damit NetBox nie Proxmox aufhält. Ist NetBox gerade nicht erreichbar oder
lehnt einen Wert ab, scheitert nur dieser Plan; Container und VMs lassen sich
weiter anlegen. Der State liegt getrennt im selben Bucket
(`netbox/terraform.tfstate`), die Gäste liest dieses Verzeichnis nur aus dem
State des Hauptverzeichnisses.

## Einmalig einrichten

1. **API-Token in NetBox anlegen:** *Admin → API Tokens → Add*, Benutzer
   `admin` (oder ein eigener Benutzer `opentofu`), *Write enabled* an. Den
   Token einmal kopieren; NetBox zeigt ihn danach nicht mehr.
2. **Hauptverzeichnis einmal anwenden**, damit dessen State den neuen Output
   `netbox_inventory` enthält:
   ```powershell
   tofu plan -out=tfplan   # zeigt nur "Changes to Outputs"
   tofu apply tfplan
   ```
3. **Variablen anlegen:**
   ```powershell
   cd netbox
   Copy-Item terraform.tfvars.example terraform.tfvars
   # Geräte eintragen
   ```

## Anwenden

Zugang wie im Hauptverzeichnis, dazu der Token:

```powershell
.\env.ps1    # im Wurzelverzeichnis: Silo-Zugang und NetBox-Token

cd netbox
tofu init
tofu plan -out=tfplan
tofu apply tfplan
```

Beim ersten Lauf legt OpenTofu viele Objekte auf einmal an. Laufen dabei
Anfragen in die Wartezeit (`context deadline exceeded`), mit weniger
gleichzeitigen Anfragen weitermachen: `tofu apply -parallelism=3 tfplan`.
Vorher in NetBox nachsehen, ob die gemeldeten Objekte doch angelegt wurden,
und sie dann loeschen - sonst scheitert der naechste Versuch an "existiert
bereits".

**Nach jedem `apply` im Hauptverzeichnis** hier einmal `plan`/`apply`, sonst
hinkt NetBox hinterher. Ein Gast, der im Hauptverzeichnis verschwindet,
verschwindet hier beim nächsten Lauf aus NetBox.

Fehlt der Output im State des Hauptverzeichnisses, bricht der Plan mit einem
Hinweis ab, statt alle Gäste aus NetBox zu löschen.

## Was wohin kommt

| NetBox | aus |
|---|---|
| Virtuelle Maschine, Name | Schlüssel in `containers` bzw. `vms` |
| Rolle | `LXC-Container` oder `Virtuelle Maschine` |
| Seriennummer | VMID |
| Beschreibung | Typ, VMID, Betriebssystem |
| Kommentar | `description` aus dem Hauptverzeichnis |
| vCPUs, RAM | `cpu_cores` (bei VMs mal `cpu_sockets`), `memory` |
| Virtuelle Platten | Wurzelplatte, Mountpoints (nur Größen in `G`), Zusatzplatten |
| Schnittstelle `eth0` (LXC) bzw. `net0` (VM) | erste Netzwerkkarte, MAC als primäre MAC |
| Primäre IPv4 | erste `ip_configs`-Adresse, **nur wenn fest**; bei DHCP keine |
| Host | das Gerät mit `hosts_guests = true`, wenn der Gast auf diesem Node läuft |

Plattengrößen stehen in MiB (GiB × 1024); NetBox rechnet zur Anzeige durch
1000, eine 16-GiB-Platte erscheint also als 16,38 GB.

## Lock-Datei

Nach dem ersten `tofu init` liegt hier `.terraform.lock.hcl`. Die Datei
einchecken, wie die im Hauptverzeichnis: Sie hält die Prüfsummen des
Providers fest.

## NetBox aktualisieren

Erst wenn eine Provider-Version die neue NetBox-Version unterstützt
(Tabelle in der Provider-Doku), beides gemeinsam heben: hier `version` in
`versions.tf`, in Ansible `netbox_version` und `netbox_docker_version` der
Rolle `netbox_server`.
