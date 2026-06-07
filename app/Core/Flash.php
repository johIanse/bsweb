<?php
namespace StepSystem\Core;
class Flash{
    public static function set($m,$t='success'){$_SESSION['flash']=['m'=>$m,'t'=>$t];}
    public static function get(){$f=$_SESSION['flash']??null;unset($_SESSION['flash']);return $f;}
}