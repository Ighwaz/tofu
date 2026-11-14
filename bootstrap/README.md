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

### 2. MinIO installieren

Das macht dieses Verzeichnis **nicht**. OpenTofu stellt den Container hin,
eingerichtet wird mit Ansible — dieselbe Trennung wie beim Rest deines
Homelabs. Für den ersten Lauf geht es auch von Hand.

Der Ablauf in Stichworten (gegen die
[offizielle MinIO-Doku](https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-single-node-single-drive.html)
gegenprüfen — MinIOs Paketierung hat sich in den letzten Releases mehrfach
bewegt, und diese Schritte sind ungetestet):

```bash
# im Container
apt-get update && apt-get install -y wget
wget https://dl.min.io/server/minio/release/linux-amd64/minio.deb
dpkg -i minio.deb

cat > /etc/default/minio <<'EOF'
MINIO_VOLUMES="/var/lib/minio"
MINIO_OPTS="--address :9000 --console-address :9001"
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=<langes-zufaelliges-passwort>
EOF

chown -R minio-user:minio-user /var/lib/minio
systemctl enable --now minio
systemctl status minio
```

Dann Bucket und einen eigenen Zugangsschlüssel anlegen (nicht den
Root-Benutzer für den State verwenden):

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
chmod +x /usr/local/bin/mc

mc alias set local http://127.0.0.1:9000 admin <passwort>
mc mb local/tofu-state
mc version enable local/tofu-state          # Versionierung: rettet dich bei einem kaputten State
mc admin user svcacct add local admin       # gibt Access Key + Secret aus
```

`mc version enable` ist kein Luxus. Ein State, der beim Schreiben
abgeschnitten wird, ist sonst weg; mit Versionierung holst du den letzten
heilen Stand zurück.

### 3. Backend im Hauptverzeichnis

Siehe den Abschnitt **State-Backend** in der README im Wurzelverzeichnis.

## Was hier absichtlich fehlt

Kein TLS. MinIO läuft im LAN auf `http://`, und der Backend-Block spricht es
unverschlüsselt an. Für ein Heimnetz hinter dem eigenen Router ist das
vertretbar, aber es ist eine bewusste Abwägung, keine Lücke aus Versehen:
Access Key und Secret gehen damit im Klartext über dein LAN. Wer das nicht
will, legt ein Zertifikat in `/etc/minio/certs/` und stellt den Endpunkt auf
`https://` um.
