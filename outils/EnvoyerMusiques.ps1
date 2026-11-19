# Met en ligne les MP3 du dossier Musique sur Roblox (API Open Cloud) et note les ID obtenus.
# Clé API : un fichier texte qui contient seulement la clé (jamais dans le dépôt git).
# Usage : powershell -ExecutionPolicy Bypass -File outils\EnvoyerMusiques.ps1 -UserId 123456 [-CleFichier C:\Users\User\.roblox-cle.txt]
param(
    [Parameter(Mandatory = $true)][string]$UserId,
    [string]$CleFichier = "$env:USERPROFILE\.roblox-cle.txt",
    [string]$Dossier = "$PSScriptRoot\..\Musique",
    [string]$Resultats = "$PSScriptRoot\ids-musiques.txt"
)

$cle = (Get-Content -Raw -LiteralPath $CleFichier).Trim()
$temp = Join-Path $env:TEMP "mindset-envoi"
New-Item -ItemType Directory -Force $temp | Out-Null

# fichier MP3 (début du nom) -> nom affiché dans le jeu
$musiques = [ordered]@{
    "Ariis, Yb Wasgood - LUNA BALA" = "LUNA BALA"
    "Automotivo da Reciprocidade" = "Automotivo da Reciprocidade"
    "AUTOMOTIVO DECORADA" = "AUTOMOTIVO DECORADA"
    "Automotivo Mec" = "Automotivo Mec"
    "AUTOMOTIVO PEGA 1.0" = "AUTOMOTIVO PEGA 1.0"
    "BUF" = "BUFÓN!"
    "COM MEDO!" = "COM MEDO!"
    "COMING FOR YOU" = "COMING FOR YOU"
    "DJ BATIDAFUNK - MONTAGE SENNTANA" = "MONTAGE SENNTANA"
    "DJ ORBITAL - maldito movimiento" = "maldito movimiento"
    "ETERNITY" = "ETERNITY"
    "Fica De Quat" = "Fica De Quatão"
    "FUNK ABNORMAL" = "FUNK ABNORMAL"
    "HIMXN - TAK TAK" = "TAK TAK"
    "LUA NA PRA" = "LUA NA PRAÇA"
    "MATADORA" = "MATADORA"
    "ME VS ME" = "ME VS ME"
    "MONTAGEM BRAVO" = "MONTAGEM BRAVO"
    "MONTAGEM GUERREIRO" = "MONTAGEM GUERREIRO"
    "MONTAGEM IMPACTO" = "MONTAGEM IMPACTO"
    "MONTAGEM MELODIA EXPLOSIVA" = "MONTAGEM MELODIA EXPLOSIVA"
    "MONTAGEM PEGADORA" = "MONTAGEM PEGADORA"
    "MONTAGEM PENSAR" = "MONTAGEM PENSAR"
    "MONTAGEM REBOLA" = "MONTAGEM REBOLA"
    "MONTAGEM SUPERSONIC" = "MONTAGEM SUPERSONIC"
    "NEXUZ - RITMO AGRESSIVO" = "RITMO AGRESSIVO"
    "NO BATID" = "NO BATIDÃO"
    "NO ERA AMOR" = "NO ERA AMOR"
    "Ogryzek - EMPIRE" = "EMPIRE"
    "Pique do ombrinho" = "Pique do ombrinho"
    "SPACE!" = "SPACE!"
    "TIKI TIKI" = "TIKI TIKI"
    "TITAN!" = "TITAN!"
    "TODO LA VIDA" = "TODO LA VIDA"
    "UH VEI VEI" = "UH VEI VEI"
    "Your Next Opponent Is You" = "Your Next Opponent Is You"
}

# Les musiques déjà envoyées (relancer le script reprend là où il s'est arrêté)
$deja = @{}
if (Test-Path -LiteralPath $Resultats) {
    foreach ($ligne in Get-Content -LiteralPath $Resultats -Encoding UTF8) {
        $morceaux = $ligne -split '\|'
        if ($morceaux.Count -eq 2) { $deja[$morceaux[0]] = $morceaux[1] }
    }
}

$fichiers = Get-ChildItem -LiteralPath $Dossier -Filter *.mp3
$utf8 = New-Object System.Text.UTF8Encoding($false)
$n = 0
foreach ($debut in $musiques.Keys) {
    $nom = $musiques[$debut]
    $n++
    if ($deja.ContainsKey($nom)) { Write-Host "[$n] $nom : déjà envoyée ($($deja[$nom]))"; continue }
    $fichier = $fichiers | Where-Object { $_.Name.StartsWith($debut) } | Select-Object -First 1
    if (-not $fichier) { Write-Warning "[$n] $nom : fichier introuvable"; continue }

    # copie avec un nom simple (les accents et caractères spéciaux gênent curl)
    $copie = Join-Path $temp "musique.mp3"
    Copy-Item -LiteralPath $fichier.FullName $copie -Force
    $requete = Join-Path $temp "requete.json"
    $json = @{
        assetType = "Audio"
        displayName = $nom
        description = "Mindset Stairs"
        creationContext = @{ creator = @{ userId = $UserId } }
    } | ConvertTo-Json -Depth 5 -Compress
    [System.IO.File]::WriteAllText($requete, $json, $utf8)

    $reponse = curl.exe -s -X POST "https://apis.roblox.com/assets/v1/assets" `
        -H "x-api-key: $cle" `
        -F "request=<$requete;type=application/json" `
        -F "fileContent=@$copie;type=audio/mpeg"
    $op = $null
    try { $op = $reponse | ConvertFrom-Json } catch {}
    if (-not $op -or -not $op.operationId) { Write-Warning "[$n] $nom : refusé -> $reponse"; continue }

    # on attend que Roblox ait fini de traiter le son
    $assetId = $null
    for ($essai = 0; $essai -lt 30 -and -not $assetId; $essai++) {
        Start-Sleep -Seconds 2
        $etat = curl.exe -s "https://apis.roblox.com/assets/v1/operations/$($op.operationId)" -H "x-api-key: $cle" | ConvertFrom-Json
        if ($etat.done) {
            if ($etat.response.assetId) { $assetId = $etat.response.assetId }
            else { Write-Warning "[$n] $nom : échec -> $($etat | ConvertTo-Json -Depth 6 -Compress)"; break }
        }
    }
    if ($assetId) {
        Add-Content -LiteralPath $Resultats -Value "$nom|$assetId" -Encoding UTF8
        Write-Host "[$n] $nom : OK -> rbxassetid://$assetId"
    } elseif (-not $etat.done) {
        Write-Warning "[$n] $nom : toujours en traitement (opération $($op.operationId)), relance le script plus tard"
    }
}
Write-Host "Terminé. Résultats dans $Resultats"
