# Скрипт для первого push на GitHub
# Использование:
#   1. Создайте пустой репозиторий на https://github.com/new
#   2. Укажите URL вашего репозитория ниже в переменной $repoUrl
#   3. Запустите: .\push-to-github.ps1

$repoUrl = "https://github.com/ВАШ_USERNAME/ИМЯ_РЕПОЗИТОРИЯ.git"  # <-- ЗАМЕНИТЕ на свой URL!

$ErrorActionPreference = "Stop"

Write-Host "Push на GitHub" -ForegroundColor Cyan
Write-Host ""

if ($repoUrl -match "ВАШ_USERNAME|ИМЯ_РЕПОЗИТОРИЯ") {
    Write-Host "ОШИБКА: Замените repoUrl в скрипте на URL вашего репозитория!" -ForegroundColor Red
    Write-Host "Пример: https://github.com/john/api-gateway.git" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path .git)) {
    Write-Host "Инициализация git..." -ForegroundColor Green
    git init
}

$remote = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Добавление remote origin..." -ForegroundColor Green
    git remote add origin $repoUrl
} elseif ($remote -ne $repoUrl) {
    Write-Host "Обновление remote origin..." -ForegroundColor Green
    git remote set-url origin $repoUrl
}

Write-Host "Добавление файлов..." -ForegroundColor Green
git add .

Write-Host "Статус:" -ForegroundColor Green
git status --short

Write-Host ""
$commit = git rev-parse HEAD 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Первый коммит..." -ForegroundColor Green
    git commit -m "Initial commit: Nginx + Kong + Keycloak API Gateway with mTLS"
}

git branch -M main 2>$null

Write-Host ""
Write-Host "Push на origin main..." -ForegroundColor Green
Write-Host "Может потребоваться авторизация (логин + Personal Access Token)." -ForegroundColor Yellow
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Готово! Репозиторий на GitHub." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Если запросили пароль - используйте Personal Access Token вместо пароля." -ForegroundColor Yellow
    Write-Host "Создать: GitHub -> Settings -> Developer settings -> Personal access tokens" -ForegroundColor Yellow
}
