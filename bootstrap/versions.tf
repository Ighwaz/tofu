terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.111.0, < 1.0.0"
    }
  }

  # Hier steht mit Absicht KEIN Backend.
  #
  # Dieses Verzeichnis legt den Container an, in dem spaeter der State des
  # Hauptverzeichnisses liegt. Laege sein eigener State ebenfalls dort, waere
  # das ein Kreis: MinIO liesse sich nie anlegen, weil der State dafuer schon
  # in MinIO liegen muesste.
  #
  # bootstrap/terraform.tfstate bleibt deshalb lokal. Er beschreibt genau
  # einen Container und aendert sich praktisch nie.
  #
  # Mitsichern: Ohne ihn verliert OpenTofu die Zuordnung zu Container und
  # Volume, und ein erneutes apply wollte beides neu anlegen.
  #
  # Nicht einchecken (die .gitignore faengt ihn ab). Das API-Token steht
  # allerdings NICHT darin - ein State haelt Ressourcen-Attribute und
  # Outputs, nicht die Provider-Konfiguration und nicht die Werte der
  # Eingabevariablen. Was hier sehr wohl drinsteht, sind Attribute der
  # Ressourcen selbst: bei Containern ein gesetztes root-Passwort, im
  # Hauptverzeichnis ausserdem die komplette cloud-init-Datei mit den
  # SSH-Keys. Grund genug, ihn nicht aus der Hand zu geben.
}
