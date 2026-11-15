terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.111.0, < 1.0.0"
    }
  }

  # Der State liegt in MinIO aus bootstrap/, nicht lokal. Fuer Semaphore oder
  # jedes andere CI ist das Pflicht: Ein Runner bekommt pro Lauf ein frisches
  # Arbeitsverzeichnis und verliert einen lokalen State danach - der naechste
  # Durchgang wuerde alles ein zweites Mal anlegen wollen.
  backend "s3" {
    bucket = "tofu-state"
    key    = "proxmox/terraform.tfstate"

    endpoints = {
      s3 = "http://192.168.178.62:9000"
    }

    # MinIO ist nicht AWS. Diese Schalter sagen dem Backend, dass es weder
    # Region noch Zugangsdaten gegen AWS pruefen und keinen
    # Instanz-Metadatendienst suchen soll. use_path_style, weil MinIO den
    # Bucket im Pfad erwartet und nicht als Subdomain.
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    use_path_style              = true

    # Sperre ueber eine Lock-Datei im Bucket - kein DynamoDB noetig. Setzt
    # OpenTofu >= 1.10 voraus, daher required_version oben.
    #
    # Nachgelesen, weil MinIO hier von S3 abweicht: OpenTofu schickt
    # PutObject mit If-None-Match: "*". Liegt die Sperrdatei schon, antwortet
    # MinIO mit 304 Not Modified, wo S3 412 Precondition Failed schreibt.
    # Das faellt nicht auf, weil OpenTofu nicht auf einen bestimmten Code
    # prueft, sondern jeden Fehler beim Schreiben als "Sperre liegt schon"
    # behandelt - und 304 ist fuer das AWS-SDK ein Fehler. Es scheitert also
    # in der sicheren Richtung, nur mit einer merkwuerdig formulierten
    # Meldung bei einer echten Kollision.
    use_lockfile = true
  }

  # Access Key und Secret gehoeren NICHT in diese Datei - sie wird
  # eingecheckt. Stattdessen in die Umgebung:
  #   $env:AWS_ACCESS_KEY_ID     = '...'
  #   $env:AWS_SECRET_ACCESS_KEY = '...'
  # In Semaphore dieselben zwei Namen als Secret anlegen.
}
