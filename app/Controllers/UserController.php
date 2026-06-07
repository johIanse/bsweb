<?php
namespace StepSystem\Controllers;
use StepSystem\Core\View;use StepSystem\Core\Auth;use StepSystem\Core\Flash;use StepSystem\Core\Database;
class UserController{
 public function dashboard(){Auth::requireLogin();View::render('dashboard',['title'=>'用户中心','user'=>Auth::user()]);}
 public function profile(){redirect('index.php?r=dashboard');}
 public function password(){Auth::requireLogin();if($_SERVER['REQUEST_METHOD']==='POST'){$o=$_POST['old_password']??'';$n=$_POST['new_password']??'';$x=Auth::user();if(!password_verify($o,$x['password'])){Flash::set('原密码错误','error');redirect('index.php?r=password');}if(strlen($n)<6){Flash::set('新密码至少 6 位','error');redirect('index.php?r=password');}Database::pdo()->prepare('UPDATE users SET password=? WHERE id=?')->execute([password_hash($n,PASSWORD_DEFAULT),$x['id']]);Auth::refresh();Flash::set('密码修改成功');redirect('index.php?r=dashboard');}View::render('password',['title'=>'修改密码','user'=>Auth::user()]);}
}