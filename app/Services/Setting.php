<?php
namespace StepSystem\Services;
use StepSystem\Core\Database;
class Setting{
 public static function get($key,$default=''){$s=Database::pdo()->prepare('SELECT `value` FROM settings WHERE `key`=?');$s->execute([$key]);$v=$s->fetchColumn();return $v===false?$default:$v;}
 public static function set($key,$value){$s=Database::pdo()->prepare('INSERT INTO settings(`key`,`value`,updated_at) VALUES(?,?,?) ON DUPLICATE KEY UPDATE `value`=VALUES(`value`),updated_at=VALUES(updated_at)');$s->execute([$key,(string)$value,now()]);}
 public static function getMany(array $defs){$out=[];foreach($defs as $k=>$v)$out[$k]=self::get($k,$v);return $out;}
 public static function setMany(array $data){foreach($data as $k=>$v)self::set($k,$v);}
}
