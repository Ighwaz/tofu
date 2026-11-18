# bootstrap — der Speicher für den State

Dieses Verzeichnis legt **einen** LXC-Container an (VMID 520,
`192.168.178.62`): den S3-Server, der den OpenTofu-State des
Hauptverzeichnisses aufnimmt. Darauf läuft seit dem 18.11.2026
[Silo](https://github.com/pgsty/silo), eine gepflegte Abspaltung von MinIO;
vorher war es MinIO selbst. Container, Ressource und Variablen heißen
weiterhin `minio`, damit sich am State nichts ändert.

## Warum ein eigenes Verzeichnis

Weil es sonst ein Kreis wäre. Der State des Hauptverzeichnisses soll in Silo
liegen. Läge der State des Silo-Containers ebenfalls dort, müsste Silo schon
laufen, bevor es angelegt werden kann.

Also: `bootstrap/` hat seinen eigenen, **lokalen** State. Er beschreibt genau
einen Container und ändert sich praktisch nie.

Das ist kein Trick, sondern das übliche Muster — irgendwo muss die Kette
anfangen. Wichtig ist nur, was daraus folgt:

> `bootstrap/terraform.tfstate` darf nicht verlorengehen. Ohne ihn weiß
> OpenTofu nichts mehr von Container und Volume und würde beides beim nächsten
> `apply` erneut anlegen wollen. Er enthält außerdem das API-Token im
> Klartext. Also: mitsichern, nicht einchecken.

Der Container hat deshalb `protection = true` — PVE verweigert dann das
Löschen, auch aus der Oberfläche heraus.

## Reihenfolge

```
1. bootstrap/  →  Container anlegen          (State lokal)
2. Ansible     →  Silo installieren, Bucket anlegen
3. Hauptverz.  →  Backend-Block eintragen, State migrieren
```

### 1. Container anlegen

```powershell
cd bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
# anpassen: template_file_id, ipv4_address, ssh_public_keys
$env:TF_VAR_proxmox_api_token = 'tofu@pve!provider=...'
tofu init
tofu plan
tofu apply
```

Die IP **muss** fest sein und außerhalb des DHCP-Bereichs liegen — sie steht
später im Backend-Block. Vorher prüfen, dass sie frei ist:

```powershell
ping 192.168.178.61
```

### 2. Silo einrichten

Das macht dieses Verzeichnis **nicht**. OpenTofu stellt den Container hin,
eingerichtet wird mit Ansible — dieselbe Trennung wie beim Rest des Homelabs.
Die Rolle `minio_server` im Ansible-Repository erledigt es:

```bash
# auf dem Ansible-Kontrollknoten
ansible-playbook playbooks/minio-setup.yml --ask-vault-pass
```

Sie installiert Silo und den Client `mcli`, legt Dienstnutzer, Datenverzeichnis,
Umgebungsdatei und systemd-Unit an, erzeugt den Bucket, schaltet die
Versionierung ein und legt den Dienstzugang für OpenTofu an. Ein zweiter Lauf
meldet `changed=0`.

Gebraucht werden vier Werte im Ansible-Vault: `vault_minio_root_user`,
`vault_minio_root_password`, `vault_minio_tofu_access_key` und
`vault_minio_tofu_secret_key`. Die Einzelheiten stehen im README des
Ansible-Repositorys unter *Silo: Ablage für den OpenTofu-State*; dort steht
auch, wie der Umzug von MinIO auf Silo lief.

> **Längen beachten.** Die Grenzen gelten an zwei Stellen unterschiedlich:
> Root-Benutzer ab 3 und Root-Passwort ab 8 Zeichen, beide **ohne**
> Obergrenze — der Tofu-Access-Key dagegen 3 bis 20 und das Tofu-Secret 8 bis
> **40** Zeichen. Ein zu langes Tofu-Secret fällt erst beim Anlegen des
> Dienstzugangs auf. Die Rolle prüft es inzwischen vorab.

#### Warum Silo und nicht mehr MinIO

Die fertigen Pakete von MinIO sind nicht mehr zu haben: `dl.min.io` antwortet
mit **HTTP 410 Gone**, die freie Fassung gibt es seit 2025 nur noch als
Quelltext. Die letzte gebaute Fassung (`RELEASE.2024-12-18T13-15-44Z`) bekam
keine Sicherheitsaktualisierungen mehr. Silo führt den Code weiter und
liefert Pakete; die Ansible-Rolle holt sie gepinnt und mit Prüfsumme aus den
GitHub-Releases:

| | |
|---|---|
| Server | `RELEASE.2026-11-12T00-00-00Z`, Paket `silo` (Dienst `silo.service`) |
| Client | dieselbe Fassung, Paket **`mcli`** |

Der Client liegt als `/usr/local/bin/mcli`, **nicht** als `mc`: So weicht er
dem Namenskonflikt mit Midnight Commander aus.

Die Weboberfläche läuft über Traefik unter `https://silo.lab.home.arpa`, mit
Anmeldung über Authelia. Die S3-Schnittstelle auf Port 9000 dagegen läuft
nicht über Traefik und bleibt im LAN.

### Abnahme

Auf dem Container, **ohne** `curl` — den bringt ein schlanker
Debian-Container nicht mit, Python ist dagegen immer da:

```bash
systemctl is-active silo
python3 -c 'import urllib.request as u; print(u.urlopen("http://127.0.0.1:9000/minio/health/live").status)'
```

Die letzte Zeile muss `200` ausgeben.

### 3. Backend im Hauptverzeichnis

Siehe den Abschnitt **State-Backend** in der README im Wurzelverzeichnis.

## Was hier absichtlich fehlt

Kein TLS auf der S3-Schnittstelle. Silo läuft im LAN auf `http://`, und der Backend-Block spricht es
unverschlüsselt an. Für ein Heimnetz hinter dem eigenen Router ist das
vertretbar, aber es ist eine bewusste Abwägung, keine Lücke aus Versehen:
Access Key und Secret gehen damit im Klartext über dein LAN. Wer das nicht
will, gibt Silo ein Zertifikat und stellt den Endpunkt auf `https://` um.
