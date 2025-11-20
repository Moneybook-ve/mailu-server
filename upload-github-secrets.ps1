# PowerShell script to upload .env secrets to GitHub repository environment (staging)
# Requires: GitHub CLI (gh) installed and authenticated
# Usage: .\upload-github-secrets.ps1 -EnvFile "mailu.env" -Repo "Moneybook-ve/mailu-server" -Environment "production"

param(
    [string]$EnvFile = "mailu.env",
    [string]$Repo = "Moneybook-ve/mailu-server",
    [string]$Environment = "production"
)

if (!(Test-Path $EnvFile)) {
    Write-Error "Environment file '$EnvFile' not found."
    exit 1
}

$lines = Get-Content $EnvFile
foreach ($line in $lines) {
    if ($line -match "^(\w+)=(.*)$") {
        $name = $matches[1]
        $value = $matches[2]
        Write-Host "Uploading secret: $name"
        gh secret set $name --body "$value" --repo $Repo --env $Environment
    }
}
Write-Host "All secrets uploaded to environment '$Environment' in repo '$Repo'."
