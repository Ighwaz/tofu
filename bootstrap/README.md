# bootstrap — der Speicher für den State

Dieses Verzeichnis legt **einen** LXC-Container an: einen MinIO-Server, der
den OpenTofu-State des Hauptverzeichnisses aufnimmt.

## Warum ein eigenes Verzeichnis

Weil es sonst ein Kreis wäre. Der State des Hauptverzeichnisses soll in MinIO
liegen. Läge der State des MinIO-Containers ebenfalls dort, müsste MinIO schon
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
2. von Hand    →  MinIO installieren, Bucket anlegen
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

### 2. MinIO einrichten

Das macht dieses Verzeichnis **nicht**. OpenTofu stellt den Container hin,
eingerichtet wird mit Ansible — dieselbe Trennung wie beim Rest des Homelabs.
Die Rolle `minio_server` im Ansible-Repository erledigt es:

```bash
# auf dem Ansible-Kontrollknoten
ansible-playbook playbooks/minio-setup.yml --ask-vault-pass
```

Sie installiert MinIO und den Client, legt Dienstnutzer, Datenverzeichnis,
Umgebungsdatei und systemd-Unit an, erzeugt den Bucket, schaltet die
Versionierung ein und legt den Dienstzugang für OpenTofu an. Ein zweiter Lauf
meldet `changed=0`.

Gebraucht werden vier Werte im Ansible-Vault: `vault_minio_root_user`,
`vault_minio_root_password`, `vault_minio_tofu_access_key` und
`vault_minio_tofu_secret_key`. Die Einzelheiten stehen im README des
Ansible-Repositorys unter *MinIO: Ablage für den OpenTofu-State*.

> **Längen beachten.** MinIO setzt sie an zwei Stellen unterschiedlich durch:
> Root-Benutzer ab 3 und Root-Passwort ab 8 Zeichen, beide **ohne**
> Obergrenze — der Tofu-Access-Key dagegen 3 bis 20 und das Tofu-Secret 8 bis
> **40** Zeichen. Ein zu langes Tofu-Secret fällt erst beim Anlegen des
> Dienstzugangs auf. Die Rolle prüft es inzwischen vorab.

#### Von Hand geht nicht mehr so, wie es hier mal stand

Die frühere Anleitung in diesem Abschnitt ist nicht bloß überholt, sie
funktioniert nicht: Beide Downloads antworten mit **HTTP 410 Gone**.

```
https://dl.min.io/server/minio/release/linux-amd64/minio.deb   -> 410
https://dl.min.io/client/mc/release/linux-amd64/mc             -> 410
```

MinIO gibt die freie Fassung seit 2025 nur noch als Quelltext heraus; die
fertigen Pakete gehören zum kostenpflichtigen AIStor. Die Ansible-Rolle holt
deshalb gepinnte Pakete aus den GitHub-Releases:

| | |
|---|---|
| Server | `RELEASE.2024-12-18T13-15-44Z`, Paket `minio` |
| Client | `RELEASE.2025-08-13T08-35-41Z`, Paket **`mcli`** |

Zwei Dinge, über die man sonst stolpert:

- Das Client-Paket heißt `mcli` und legt die Binärdatei als
  `/usr/local/bin/mcli` ab, **nicht** als `mc` — so weicht es dem
  Namenskonflikt mit Midnight Commander aus. Auf dem Container heißt der
  Befehl also `mcli`.
- Das Server-Paket bringt **kein `postinst`** mit, legt also weder Benutzer
  noch Gruppe an, obwohl seine Unit `User=minio-user` verlangt. Die Rolle
  legt den Benutzer selbst an.

> **Diese Server-Fassung bekommt keine Sicherheitsaktualisierungen mehr.**
> Darum gehört MinIO hier nicht über Traefik nach außen und bekommt keinen
> öffentlichen Host: erreichbar nur im LAN. Sobald dort Daten liegen, die
> mehr als dieses Labor betreffen, ist das der Moment zu wechseln — Garage
> und SeaweedFS sprechen dasselbe S3 und werden gepflegt.

### Abnahme

Auf dem Container, **ohne** `curl` — den bringt ein schlanker
Debian-Container nicht mit, Python ist dagegen immer da:

```bash
systemctl is-active minio
python3 -c 'import urllib.request as u; print(u.urlopen("http://127.0.0.1:9000/minio/health/live").status)'
```

Die letzte Zeile muss `200` ausgeben.

### 3. Backend im Hauptverzeichnis

Siehe den Abschnitt **State-Backend** in der README im Wurzelverzeichnis.

## Was hier absichtlich fehlt

Kein TLS. MinIO läuft im LAN auf `http://`, und der Backend-Block spricht es
unverschlüsselt an. Für ein Heimnetz hinter dem eigenen Router ist das
vertretbar, aber es ist eine bewusste Abwägung, keine Lücke aus Versehen:
Access Key und Secret gehen damit im Klartext über dein LAN. Wer das nicht
will, legt ein Zertifikat in `/etc/minio/certs/` und stellt den Endpunkt auf
`https://` um.
