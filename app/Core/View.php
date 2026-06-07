<?php
namespace StepSystem\Core;
class View{
    public static function render($view,$data=[]){extract($data);$file=__DIR__.'/../Views/'.$view.'.php';ob_start();require $file;$content=ob_get_clean();require __DIR__.'/../Views/layout.php';exit;}
}