<?php
namespace StepSystem\Services;
use StepSystem\Core\Database;
use StepSystem\Core\Auth;
class AdminLog{
    public static function write($action,$detail=''){$u=Auth::user();try{$s=Database::pdo()->prepare('INSERT INTO admin_logs(user_id,action,detail,ip,created_at) VALUES(?,?,?,?,?)');$s->execute([$u['id']??null,$action,$detail,$_SERVER['REMOTE_ADDR']??'',now()]);}catch(\Throwable $e){}}
}