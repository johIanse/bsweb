<?php
date_default_timezone_set('Asia/Shanghai');
define("APP", "步数系统");
spl_autoload_register(function($class){
    $prefix='StepSystem\\';
    if(strpos($class,$prefix)!==0)return;
    $path=__DIR__.'/../app/'.str_replace('\\','/',substr($class,strlen($prefix))).'.php';
    if(is_file($path))require $path;
});
function h($s){return htmlspecialchars((string)$s,ENT_QUOTES,'UTF-8');}
function now(){return date('Y-m-d H:i:s');}
function redirect($url){header('Location: '.$url);exit;}