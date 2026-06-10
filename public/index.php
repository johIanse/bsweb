<?php
session_start();
require __DIR__.'/../config/bootstrap.php';
header('X-Frame-Options: SAMEORIGIN');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');
header('X-XSS-Protection: 0');
use StepSystem\Core\Database;use StepSystem\Controllers\HomeController;use StepSystem\Controllers\AuthController;use StepSystem\Controllers\YhOAuthController;use StepSystem\Controllers\UserController;use StepSystem\Controllers\AdminController;use StepSystem\Controllers\StepController;use StepSystem\Models\User;use StepSystem\Core\View;
if(empty($_SESSION['csrf_token']))$_SESSION['csrf_token']=bin2hex(random_bytes(32));
if(!Database::installed() && ($_GET['r']??'home')!=='home')redirect('install.php');
$r=$_GET['r']??'home';
try{
 switch($r){
  case 'home':(new HomeController)->home();break;
  case 'register':(new AuthController)->register();break;
  case 'login':(new AuthController)->login();break;
  case 'yh_login':(new YhOAuthController)->login();break;
  case 'yh':(new YhOAuthController)->callback();break;
  case 'logout':(new AuthController)->logout();break;
  case 'dashboard':(new UserController)->dashboard();break;
  case 'profile':(new UserController)->profile();break;
  case 'password':(new UserController)->password();break;
  case 'step_settings':(new StepController)->settings();break;
  case 'steps':(new StepController)->settings();break;
  case 'step_test':(new StepController)->test();break;
  case 'step_run':(new StepController)->run();break;
  case 'admin':(new AdminController)->index();break;
  case 'admin_create':(new AdminController)->save();break;
  case 'admin_edit':$x=User::find((int)($_GET['id']??0));if(!$x)redirect('index.php?r=admin');(new AdminController)->save($x);break;
  case 'admin_delete':(new AdminController)->delete();break;
  case 'admin_user_logs':(new AdminController)->logs();break;
  case 'admin_username':(new AdminController)->adminUsername();break;
  case 'admin_register_settings':(new AdminController)->registerSettings();break;
  case 'admin_yh_oauth':(new AdminController)->yhOAuthSettings();break;
  case 'admin_proxy':(new AdminController)->proxy();break;
  case 'admin_proxy_test':(new AdminController)->proxyTest();break;
  default:(new HomeController)->home();
 }
}catch(Throwable $e){View::render('error',['title'=>'系统错误','message'=>$e->getMessage()]);}