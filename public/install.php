<?php
session_start();
require realpath(__DIR__."/../config/bootstrap.php");
$GLOBALS["DB_CFG"]=["host"=>"step-mysql","name"=>"step_system","user"=>"root","pass"=>"+XnYtMj/SY2FSMqsYN5vxv5yla6EVFly7k2jGM5kYuk="];
header('X-Frame-Options: SAMEORIGIN');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');
use StepSystem\Core\Database;
$installToken=(string)(getenv('INSTALL_TOKEN')?:'');
$reqToken=(string)($_GET['token']??$_POST['token']??'');
if($installToken===''||!hash_equals($installToken,$reqToken)){
    http_response_code(403);
    exit('403 Forbidden');
}
function renderInstall($err=''){$c=Database::envConfig();echo '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>安装向导 - '.APP.'</title><link rel="stylesheet" href="style.css?v=5"></head><body><div class="top"><div class="brand">'.APP.' 安装向导</div></div><main class="wrap"><section class="hero"><h1>安装向导</h1><p>初始化 MySQL 数据库、创建数据表和管理员账号。</p></section>'.($err?'<div class="alert error">'.h($err).'</div>':'').(Database::installed()?'<div class="alert success">检测到系统已安装。如需重新安装，请先删除 config/database.php。</div>':'').'<div class="card form"><h2>数据库配置</h2><form method="post"><input type="hidden" name="token" value="'.h($_GET['token']??$_POST['token']??'').'"><label>数据库地址</label><input name="db_host" value="'.h($c['host']).'"><label>数据库名</label><input name="db_name" value="'.h($c['name']).'"><label>数据库用户</label><input name="db_user" value="'.h($c['user']).'"><label>数据库密码</label><input name="db_pass" type="password" value="'.h($c['pass']).'"><hr><h2>管理员配置</h2><label>管理员账号</label><input name="admin_user" value="admin" autocomplete="username"><label>管理员密码</label><input name="admin_pass" type="password" value="" autocomplete="new-password" placeholder="请设置强密码"><p class="actions"><button class="btn green">立即安装</button></p></form></div></main><script src="app.js?v=5"></script></body></html>';exit;}
if($_SERVER['REQUEST_METHOD']!=='POST')renderInstall();
if(Database::installed())renderInstall('系统已安装，不能重复安装。');
$cfg=['host'=>trim($_POST['db_host']??''),'name'=>trim($_POST['db_name']??''),'user'=>trim($_POST['db_user']??''),'pass'=>(string)($_POST['db_pass']??'')];$au=trim($_POST['admin_user']??'admin');$ap=$_POST['admin_pass']??'';
if($cfg['host']===''||$cfg['name']===''||$cfg['user']===''||$cfg['pass']==='')renderInstall('数据库信息不能为空');
if(!preg_match('/^[A-Za-z0-9_]{3,32}$/',$au))renderInstall('管理员账号只能包含字母、数字、下划线，长度 3-32 位');
if(strlen($ap)<10)renderInstall('管理员密码至少 10 位');
try{$dsn='mysql:host='.$cfg['host'].';dbname='.$cfg['name'].';charset=utf8mb4';$p=new PDO($dsn,$cfg['user'],$cfg['pass'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);Database::migrate($p);$p->prepare("DELETE FROM users WHERE role='admin'")->execute();$p->prepare("INSERT INTO users(username,password,role,status,expires_at,created_at) VALUES(?,?,?,?,?,?)")->execute([$au,password_hash($ap,PASSWORD_DEFAULT),'admin',1,null,now()]);$txt="<?php\nreturn ".var_export($cfg,true).";\n";if(file_put_contents(Database::configFile(),$txt,LOCK_EX)===false)renderInstall('配置文件写入失败，请检查 config 目录权限');redirect('index.php?r=login');}catch(Throwable $e){$msg=getenv('APP_DEBUG')==='1'?$e->getMessage():'请检查数据库连接和权限设置';renderInstall('安装失败：'.$msg);}