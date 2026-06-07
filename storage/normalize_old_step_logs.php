<?php
require __DIR__.'/../config/bootstrap.php';
use StepSystem\Core\Database;
$p=Database::pdo();
$rows=$p->query("SELECT id,message FROM step_logs WHERE message LIKE '%微信步数提交%' OR message LIKE '%代理：%' OR message LIKE '%最后代理：%' OR message LIKE '%登录代理：%' OR message LIKE '%换代理%' ORDER BY id")->fetchAll();
$n=0;
foreach($rows as $r){
  $m=$r['message'];
  $m=str_replace('微信步数提交成功！','步数提交成功！',$m);
  $m=str_replace('微信步数提交失败：','步数提交失败：',$m);
  $m=str_replace('微信步数提交暂停：','步数提交暂停：',$m);
  $m=preg_replace('/，登录代理：http:\/\/[^\s，,]+/u','',$m);
  $m=preg_replace('/，代理：http:\/\/[^\s，,]+/u','',$m);
  $m=preg_replace('/，最后代理：http:\/\/[^\s，,]+/u','',$m);
  $m=str_replace('。换代理也可能无效','',$m);
  $m=str_replace('当前已使用代理，但','',$m);
  if($m!==$r['message']){$s=$p->prepare('UPDATE step_logs SET message=? WHERE id=?');$s->execute([mb_substr($m,0,250),$r['id']]);$n++;}
}
echo "normalized=$n\n";
