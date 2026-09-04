Write-Host "=== Heliantha Mobile ===" -ForegroundColor Cyan

Write-Host "`n1) Préparation backend FastAPI" -ForegroundColor Yellow
Set-Location "$PSScriptRoot\backend"

if (-not (Test-Path ".venv")) {
    python -m venv .venv
}

& ".\.venv\Scripts\python.exe" -m pip install -r requirements.txt

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Fichier backend\.env créé. Configure la clé PrestaShop." -ForegroundColor Green
}

Write-Host "`n2) Préparation Flutter" -ForegroundColor Yellow
Set-Location "$PSScriptRoot\mobile"

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    flutter create .
    flutter pub get
    Write-Host "Flutter prêt." -ForegroundColor Green
} else {
    Write-Host "Flutter n'est pas installé ou pas dans PATH." -ForegroundColor Red
}

Set-Location $PSScriptRoot

Write-Host "`nTerminé." -ForegroundColor Cyan
Write-Host "Backend : cd backend ; .\.venv\Scripts\Activate.ps1 ; uvicorn app.main:app --reload"
Write-Host "Flutter  : cd mobile ; flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000"
