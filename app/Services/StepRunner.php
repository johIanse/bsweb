<?php
namespace StepSystem\Services;
use StepSystem\Core\Database;
class StepRunner{
    public static function run(array $user){
        $username=trim($user['zepp_username']??'');$password=trim($user['zepp_password']??'');
        $min=max(1,(int)($user['step_min']??3000));$max=max($min,(int)($user['step_max']??8000));$steps=self::pickSteps($user['id'],$min,$max);
        if($username===''||$password==='')return self::log($user['id'],0,'error','请先保存 Zepp Life/小米运动账号密码');
        $cool=max(0,(int)Setting::get('cooldown_seconds','300'));$ck='step_last_run_'.md5($username);$last=(int)Setting::get($ck,'0');
        $limitKey='step_429_until_'.md5($username);$limitUntil=(int)Setting::get($limitKey,'0');
        if($limitUntil>time())return self::log($user['id'],$steps,'error','步数提交暂停：该 Zepp 账号触发账号级限流，'.date('H:i',$limitUntil).' 后再试');
        if($cool>0 && $last>0 && time()-$last<$cool)return self::log($user['id'],$steps,'error','同一 Zepp 账号执行过于频繁，请 '.($cool-(time()-$last)).' 秒后再试');
        $script=__DIR__.'/../../step.js';
        if(!is_file($script))return self::log($user['id'],$steps,'error','step.js 不存在，无法获取 access_token');
        $hasCache=(bool)self::tokenCache($username);
        $retries=$hasCache?0:max(0,min(5,(int)Setting::get('retry_count','2')));$lastText='';$lastProxy='';
        for($i=0;$i<=$retries;$i++){
            $proxy=$hasCache?'':self::getProxy($i>0);$lastProxy=$proxy;
            [$ok,$text,$code]=self::executeNode($script,$username,$password,$steps,$proxy);$lastText=$text;
            if(strpos($text,'成功修改步数')!==false || strpos($text,'执行结果: 成功')!==false){self::saveTokenCacheFromOutput($username,$text);Setting::set($ck,(string)time());return self::log($user['id'],$steps,'success','步数提交成功！步数：'.$steps);}
            if(strpos($text,'429')!==false || stripos($text,'Too Many Requests')!==false){Setting::set($limitKey,(string)(time()+7200));break;}
            if(strpos($text,'429')===false && stripos($text,'Too Many Requests')===false)break;
        }
        if(stripos($lastText,'token')!==false || strpos($lastText,'登录')!==false || strpos($lastText,'401')!==false || strpos($lastText,'403')!==false)self::clearTokenCache($username);
        $msg=self::friendlyError($lastText,$lastProxy);
        return self::log($user['id'],$steps,'error',$msg);
    }

    public static function validateLogin($username,$password){
        $username=trim((string)$username);$password=trim((string)$password);
        if($username===''||$password==='')return ['status'=>'error','message'=>'请填写 Zepp Life/小米运动账号密码'];
        $cache=self::tokenCache($username);
        $script=__DIR__.'/../../step.js';
        if(!is_file($script))return ['status'=>'error','message'=>'step.js 不存在，无法验证账号'];
        if($cache){
            [$ok,$text,$code]=self::executeNode($script,$username,$password,1,'',true,false,true);
            if(strpos($text,'OPENCLAW_TOKEN_CACHE:')!==false && strpos($text,'"source":"cache"')!==false){
                self::saveTokenCacheFromOutput($username,$text);
                return ['status'=>'success','message'=>'Zepp 账号登录数据有效，已复用保存数据，没有重新登录','cached'=>true];
            }
            if(strpos($text,'429')!==false || stripos($text,'Too Many Requests')!==false)return ['status'=>'error','message'=>'Zepp 接口限流，暂时无法验证账号，请稍后再试'];
            self::clearTokenCache($username);
        }
        $retries=max(0,min(5,(int)Setting::get('retry_count','2')));$lastText='';$lastProxy='';
        for($i=0;$i<=$retries;$i++){
            $proxy=self::getProxy($i>0);$lastProxy=$proxy;
            [$ok,$text,$code]=self::executeNode($script,$username,$password,1,$proxy,true,true);$lastText=$text;
            if(strpos($text,'OPENCLAW_TOKEN_CACHE:')!==false){self::saveTokenCacheFromOutput($username,$text);if(strpos($text,'"source":"cache"')!==false)return ['status'=>'success','message'=>'Zepp 账号登录数据仍有效，已使用上次保存数据','cached'=>true];return ['status'=>'success','message'=>'Zepp 账号重新登录验证成功，已更新登录数据','refreshed'=>true];}
            if(strpos($text,'登录验证成功')!==false)return ['status'=>'success','message'=>'Zepp 账号登录数据仍有效，已使用上次保存数据','cached'=>true];
            if(strpos($text,'429')===false && stripos($text,'Too Many Requests')===false)break;
        }
        if(strpos($lastText,'429')!==false || stripos($lastText,'Too Many Requests')!==false)return ['status'=>'error','message'=>'Zepp 接口限流，暂时无法验证账号，请稍后再试'];
        $msg=self::friendlyError($lastText,$lastProxy);
        if(strpos($msg,'账号或密码')!==false)return ['status'=>'error','message'=>'Zepp 账号或密码错误，无法保存配置'];
        return ['status'=>'error','message'=>str_replace('步数提交失败','Zepp 登录验证失败',$msg)];
    }

    private static function pickSteps($userId,$min,$max){
        $last=0;
        try{$s=Database::pdo()->prepare("SELECT MAX(steps) FROM step_logs WHERE user_id=? AND status='success' AND steps IS NOT NULL AND substr(created_at,1,10)=?");$s->execute([$userId,date('Y-m-d')]);$last=(int)$s->fetchColumn();}catch(\Throwable $e){}
        if($last>0){$min=max($min,$last+1);if($min>$max)$max=$min;}
        return random_int($min,$max);
    }
    private static function friendlyError($text,$proxy=''){
        $text=trim((string)$text);
        $proxyText='';
        if($text==='' )return '步数提交失败：执行脚本无返回'.$proxyText;
        if(strpos($text,'429')!==false || stripos($text,'Too Many Requests')!==false)return '步数提交失败：Zepp/小米接口返回 429 限流。建议暂停 2 小时后再试，或不要多个系统用户共用同一个 Zepp 账号'.$proxyText;
        if(stripos($text,'password')!==false || strpos($text,'登录')!==false || strpos($text,'账号')!==false)return '步数提交失败：账号或密码可能不正确，请检查 Zepp Life/小米运动账号配置'.$proxyText;
        if(strpos($text,'NODE_BINARY_NOT_FOUND')!==false)return '步数提交失败：Magisk 包缺少 Node.js 运行时，请安装新版模块'.$proxyText;
        if(stripos($text,'Cannot find module')!==false)return '步数提交失败：Node.js 依赖缺失，请安装新版模块'.$proxyText;
        if(stripos($text,'timeout')!==false || strpos($text,'ETIMEDOUT')!==false)return '步数提交失败：网络连接超时，请稍后重试'.$proxyText;
        if(stripos($text,'ECONNRESET')!==false || stripos($text,'ECONNREFUSED')!==false)return '步数提交失败：网络连接异常，请稍后重试'.$proxyText;
        return '步数提交失败：第三方接口返回异常，请稍后重试'.$proxyText;
    }
    private static function tokenCacheKey($username){return 'zepp_token_cache_'.md5($username);} 
    private static function tokenCache($username){$raw=Setting::get(self::tokenCacheKey($username),'');$data=json_decode($raw,true);if(!is_array($data))return null;if(empty($data['loginToken'])||empty($data['userId'])||empty($data['appToken']))return null;if(!empty($data['cachedAt'])&&time()-((int)$data['cachedAt']/1000)>86400*20)return null;return $data;}
    private static function saveTokenCacheFromOutput($username,$text){if(preg_match('/OPENCLAW_TOKEN_CACHE:(\{.*?\})(?:\r?\n|$)/s',$text,$m)){ $data=json_decode($m[1],true); if(is_array($data)&&!empty($data['loginToken'])&&!empty($data['userId'])&&!empty($data['appToken']))Setting::set(self::tokenCacheKey($username),json_encode($data,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));}}
    private static function clearTokenCache($username){Setting::set(self::tokenCacheKey($username),'');}
    private static function executeNode($script,$username,$password,$steps,$proxy,$loginOnly=false,$ignoreCache=false,$cacheOnly=false){
        $nodePath=__DIR__.'/../../node_modules';
        $nodeBin=trim((string)(getenv('STEP_NODE_BIN')?:''));
        if($nodeBin!=='' && (!is_file($nodeBin)||!is_executable($nodeBin)))$nodeBin='';
        if($nodeBin===''){
            $which=PHP_OS_FAMILY==='Windows'?'where node 2>NUL':'command -v node 2>/dev/null';
            $nodeBin=trim((string)shell_exec($which));
            if(strpos($nodeBin,"\n")!==false)$nodeBin=strtok($nodeBin,"\r\n");
        }
        if($nodeBin===''){
            foreach([__DIR__.'/../../../php/bin/node',__DIR__.'/../../runtime/node/node.exe',__DIR__.'/../../runtime/node/node'] as $candidate){
                if(is_file($candidate)&&is_executable($candidate)){$nodeBin=$candidate;break;}
            }
        }
        if($nodeBin==='')return [false,'NODE_BINARY_NOT_FOUND',127];
        $envVars=[
            'TZ'=>'Asia/Shanghai',
            'NODE_PATH'=>$nodePath,
            'XIAOMI_STEP_USERNAME'=>$username,
            'XIAOMI_STEP_PASSWORD'=>$password,
            'XIAOMI_STEP_STEP'=>(string)$steps,
            'XIAOMI_STEP_DEBUG'=>'1',
        ];
        if($loginOnly)$envVars['XIAOMI_STEP_LOGIN_ONLY']='1';
        if($cacheOnly)$envVars['XIAOMI_STEP_CACHE_ONLY']='1';
        $cache=$ignoreCache?null:self::tokenCache($username);
        if($cache){
            $envVars['XIAOMI_STEP_LOGIN_TOKEN']=$cache['loginToken']??'';
            $envVars['XIAOMI_STEP_USER_ID']=$cache['userId']??'';
            $envVars['XIAOMI_STEP_APP_TOKEN']=$cache['appToken']??'';
        }
        if($proxy){
            $agent=$nodePath.'/global-agent/bootstrap.js';
            if(!is_file($agent))$agent=$nodePath.'/global-agent/dist/bootstrap.js';
            if(is_file($agent))$envVars['NODE_OPTIONS']='-r '.$agent;
            $envVars['GLOBAL_AGENT_HTTP_PROXY']=$proxy;
            $envVars['HTTP_PROXY']=$proxy;
            $envVars['HTTPS_PROXY']=$proxy;
            $envVars['XIAOMI_STEP_PROXY']=$proxy;
        }
        $cmd=self::envPrefix($envVars).' '.escapeshellarg($nodeBin).' '.escapeshellarg($script).' 2>&1';
        $out=[];$code=0;exec($cmd,$out,$code);return [$code===0,implode("\n",$out),$code];
    }
    private static function envPrefix($vars){
        $parts=[];
        foreach($vars as $k=>$v){
            $k=preg_replace('/[^A-Za-z0-9_]/','',(string)$k);
            if($k==='')continue;
            if(PHP_OS_FAMILY==='Windows'){
                $parts[]='set "'.$k.'='.str_replace('"','',(string)$v).'"';
            }else{
                $parts[]=$k.'='.escapeshellarg((string)$v);
            }
        }
        return PHP_OS_FAMILY==='Windows'?implode(' && ',$parts).' &&':implode(' ',$parts);
    }
    private static function getProxy($force=false){
        if(Setting::get('proxy_enabled','1')!=='1')return '';
        $api=trim(Setting::get('proxy_api_url',getenv('STEP_PROXY_API_URL')?:''));if($api==='')return '';
        $body=self::httpGet($api,15);if($body==='')return '';
        if(preg_match('/白名单[：:]\s*(\d{1,3}(?:\.\d{1,3}){3})/u',$body,$wm)){
            self::addWhitelistIp($wm[1]);
            $body=self::httpGet($api,15);
            if($body==='')return '';
        }
        $json=json_decode($body,true);
        if(is_array($json)&&isset($json['data']['list'][0])){$it=$json['data']['list'][0];if(is_array($it)&&isset($it['ip'],$it['port'])){$auth=!empty($it['account'])?rawurlencode($it['account']).':'.rawurlencode($it['password']??'').'@':'';return 'http://'.$auth.$it['ip'].':'.$it['port'];}if(is_string($it)&&preg_match('/(\d{1,3}(?:\.\d{1,3}){3})\s*[:：]\s*(\d{2,5})/',$it,$m))return 'http://'.$m[1].':'.$m[2];}
        if(is_array($json)&&isset($json['data'][0]['IP'],$json['data'][0]['Port']))return 'http://'.$json['data'][0]['IP'].':'.$json['data'][0]['Port'];
        if(preg_match('/(\d{1,3}(?:\.\d{1,3}){3})\s*[:：]\s*(\d{2,5})/',$body,$m))return 'http://'.$m[1].':'.$m[2];return '';
    }
    private static function ensureWhitelist(){
        if(Setting::get('whitelist_enabled','1')!=='1')return;$ip=self::detectPublicIp();if(!$ip)return;self::syncWhitelistIp($ip);
    }
    private static function addWhitelistIp($ip){self::syncWhitelistIp($ip);}
    private static function syncWhitelistIp($ip){
        if(Setting::get('whitelist_enabled','1')!=='1'||!preg_match('/^\d{1,3}(?:\.\d{1,3}){3}$/',$ip))return;
        $get=trim(Setting::get('whitelist_get_url',''));$add=trim(Setting::get('whitelist_add_url',''));if($add==='')return;
        $list=$get!==''?self::httpGet($get,12):'';$exists=$list!==''&&strpos($list,$ip)!==false;
        if(!$exists){$url=str_replace(['{ip}','{memo}'],[rawurlencode($ip),rawurlencode(Setting::get('whitelist_memo','step-system-nas'))],$add);self::httpGet($url,12);}
        self::rotateManagedWhitelist($ip);
    }
    private static function rotateManagedWhitelist($currentIp){
        $prev=trim(Setting::get('whitelist_managed_ip',''));if($prev===''||$prev===$currentIp){Setting::set('whitelist_managed_ip',$currentIp);return;}
        if(preg_match('/^\d{1,3}(?:\.\d{1,3}){3}$/',$prev))self::deleteWhitelistIp($prev);
        Setting::set('whitelist_managed_ip',$currentIp);
    }
    private static function deleteWhitelistIp($ip){
        $del=trim(Setting::get('whitelist_del_url',''));if($del===''||!preg_match('/^\d{1,3}(?:\.\d{1,3}){3}$/',$ip))return;
        $url=str_replace('{ip}',rawurlencode($ip),$del);self::httpGet($url,12);
    }

    public static function whitelistHeartbeat(){
        if(Setting::get('whitelist_enabled','1')!=='1')return ['status'=>'disabled'];
        $interval=max(60,(int)Setting::get('whitelist_heartbeat_seconds','300'));
        $last=(int)Setting::get('whitelist_heartbeat_last','0');
        if($last>0 && time()-$last<$interval)return ['status'=>'skipped','next_in'=>$interval-(time()-$last),'managed_ip'=>Setting::get('whitelist_managed_ip','')];
        $ip=self::detectPublicIp();
        if(!$ip){Setting::set('whitelist_heartbeat_last',(string)time());return ['status'=>'error','message'=>'public ip detect failed'];}
        self::syncWhitelistIp($ip);
        Setting::set('whitelist_heartbeat_last',(string)time());
        return ['status'=>'ok','public_ip'=>$ip,'managed_ip'=>Setting::get('whitelist_managed_ip','')];
    }
    public static function detectPublicIp(){foreach(['https://api.ipify.org','https://ifconfig.me/ip','http://ip.3322.net'] as $u){$b=trim(self::httpGet($u,8));if(preg_match('/^\d{1,3}(?:\.\d{1,3}){3}$/',$b))return $b;}return '';}
    public static function proxyDiagnostics(){$hb=self::whitelistHeartbeat();$ip=self::detectPublicIp();$proxy=self::getProxy(true);return ['public_ip'=>$ip,'managed_whitelist_ip'=>Setting::get('whitelist_managed_ip',''),'heartbeat'=>$hb,'proxy'=>$proxy?self::maskProxy($proxy):'','proxy_enabled'=>Setting::get('proxy_enabled','1'),'cooldown_seconds'=>Setting::get('cooldown_seconds','300'),'retry_count'=>Setting::get('retry_count','2')];}
    private static function httpGet($url,$timeout=10){try{$ch=curl_init($url);curl_setopt_array($ch,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_CONNECTTIMEOUT=>5,CURLOPT_TIMEOUT=>$timeout,CURLOPT_FOLLOWLOCATION=>true,CURLOPT_HTTPHEADER=>['Accept: application/json,text/plain,*/*']]);$body=curl_exec($ch);$code=(int)curl_getinfo($ch,CURLINFO_HTTP_CODE);curl_close($ch);return ($body!==false&&$code>=200&&$code<300)?(string)$body:'';}catch(\Throwable $e){return '';}}
    private static function maskProxy($proxy){return preg_replace('/(\d+\.\d+)\.\d+\.\d+:(\d+)/','$1.*.*:$2',$proxy);}
    private static function log($uid,$steps,$status,$msg){try{$s=Database::pdo()->prepare('INSERT INTO step_logs(user_id,steps,status,message,created_at) VALUES(?,?,?,?,?)');$s->execute([$uid,$steps,$status,mb_substr($msg,0,250),now()]);}catch(\Throwable $e){}return ['status'=>$status,'steps'=>$steps,'message'=>$msg];}
}
