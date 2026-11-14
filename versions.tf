terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.111.0, < 1.0.0"
    }
  }

  # Standardmaessig liegt der State lokal in terraform.tfstate. Fuer Semaphore
  # oder jedes andere CI reicht das nicht: Ein Runner bekommt pro Lauf ein
  # frisches Arbeitsverzeichnis und verliert ihn danach - der naechste
  # Durchgang wuerde alles ein zweites Mal anlegen wollen.
  #
  # Sobald MinIO aus bootstrap/ laeuft, diesen Block einkommentieren und mit
  # den Werten aus bootstrap/README.md fuellen. Danach einmal
  #   tofu init -migrate-state
  # - das schiebt den vorhandenen lokalen State in den Bucket.
  #
  # backend "s3" {
  #   bucket = "tofu-state"
  #   key    = "procmox/terraform.tfstate"
  #
  #   endpoints = {
  #     s3 = "http://192.168.178.61:9000"
  #   }
  #
  #   # MinIO ist nicht AWS. Diese Schalter sagen dem Backend, dass es weder
  #   # Region noch Zugangsdaten gegen AWS pruefen und keinen
  #   # Instanz-Metadatendienst suchen soll. use_path_style, weil MinIO den
  #   # Bucket im Pfad erwartet und nicht als Subdomain.
  #   region                      = "us-east-1"
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  #   skip_requesting_account_id  = true
  #   skip_metadata_api_check     = true
  #   use_path_style              = true
  #
  #   # Sperre ueber eine Lock-Datei im Bucket - kein DynamoDB noetig.
  #   # Setzt OpenTofu >= 1.10 voraus (required_version oben steht auf 1.6,
  #   # weil der Block hier auskommentiert ist) und ein MinIO, das bedingte
  #   # Schreibzugriffe beherrscht.
  #   use_lockfile = true
  # }
  #
  # Access Key und Secret gehoeren NICHT in diese Datei - sie wird
  # eingecheckt. Stattdessen in die Umgebung:
  #   $env:AWS_ACCESS_KEY_ID     = '...'
  #   $env:AWS_SECRET_ACCESS_KEY = '...'
  # In Semaphore dieselben zwei Namen als Secret anlegen.
}
