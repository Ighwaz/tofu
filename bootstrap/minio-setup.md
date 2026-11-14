# MinIO einrichten — Vorgabe für die Ansible-Rolle

Dieses Dokument beschreibt, was nach `tofu apply` in `bootstrap/` noch zu tun
ist. Es ist die Schnittstelle zwischen diesem Repo und dem Ansible-Repo:
OpenTofu stellt den Container hin, Ansible richtet ihn ein.

> **Ungetestet.** Ich konnte nichts davon ausprobieren — weder habe ich Zugang
> zu deiner Node, noch lässt sich MinIO hier installieren. Die Schritte sind
> der dokumentierte Ablauf, nicht ein von mir verifizierter. Prüf sie gegen
> die [offizielle Doku](https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-single-node-single-drive.html),
> bevor du dich darauf verlässt. Die Abnahmekriterien weiter unten sind der
> Teil, auf den es ankommt: Was dort grün ist, funktioniert.

## Ausgangslage

Nach `bootstrap/tofu apply` existiert:

| | |
| --- | --- |
| LXC-Container | unprivilegiert, Debian 13, VMID aus `vm_id` (Vorgabe 520) |
| IP | fest, aus `ipv4_address` — **ändert sich nicht**, der Backend-Block zeigt darauf |
| Root-Disk | 8 GiB auf `bigpool` |
| Datenvolume | eigenes Volume, gemountet auf `/var/lib/minio`, `backup = true` |
| Zugang | `root` per SSH-Key aus `ssh_public_keys` |
| Löschschutz | `protection = true` |

Ansible soll **nichts** davon anfassen — Größe, Mounts und Netz gehören
OpenTofu. Alles unterhalb des Dateisystems gehört Ansible.

## Inventory

Der Container gehört in `inventory/hosts.yml` unter `lxc`, wie die anderen:

```yaml
        minio:
          pve_vmid: 520
          ansible_host: 192.168.178.61   # = ipv4_address ohne Präfix
```

## Was die Rolle tun muss

### 1. Datenverzeichnis

MinIO bekommt **nicht** `/var/lib/minio` selbst, sondern ein Unterverzeichnis:

```
/var/lib/minio/data
```

Grund: `/var/lib/minio` ist der Mountpunkt des Volumes. MinIO legt in seinem
Datenverzeichnis eigene Strukturen an und verträgt sich schlecht mit allem,
was ein Dateisystem im Wurzelverzeichnis sonst noch ablegt. Ein
Unterverzeichnis kostet nichts und nimmt die Frage raus.

Eigentümer muss der Benutzer sein, unter dem der Dienst läuft — beim
`.deb`-Paket ist das `minio-user:minio-user`.

### 2. MinIO installieren

Paket von `https://dl.min.io/server/minio/release/linux-amd64/minio.deb`,
per `apt`/`dpkg`. Das Paket bringt Binary, systemd-Unit und den Benutzer mit.

Idempotent über eine Versionsprüfung (`minio --version`) statt blindem
Herunterladen bei jedem Lauf.

### 3. `/etc/default/minio`

```
MINIO_VOLUMES="/var/lib/minio/data"
MINIO_OPTS="--address :9000 --console-address :9001"
MINIO_ROOT_USER=<aus Vault>
MINIO_ROOT_PASSWORD=<aus Vault>
```

Rechte `0640`, Eigentümer `root:minio-user`. Die Datei enthält das
Root-Passwort im Klartext — sie darf nicht world-readable sein.

Bei Änderung: `notify` auf einen Neustart von `minio`.

### 4. Dienst

`systemd`-Unit `minio` aktivieren und starten. Danach muss
`http://127.0.0.1:9000/minio/health/live` mit 200 antworten.

### 5. `mc` installieren

Von `https://dl.min.io/client/mc/release/linux-amd64/mc`, nach
`/usr/local/bin/mc`, Modus `0755`. Auch hier Versionsprüfung statt
Dauer-Download.

### 6. Alias, Bucket, Versionierung

```bash
mc alias set local http://127.0.0.1:9000 <root-user> <root-password>
mc mb --ignore-existing local/tofu-state
mc version enable local/tofu-state
```

`--ignore-existing` macht `mb` idempotent. `mc version enable` ist ebenfalls
wiederholbar.

**Versionierung ist nicht optional.** Ein State, dessen Schreibvorgang
abbricht, ist sonst verloren — mit Versionierung holst du den letzten heilen
Stand zurück. Das ist der einzige Schutz, den du hast, wenn beim
`tofu apply` das Netz wegbricht.

### 7. Zugangsschlüssel für OpenTofu

**Nicht den Root-Benutzer verwenden.** OpenTofu bekommt einen eigenen
Service-Account mit fest vorgegebenen Schlüsseln aus dem Vault:

```bash
mc admin user svcacct add local <root-user> \
  --access-key  <aus Vault> \
  --secret-key  <aus Vault>
```

Ohne `--access-key`/`--secret-key` würfelt MinIO bei jedem Lauf neue
Zugangsdaten aus — das wäre nicht idempotent, und du müsstest sie nach jedem
Ansible-Lauf neu im Backend eintragen. Mit festen Werten aus dem Vault läuft
die Rolle beliebig oft.

Der Befehl schlägt fehl, wenn der Account schon existiert. Vorher prüfen:

```bash
mc admin user svcacct ls local <root-user>
```

und nur anlegen, wenn der Access Key dort nicht auftaucht.

## Variablen für den Vault

| Variable | Zweck |
| --- | --- |
| `minio_root_user` | Administrator von MinIO. Nur für Verwaltung, nicht für OpenTofu |
| `minio_root_password` | dito — lang und zufällig |
| `minio_tofu_access_key` | Zugangsschlüssel für den OpenTofu-Service-Account |
| `minio_tofu_secret_key` | zugehöriges Geheimnis — lang und zufällig |

Alle vier gehören in `ansible-vault`, keines davon ins Klartext-Inventory.

## Abnahmekriterien

Das hier ist der verlässliche Teil. Was hier durchläuft, funktioniert —
unabhängig davon, ob die Schritte oben noch zur aktuellen MinIO-Version
passen.

Auf dem Container:

```bash
systemctl is-active minio                       # -> active
curl -fsS http://127.0.0.1:9000/minio/health/live && echo OK
mc ls local/                                    # -> tofu-state
mc version info local/tofu-state                # -> Enabled
```

Vom Arbeitsplatzrechner aus — das ist der eigentliche Test, denn von dort
spricht OpenTofu den Dienst an:

```powershell
curl.exe -fsS http://192.168.178.61:9000/minio/health/live
```

Und zuletzt, im Hauptverzeichnis dieses Repos, nach dem Einkommentieren des
Backend-Blocks:

```powershell
$env:AWS_ACCESS_KEY_ID     = '<minio_tofu_access_key>'
$env:AWS_SECRET_ACCESS_KEY = '<minio_tofu_secret_key>'
tofu init -migrate-state
tofu plan
```

`tofu plan` muss **null Änderungen** zeigen. Zeigt er welche, ist beim Umzug
etwas schiefgegangen — dann nicht applyen, sondern nachsehen.

## Stolpersteine

- **MinIO startet nicht, `Unable to use the drive`** — meist gehört
  `/var/lib/minio/data` nicht `minio-user`, oder `MINIO_VOLUMES` zeigt auf
  den Mountpunkt statt auf das Unterverzeichnis.
- **Firewall** — Port 9000 muss vom Arbeitsplatzrechner und vom
  Semaphore-Runner erreichbar sein. Im flachen Heimnetz ist das gegeben,
  aber es ist die erste Stelle, an der man sucht.
- **Kein TLS.** Der Backend-Block spricht `http://`. Access Key und Secret
  gehen damit im Klartext über dein LAN. Für ein Heimnetz hinter dem eigenen
  Router vertretbar, aber eine bewusste Abwägung. Wer das nicht will, legt
  Zertifikate nach `/etc/minio/certs/` und stellt den Endpunkt auf `https://`
  um — dann aber auch im Backend-Block.
- **`/etc/default/minio` ist world-readable**, wenn man die Rechte nicht
  setzt. Dort steht das Root-Passwort.
