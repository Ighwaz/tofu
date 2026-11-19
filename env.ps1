<#
  Zugangsdaten fuer OpenTofu in DIESEM PowerShell-Fenster setzen.

    .\env.ps1          fragt nur, was im Fenster noch fehlt
    .\env.ps1 -Neu     fragt alles neu ab

  Die Datei enthaelt keine Geheimnisse und darf eingecheckt werden. Secret und
  Token werden verdeckt abgefragt und leben nur als Umgebungsvariablen dieses
  Fensters; ein neues Fenster braucht einen neuen Aufruf.

  Zur Kontrolle zeigt das Skript die ersten 8 Zeichen eines SHA-256 des
  Silo-Secrets. Gegenprobe auf CT 112:
    ansible minio -m debug -a "msg='{{ (vault_minio_tofu_secret_key | hash(\"sha256\"))[:8] }}'" --ask-vault-pass

  Laeuft fuer Windows PowerShell 5.1 und PowerShell 7. Absichtlich ohne
  Umlaute: 5.1 liest Dateien ohne BOM als ANSI.
#>
param(
    [switch]$Neu,
    [string]$AccessKey = 'tofu-state'
)

function Read-Geheim([string]$Frage) {
    # Read-Host -MaskInput gibt es erst ab PowerShell 7.1.
    $sicher = Read-Host -AsSecureString $Frage
    $zeiger = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sicher)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($zeiger).Trim()
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($zeiger)
    }
}

function Get-Kurzhash([string]$Wert) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Wert))
        return (-join ($bytes | ForEach-Object { $_.ToString('x2') })).Substring(0, 8)
    }
    finally {
        $sha.Dispose()
    }
}

$env:AWS_ACCESS_KEY_ID = $AccessKey

if ($Neu -or -not $env:AWS_SECRET_ACCESS_KEY) {
    $env:AWS_SECRET_ACCESS_KEY = Read-Geheim 'Silo-Secret (vault_minio_tofu_secret_key)'
}
if ($Neu -or -not $env:NETBOX_API_TOKEN) {
    $env:NETBOX_API_TOKEN = Read-Geheim 'NetBox-API-Token'
}

# --- Kontrolle, ohne etwas Geheimes auszugeben -------------------------------

$secret = $env:AWS_SECRET_ACCESS_KEY
$token  = $env:NETBOX_API_TOKEN

if (-not $secret) {
    Write-Warning 'Silo-Secret fehlt. Nochmal: .\env.ps1 -Neu'
}
else {
    $hinweis = ''
    if ($secret -notmatch '^[A-Za-z0-9]{8,40}$') {
        $hinweis = '  <- erwartet 8 bis 40 Buchstaben/Ziffern, Leer- oder Sonderzeichen mitkopiert?'
    }
    Write-Host ("Silo:   {0} / Secret {1} Zeichen, Hash {2}{3}" -f $env:AWS_ACCESS_KEY_ID, $secret.Length, (Get-Kurzhash $secret), $hinweis)
}

if (-not $token) {
    Write-Warning 'NetBox-Token fehlt. Nochmal: .\env.ps1 -Neu'
}
elseif ($token -notmatch '^nbt_[A-Za-z0-9]+\.[A-Za-z0-9]+$') {
    Write-Warning 'NetBox-Token hat nicht die Form nbt_<Key>.<Token> - nur ein Teil kopiert?'
}
else {
    Write-Host ("NetBox: Token gesetzt ({0} Zeichen)" -f $token.Length)
}

Remove-Variable secret, token
