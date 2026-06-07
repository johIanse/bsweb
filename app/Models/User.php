<?php
namespace StepSystem\Models;
use StepSystem\Core\Database;
class User{
    public static function findByUsername($u){$s=Database::pdo()->prepare('SELECT * FROM users WHERE username=?');$s->execute([$u]);return $s->fetch();}
    public static function find($id){$s=Database::pdo()->prepare('SELECT * FROM users WHERE id=?');$s->execute([$id]);return $s->fetch();}
    public static function create($u,$p,$role='user',$expires=null,$status=1){$s=Database::pdo()->prepare('INSERT INTO users(username,password,role,status,expires_at,created_at) VALUES(?,?,?,?,?,?)');$s->execute([$u,password_hash($p,PASSWORD_DEFAULT),$role,$status,$role==='admin'?null:$expires,now()]);}
    public static function update($id,$data){$sets=[];$args=[];foreach($data as $k=>$v){$sets[]="$k=?";$args[]=$v;}$args[]=$id;Database::pdo()->prepare('UPDATE users SET '.implode(',',$sets).' WHERE id=?')->execute($args);}
    public static function delete($id){$p=Database::pdo();$p->beginTransaction();try{$p->prepare("DELETE FROM step_logs WHERE user_id=?")->execute([$id]);$p->prepare("DELETE FROM admin_logs WHERE user_id=?")->execute([$id]);$p->prepare("DELETE FROM users WHERE id=? AND role!='admin'")->execute([$id]);$p->commit();}catch(\Throwable $e){$p->rollBack();throw $e;}}
}