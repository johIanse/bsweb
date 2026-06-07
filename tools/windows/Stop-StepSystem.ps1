$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $Root
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Host "未检测到 docker" -ForegroundColor Red
  exit 1
}
docker compose -p step-single -f docker-compose.single.yml down
Write-Host "步数系统已停止，数据库 volume 已保留。" -ForegroundColor Green
Write-Host "按回车退出..."
[void][Console]::ReadLine()
