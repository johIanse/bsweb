param(
  [int]$Port = 8088,
  [string]$AdminUser = "admin",
  [string]$AdminPass = "admin123"
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Step System Portable"

function Pause-Exit([int]$Code = 0) {
  Write-Host ""
  Write-Host "按回车退出..."
  [void][Console]::ReadLine()
  exit $Code
}

$Root = Split-Path -Parent $PSScriptRoot
$Php = Join-Path $Root "runtime\php\php.exe"
$Node = Join-Path $Root "runtime\node\node.exe"
$DataDir = Join-Path $Root "data"
$DbPath = Join-Path $DataDir "step-system.sqlite"
$PublicDir = Join-Path $Root "public"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "        步数系统 Windows 单机版" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Php)) {
  Write-Host "未找到内置 PHP：$Php" -ForegroundColor Red
  Pause-Exit 1
}
if (-not (Test-Path $Node)) {
  Write-Host "未找到内置 Node.js：$Node" -ForegroundColor Red
  Pause-Exit 1
}
if (-not (Test-Path $PublicDir)) {
  Write-Host "未找到 public 目录，请确认程序包完整。" -ForegroundColor Red
  Pause-Exit 1
}
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Root "storage") | Out-Null

$env:APP_ENV = "portable"
$env:APP_DEBUG = "0"
$env:APP_URL = "http://127.0.0.1:$Port"
$env:DB_DRIVER = "sqlite"
$env:DB_PATH = $DbPath
$env:NODE_PATH = Join-Path $Root "node_modules"
$env:STEP_NODE_BIN = $Node
$env:Path = (Split-Path -Parent $Node) + ";" + $env:Path
$env:TZ = "Asia/Shanghai"

Write-Host "初始化 SQLite 数据库..." -ForegroundColor Yellow
& $Php -r "require '$($Root.Replace('\\','/'))/config/bootstrap.php'; require '$($Root.Replace('\\','/'))/app/Core/Database.php'; StepSystem\Core\Database::pdo(); echo 'DB_OK'.PHP_EOL;"
if ($LASTEXITCODE -ne 0) { Pause-Exit $LASTEXITCODE }

if ($AdminUser -and $AdminPass) {
  Write-Host "检查默认管理员..." -ForegroundColor Yellow
  $env:STEP_ADMIN_USER = $AdminUser
  $env:STEP_ADMIN_PASS = $AdminPass
  $code = @'
require "config/bootstrap.php";
require "app/Core/Database.php";
use StepSystem\Core\Database;
$p = Database::pdo();
Database::migrate($p);
$u = getenv("STEP_ADMIN_USER");
$pw = getenv("STEP_ADMIN_PASS");
$count = (int)$p->query("SELECT COUNT(*) FROM users WHERE role=".$p->quote("admin"))->fetchColumn();
if ($count === 0) {
  $p->prepare("INSERT INTO users(username,password,role,status,expires_at,created_at) VALUES(?,?,?,?,?,?)")
    ->execute([$u, password_hash($pw, PASSWORD_DEFAULT), "admin", 1, null, date("Y-m-d H:i:s")]);
  echo "DEFAULT_ADMIN_CREATED: ".$u.PHP_EOL;
} else {
  echo "ADMIN_EXISTS".PHP_EOL;
}
'@
  Push-Location $Root
  & $Php -r $code
  Pop-Location
}

Write-Host "启动本地 PHP 服务..." -ForegroundColor Yellow
$arguments = @("-S", "127.0.0.1:$Port", "-t", $PublicDir)
$process = Start-Process -FilePath $Php -ArgumentList $arguments -WorkingDirectory $Root -PassThru -WindowStyle Hidden

Write-Host "启动定时任务/心跳检测..." -ForegroundColor Yellow
$schedulerLog = Join-Path $Root "storage\step-scheduler.log"
$schedulerScript = @"
`$env:APP_ENV='portable'
`$env:APP_DEBUG='0'
`$env:APP_URL='http://127.0.0.1:$Port'
`$env:DB_DRIVER='sqlite'
`$env:DB_PATH='$($DbPath.Replace("'","''"))'
`$env:NODE_PATH='$((Join-Path $Root "node_modules").Replace("'","''"))'
`$env:STEP_NODE_BIN='$($Node.Replace("'","''"))'
`$env:Path='$((Split-Path -Parent $Node).Replace("'","''"));' + `$env:Path
`$env:TZ='Asia/Shanghai'
while (`$true) {
  Push-Location '$($Root.Replace("'","''"))'
  try { & '$($Php.Replace("'","''"))' scheduler.php 2>&1 | Add-Content -Encoding UTF8 '$($schedulerLog.Replace("'","''"))' } catch { `$_.Exception.Message | Add-Content -Encoding UTF8 '$($schedulerLog.Replace("'","''"))' }
  Pop-Location
  Start-Sleep -Seconds 60
}
"@
$schedulerProcess = Start-Process -FilePath "powershell" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-Command",$schedulerScript) -WorkingDirectory $Root -PassThru -WindowStyle Hidden

$url = "http://127.0.0.1:$Port/"
$ok = $false
for ($i=1; $i -le 40; $i++) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 $url
    if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { $ok = $true; break }
  } catch { Start-Sleep -Milliseconds 500 }
}

if (-not $ok) {
  Write-Host "服务未能启动。" -ForegroundColor Red
  try { Stop-Process -Id $process.Id -Force } catch {}
  try { Stop-Process -Id $schedulerProcess.Id -Force } catch {}
  Pause-Exit 1
}

Write-Host "启动成功：$url" -ForegroundColor Green
Write-Host "默认管理员：admin / admin123" -ForegroundColor Green
Write-Host "数据文件：$DbPath" -ForegroundColor Cyan
Write-Host "定时日志：$schedulerLog" -ForegroundColor Cyan
Start-Process $url
Write-Host ""
Write-Host "保持此窗口打开，关闭窗口后本地服务会停止。" -ForegroundColor Yellow
Write-Host "按 Ctrl+C 或直接关闭窗口停止服务。"
try { Wait-Process -Id $process.Id } finally { try { Stop-Process -Id $process.Id -Force } catch {}; try { Stop-Process -Id $schedulerProcess.Id -Force } catch {} }
