<?php
namespace StepSystem\Controllers;
use StepSystem\Core\Auth;use StepSystem\Core\Database;use StepSystem\Core\Flash;use StepSystem\Models\User;use StepSystem\Services\Setting;
class YhOAuthController{
 private $base='https://yaohuo.me';
 private function cfg(){return Setting::getMany(['yh_oauth_enabled'=>'1','yh_oauth_register_enabled'=>'1','yh_oauth_app_id'=>'','yh_oauth_app_key'=>'','yh_oauth_callback'=>default_yh_callback_url(),'registration_gift_days'=>'7']);}
 public function login(){
  $c=$this->cfg(); if(trim($c['yh_oauth_app_id'])===''||trim($c['yh_oauth_app_key'])===''){Flash::set('授权登录暂未配置','error');redirect('index.php?r=login');}
  $state=bin2hex(random_bytes(16));$_SESSION['yh_oauth_state']=$state;
  $url=$this->base.'/OAuth/Authorize.aspx?'.http_build_query(['response_type'=>'code','client_id'=>$c['yh_oauth_app_id'],'redirect_uri'=>$c['yh_oauth_callback'],'scope'=>'profile','state'=>$state]);
  header('Location: '.$url);exit;
 }
 public function callback(){
  $c=$this->cfg();
  if(isset($_GET['error'])){Flash::set('授权失败：'.($_GET['error_description']??$_GET['error']),'error');redirect('index.php?r=login');}
  $code=(string)($_GET['code']??'');$state=(string)($_GET['state']??'');
  if($code===''||empty($_SESSION['yh_oauth_state'])||!hash_equals($_SESSION['yh_oauth_state'],$state)){Flash::set('授权状态校验失败，请重试','error');redirect('index.php?r=login');}
  unset($_SESSION['yh_oauth_state']);
  $token=$this->postJson($this->base.'/OAuth/Token.aspx',['grant_type'=>'authorization_code','code'=>$code,'client_id'=>$c['yh_oauth_app_id'],'client_secret'=>$c['yh_oauth_app_key'],'redirect_uri'=>$c['yh_oauth_callback']]);
  if(empty($token['access_token'])){Flash::set('授权登录失败：'.($token['error_description']??$token['error']??'无法获取令牌'),'error');redirect('index.php?r=login');}
  $profile=$this->getProfile($token['access_token']);
  if(empty($profile['userid'])){Flash::set('授权登录失败：'.($profile['error_description']??$profile['error']??'无法获取用户信息'),'error');redirect('index.php?r=login');}
  $oauthId=(string)$profile['userid'];$nickname=trim((string)($profile['nickname']??('用户'.$oauthId)));
  $u=$this->findByOauth($oauthId);
  if(!$u){
   if(($c['yh_oauth_register_enabled']??'1')!=='1'){Flash::set('已关闭授权登录，未授权登录过的账号无法登录','error');redirect('index.php?r=login');}
   $u=$this->createOauthUser($oauthId,$nickname,(int)($profile['level']??0),(int)($c['registration_gift_days']??7));
  }else{
   Database::pdo()->prepare('UPDATE users SET yh_nickname=?,yh_level=?,last_login_at=? WHERE id=?')->execute([$nickname,(int)($profile['level']??0),now(),$u['id']]);
   $u=User::find($u['id']);
  }
  if((int)$u['status']!==1){Flash::set('账号已禁用','error');redirect('index.php?r=login');}
  if($u['role']!=='admin'&&Auth::expired($u['expires_at'])){Flash::set('账号已到期，请联系管理员续期','error');redirect('index.php?r=login');}
  $_SESSION['user']=$u;redirect($u['role']==='admin'?'index.php?r=admin':'index.php?r=dashboard');
 }
 private function findByOauth($id){$s=Database::pdo()->prepare('SELECT * FROM users WHERE yh_userid=? LIMIT 1');$s->execute([$id]);return $s->fetch();}
 private function createOauthUser($oauthId,$nickname,$level,$giftDays){$p=Database::pdo();$base='yh_'.$oauthId;$name=$base;$i=1;while(User::findByUsername($name)){$i++;$name=$base.'_'.$i;}$expires=$giftDays>0?date('Y-m-d H:i:s',strtotime('+'.$giftDays.' days')):null;$p->prepare('INSERT INTO users(username,password,role,status,expires_at,created_at,yh_userid,yh_nickname,yh_level,last_login_at) VALUES(?,?,?,?,?,?,?,?,?,?)')->execute([$name,password_hash(bin2hex(random_bytes(24)),PASSWORD_DEFAULT),'user',1,$expires,now(),$oauthId,$nickname,$level,now()]);return User::find((int)$p->lastInsertId());}
 private function postJson($url,$data){$ch=curl_init($url);curl_setopt_array($ch,[CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>http_build_query($data),CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>15,CURLOPT_HTTPHEADER=>['Content-Type: application/x-www-form-urlencoded','Accept: application/json']]);$r=curl_exec($ch);curl_close($ch);$j=json_decode((string)$r,true);return is_array($j)?$j:['error'=>'bad_response'];}
 private function getProfile($token){$ch=curl_init($this->base.'/OAuth/Profile.aspx');curl_setopt_array($ch,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>15,CURLOPT_HTTPHEADER=>['Accept: application/json','Authorization: Bearer '.$token]]);$r=curl_exec($ch);curl_close($ch);$j=json_decode((string)$r,true);return is_array($j)?$j:['error'=>'bad_response'];}
}
