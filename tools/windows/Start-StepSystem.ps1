param(
  [int]$Port = 8088,
  [string]$AdminUser = "admin",
  [string]$AdminPass = "admin123"
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Step System Launcher"

function Pause-Exit([int]$Code = 0) {
  Write-Host ""
  Write-Host "按回车退出..."
  [void][Console]::ReadLine()
  exit $Code
}

function Need-Command($Name, $InstallHint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    Write-Host "未检测到 $Name" -ForegroundColor Red
    Write-Host $InstallHint -ForegroundColor Yellow
    Pause-Exit 1
  }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "          步数系统 Windows 启动器" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Need-Command docker "请先安装并启动 Docker Desktop：https://www.docker.com/products/docker-desktop/"

try {
  docker info *> $null
} catch {
  Write-Host "Docker 未启动或当前用户无法访问 Docker。" -ForegroundColor Red
  Write-Host "请打开 Docker Desktop，等待左下角显示 running 后再运行本程序。" -ForegroundColor Yellow
  Pause-Exit 1
}

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $Root

if (-not (Test-Path "docker-compose.single.yml")) {
  Write-Host "未找到 docker-compose.single.yml，请在完整源码包目录内运行。" -ForegroundColor Red
  Pause-Exit 1
}

if (-not (Test-Path ".env")) {
  $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()
  $mysql = -join (1..32 | ForEach-Object { $chars | Get-Random })
  $token = -join (1..40 | ForEach-Object { $chars | Get-Random })
  @"
APP_ENV=production
APP_DEBUG=0
APP_URL=http://localhost:$Port

DB_HOST=127.0.0.1
DB_NAME=step_system
DB_USER=root
DB_PASS=$mysql
MYSQL_ROOT_PASSWORD=$mysql

INSTALL_TOKEN=$token
STEP_PROXY_API_URL=
"@ | Set-Content -Encoding UTF8 ".env"
  Write-Host "已生成 .env" -ForegroundColor Green
}

(Get-Content "docker-compose.single.yml") -replace '"[0-9]+:80"', ('"' + $Port + ':80"') | Set-Content -Encoding UTF8 "docker-compose.single.yml"

Write-Host "正在启动单容器服务，首次构建可能需要几分钟..." -ForegroundColor Yellow
docker compose -p step-single -f docker-compose.single.yml up -d --build
if ($LASTEXITCODE -ne 0) { Pause-Exit $LASTEXITCODE }

Write-Host "等待服务就绪..." -ForegroundColor Yellow
$ok = $false
for ($i=1; $i -le 90; $i++) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 "http://127.0.0.1:$Port/"
    if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { $ok = $true; break }
  } catch {
    Start-Sleep -Seconds 2
  }
}

if (-not $ok) {
  Write-Host "服务未按时就绪，请查看日志：" -ForegroundColor Red
  Write-Host "docker compose -p step-single -f docker-compose.single.yml logs -f step-system-single"
  Pause-Exit 1
}

if ($AdminUser -and $AdminPass) {
  Write-Host "正在初始化管理员..." -ForegroundColor Yellow
  $php = @'
require "/var/www/html/config/bootstrap.php";
require "/var/www/html/app/Core/Database.php";
use StepSystem\Core\Database;
$p = Database::pdo();
Database::migrate($p);
$u = getenv("STEP_ADMIN_USER");
$pw = getenv("STEP_ADMIN_PASS");
$p->prepare("DELETE FROM users WHERE role=?")->execute(["admin"]);
$p->prepare("INSERT INTO users(username,password,role,status,expires_at,created_at) VALUES(?,?,?,?,?,?)")
  ->execute([$u, password_hash($pw, PASSWORD_DEFAULT), "admin", 1, null, date("Y-m-d H:i:s")]);
echo "admin initialized: ".$u."\n";
'@
  docker exec -e STEP_ADMIN_USER=$AdminUser -e STEP_ADMIN_PASS=$AdminPass step-system-single php -r $php
}

$url = "http://127.0.0.1:$Port/"
Write-Host "" 
Write-Host "启动成功：$url" -ForegroundColor Green
Write-Host "默认管理员：admin / admin123" -ForegroundColor Green
Write-Host "常用命令：" -ForegroundColor Cyan
Write-Host "  docker compose -p step-single -f docker-compose.single.yml ps"
Write-Host "  docker compose -p step-single -f docker-compose.single.yml logs -f step-system-single"
Write-Host "  docker compose -p step-single -f docker-compose.single.yml restart"
Start-Process $url
Pause-Exit 0
