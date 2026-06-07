<?php
require __DIR__.'/config/bootstrap.php';
use StepSystem\Core\Database;
use StepSystem\Core\Auth;
use StepSystem\Services\StepRunner;

if(!Database::installed()){
    echo date('Y-m-d H:i:s')." not installed\n";
    exit;
}
$p=Database::pdo();
StepRunner::whitelistHeartbeat();
$now=date('H:i');
$today=date('Y-m-d');
$s=$p->prepare("SELECT * FROM users WHERE auto_run=1 AND status=1 AND zepp_username IS NOT NULL AND zepp_username<>'' AND run_time<=? AND (last_step_run_date IS NULL OR last_step_run_date<>?) ORDER BY id ASC LIMIT 20");
$s->execute([$now,$today]);
$users=$s->fetchAll();
$ran=0;
$skipped=0;
foreach($users as $u){
    if($u['role']!=='admin'&&Auth::expired($u['expires_at'])){
        $skipped++;
        echo date('Y-m-d H:i:s').' user='.$u['id'].' skipped expired' . "\n";
        continue;
    }
    $res=StepRunner::run($u);
    $p->prepare('UPDATE users SET last_step_run_date=? WHERE id=?')->execute([$today,$u['id']]);
    $ran++;
    echo date('Y-m-d H:i:s').' user='.$u['id'].' '.$res['status'].' '.$res['message']."\n";
}
if(!$users){
    $due=$p->prepare("SELECT COUNT(*) FROM users WHERE auto_run=1 AND status=1 AND run_time<=?");
    $due->execute([$now]);
    echo date('Y-m-d H:i:s')." no due tasks now={$now} due_enabled=".$due->fetchColumn()."\n";
} elseif(!$ran) {
    echo date('Y-m-d H:i:s')." no runnable tasks skipped={$skipped}\n";
}
