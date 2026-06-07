<?php
namespace StepSystem\Core;
class Auth{
    public static function user(){return $_SESSION['user']??null;}
    public static function isAdmin(){return self::user()&&self::user()['role']==='admin';}
    public static function refresh(){if(!self::user())return;$s=Database::pdo()->prepare('SELECT * FROM users WHERE id=?');$s->execute([self::user()['id']]);if($u=$s->fetch())$_SESSION['user']=$u;}
    public static function requireLogin(){self::refresh();if(!self::user())redirect('index.php?r=login');}
    public static function requireAdmin(){self::requireLogin();if(!self::isAdmin()){Flash::set('无管理员权限','error');redirect('index.php?r=dashboard');}}
    public static function expired($t){return $t&&strtotime($t)<time();}
}