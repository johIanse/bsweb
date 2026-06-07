<?php
namespace StepSystem\Controllers;
use StepSystem\Core\View;use StepSystem\Core\Database;
class HomeController{public function home(){
    $stats=['totalUsers'=>0,'activeUsers'=>0,'todaySuccess'=>0,'startDate'=>'','runDays'=>1,'beijingTime'=>date('Y-m-d H:i:s'),'serverTs'=>time()];
    try{$p=Database::pdo();$stats['totalUsers']=(int)$p->query('SELECT COUNT(*) FROM users')->fetchColumn();$stats['activeUsers']=(int)$p->query('SELECT COUNT(*) FROM users WHERE status=1')->fetchColumn();$stats['todaySuccess']=(int)$p->query("SELECT COUNT(*) FROM step_logs WHERE status='success' AND steps IS NOT NULL AND DATE(created_at)=CURDATE()")->fetchColumn();$start=(string)$p->query("SELECT MIN(created_at) FROM users")->fetchColumn();if($start){$stats['startDate']=substr($start,0,10);$stats['runDays']=max(1,(int)floor((time()-strtotime($start))/86400)+1);}}catch(\Throwable $e){}
    View::render('home',['title'=>'首页','stats'=>$stats]);
}}
