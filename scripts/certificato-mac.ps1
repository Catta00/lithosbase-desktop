# =============================================================================
# IL CERTIFICATO PER FIRMARE L'APP MAC, SENZA AVERE UN MAC.
#
# Un programma scaricato da internet, su Mac, si apre solo se e' firmato con un
# certificato "Developer ID Application" e poi notarizzato da Apple. Senza,
# macOS lo blocca: il cliente vede un avviso, pensa che il programma sia rotto,
# e non scrive per dirlo.
#
# Quel certificato si crea di solito dal Mac, con Accesso Portachiavi. Non ne
# abbiamo uno, ma non serve: la richiesta e il file finale si costruiscono con
# OpenSSL, che su Windows arriva insieme a Git.
#
# Lo script si ferma due volte e aspetta te: una per andare sul sito Apple, una
# per scegliere la password del file. Niente di quello che scrivi finisce nei
# log.
#
#   powershell -ExecutionPolicy Bypass -File .\scripts\certificato-mac.ps1
#
# Serve l'abbonamento Apple Developer, quello che paghi gia' per l'app iPhone.
# =============================================================================

$ErrorActionPreference = 'Stop'

function Titolo($t) { Write-Host ""; Write-Host $t -ForegroundColor Cyan; Write-Host ("-" * $t.Length) -ForegroundColor DarkGray }
function Passo($t)  { Write-Host "  $t" }
function Attesa($t) { Write-Host ""; Write-Host $t -ForegroundColor Yellow; [void](Read-Host "Premi Invio quando hai fatto") }

# ── OpenSSL ──────────────────────────────────────────────────────────────────
$openssl = (Get-Command openssl -ErrorAction SilentlyContinue).Source
if (-not $openssl) {
  $candidati = @(
    "C:\Program Files\Git\usr\bin\openssl.exe",
    "C:\Program Files\Git\mingw64\bin\openssl.exe",
    "C:\Program Files (x86)\Git\usr\bin\openssl.exe"
  )
  $openssl = $candidati | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $openssl) {
  Write-Host "OpenSSL non si trova. Arriva insieme a Git per Windows: installalo da git-scm.com e rilancia." -ForegroundColor Red
  exit 1
}

$cartella = Join-Path $PSScriptRoot "..\.certificato"
New-Item -ItemType Directory -Force -Path $cartella | Out-Null
$cartella = (Resolve-Path $cartella).Path
$chiave = Join-Path $cartella "chiave-privata.key"
$csr    = Join-Path $cartella "richiesta.certSigningRequest"
$cer    = Join-Path $cartella "developerID.cer"
$pem    = Join-Path $cartella "developerID.pem"
$ca     = Join-Path $cartella "AppleWWDR-DeveloperID.pem"
$p12    = Join-Path $cartella "certificato.p12"
$b64    = Join-Path $cartella "certificato.p12.base64.txt"

Titolo "1. La richiesta da mandare ad Apple"

if (Test-Path $chiave) {
  Passo "La chiave privata c'e' gia', la riuso: $chiave"
} else {
  & $openssl genrsa -out $chiave 2048 2>$null
  Passo "Chiave privata creata."
}

$soggetto = "/emailAddress=filippocattaneo00@gmail.com/CN=Lithosbase/C=AU"
& $openssl req -new -key $chiave -out $csr -subj $soggetto 2>$null
Passo "Richiesta creata: $csr"

Write-Host ""
Passo "ATTENZIONE: il file chiave-privata.key e' la meta' segreta del certificato."
Passo "Non finisce su GitHub, non si manda a nessuno, e senza quello il"
Passo "certificato che scarichi da Apple non serve a niente. Tienine una copia."

Attesa @"
Adesso tocca a te, sul sito Apple:

  1. apri  https://developer.apple.com/account/resources/certificates/add
  2. scegli  Developer ID Application
     (NON "Apple Distribution": quella serve per l'App Store, a noi no)
  3. se ti chiede il tipo di profilo, scegli  G2 Sub-CA (Xcode 11 o successivo)
  4. carica il file  $csr
  5. scarica il certificato e salvalo qui, con questo nome esatto:
       $cer
"@

if (-not (Test-Path $cer)) {
  Write-Host "Non trovo $cer. Salvalo li' e rilancia lo script." -ForegroundColor Red
  exit 1
}

$emittente = & $openssl x509 -inform DER -in $cer -noout -issuer 2>$null
$scadenza  = (& $openssl x509 -inform DER -in $cer -noout -enddate 2>$null) -replace '^notAfter=', ''
if ($emittente -notmatch 'OUs*=s*G2') {
  Write-Host ""
  Write-Host "Questo certificato e' stato creato con Previous Sub-CA, non con G2." -ForegroundColor Red
  Write-Host "  Scade il: $scadenza"
  Write-Host ""
  Write-Host "Funzionerebbe, ma per pochi mesi: l'autorita' che lo firma scade il"
  Write-Host "1 febbraio 2027, e un certificato non puo' durare piu' di chi lo firma."
  Write-Host "Il G2 arriva al 2031."
  Write-Host ""
  Write-Host "Rifallo sulla stessa pagina, con lo stesso file di richiesta, mettendo"
  Write-Host "il pallino su  G2 Sub-CA (Xcode 11.4.1 or later)  invece che su"
  Write-Host "Previous Sub-CA, che il sito lascia selezionato di suo. Poi sovrascrivi"
  Write-Host "  $cer"
  Write-Host "e rilancia."
  exit 1
}
Passo "Certificato G2, scade il $scadenza."

Titolo "2. Il file unico da dare a GitHub"

& $openssl x509 -inform DER -in $cer -out $pem 2>$null
Passo "Certificato convertito."

# La catena di Apple serve alla notarizzazione: senza l'intermedio, la firma
# risulta valida in locale ma Apple la rifiuta.
try {
  Invoke-WebRequest -Uri "https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer" -OutFile "$ca.der" -UseBasicParsing
  & $openssl x509 -inform DER -in "$ca.der" -out $ca 2>$null
  Passo "Scaricato anche il certificato intermedio di Apple."
  $conCatena = $true
} catch {
  Passo "Non sono riuscito a scaricare l'intermedio di Apple: proseguo senza."
  $conCatena = $false
}

Write-Host ""
Write-Host "Scegli una password per il file .p12." -ForegroundColor Yellow
Write-Host "Serve solo a proteggere il file, la userai una volta sola: la incolli"
Write-Host "in un segreto su GitHub e poi non la vedi piu'. Inventane una lunga."
$pwd1 = Read-Host "Password" -AsSecureString
$pwd2 = Read-Host "Ripetila" -AsSecureString
$p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd1))
$p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd2))
if ($p1 -ne $p2) { Write-Host "Le due password non coincidono." -ForegroundColor Red; exit 1 }
if ($p1.Length -lt 8) { Write-Host "Troppo corta: almeno 8 caratteri." -ForegroundColor Red; exit 1 }

$env:P12PASS = $p1
if ($conCatena) {
  & $openssl pkcs12 -export -out $p12 -inkey $chiave -in $pem -certfile $ca -name "Developer ID Application" -passout env:P12PASS 2>$null
} else {
  & $openssl pkcs12 -export -out $p12 -inkey $chiave -in $pem -name "Developer ID Application" -passout env:P12PASS 2>$null
}
$env:P12PASS = ""
$p1 = $null; $p2 = $null

if (-not (Test-Path $p12)) { Write-Host "Creazione del .p12 non riuscita." -ForegroundColor Red; exit 1 }
Passo "Creato: $p12"

[Convert]::ToBase64String([IO.File]::ReadAllBytes($p12)) | Set-Content -Path $b64 -NoNewline
Passo "Scritto in forma incollabile: $b64"

Titolo "3. I cinque segreti su GitHub"

Write-Host @"
  Vai su:
    https://github.com/Catta00/lithosbase-desktop/settings/secrets/actions

  e crea questi, con "New repository secret":

    MAC_CERT_P12                  tutto il contenuto di
                                  $b64
    MAC_CERT_PASSWORD             la password che hai appena scelto
    APPLE_ID                      la mail del tuo account Apple Developer
    APPLE_APP_SPECIFIC_PASSWORD   una password dedicata, si crea in un minuto su
                                  https://account.apple.com  ->  Accesso e sicurezza
                                  ->  Password per app
    APPLE_TEAM_ID                 le dieci lettere che trovi in alto a destra su
                                  https://developer.apple.com/account

  Poi, sempre su GitHub:  Actions  ->  Build macOS  ->  Run workflow.
  Il referto in cima alla pagina deve chiudere con "Esito: consegnabile".
"@

Titolo "4. Da cancellare quando hai finito"

Write-Host @"
  La cartella  $cartella  contiene la chiave privata e il certificato.
  Mettila in un posto sicuro (non dentro il progetto, non su GitHub) e poi
  toglila da qui. Ti serve solo quando il certificato scade, fra cinque anni.
"@
Write-Host ""
