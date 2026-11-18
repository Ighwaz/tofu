terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.111.0, < 1.0.0"
    }
  }

  # Der State liegt in Silo (MinIO-Fork) aus bootstrap/, nicht lokal. Fuer Semaphore oder
  # jedes andere CI ist das Pflicht: Ein Runner bekommt pro Lauf ein frisches
  # Arbeitsverzeichnis und verliert einen lokalen State danach - der naechste
  # Durchgang wuerde alles ein zweites Mal anlegen wollen.
  backend "s3" {
    bucket = "tofu-state"
    key    = "proxmox/terraform.tfstate"

    endpoints = {
      s3 = "http://192.168.178.62:9000"
    }

    # Silo ist nicht AWS. Diese Schalter sagen dem Backend, dass es weder
    # Region noch Zugangsdaten gegen AWS pruefen und keinen
    # Instanz-Metadatendienst suchen soll. use_path_style, weil Silo den
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
    # OpenTofu schickt PutObject mit If-None-Match: "*". Liegt die Sperrdatei
    # schon, antworten MinIO und Silo mit 412 Precondition Failed, wie S3.
    # Nachgelesen in checkPreconditionsPUT, nicht erprobt; siehe README,
    # Abschnitt State-Backend.
    use_lockfile = true
  }

  # Access Key und Secret gehoeren NICHT in diese Datei - sie wird
  # eingecheckt. Stattdessen in die Umgebung:
  #   $env:AWS_ACCESS_KEY_ID     = '...'
  #   $env:AWS_SECRET_ACCESS_KEY = '...'
  # In Semaphore dieselben zwei Namen als Secret anlegen.
}
