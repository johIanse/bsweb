<?php
namespace StepSystem\Core;
use PDO;
class Database{
    private static $pdo;
    private static $driver;
    public static function configFile(){return __DIR__.'/../../config/database.php';}
    public static function installed(){
        if(is_file(self::configFile()))return true;
        $driver=strtolower((string)(getenv('DB_DRIVER')?:''));
        if($driver==='sqlite')return true;
        return false;
    }
    public static function envConfig(){
        $driver=strtolower((string)(getenv('DB_DRIVER')?:''));
        if($driver==='sqlite'){
            $path=(string)(getenv('DB_PATH')?:__DIR__.'/../../storage/step-system.sqlite');
            return ['driver'=>'sqlite','path'=>$path];
        }
        return ['driver'=>'mysql','host'=>getenv('DB_HOST')?:'step-mysql','name'=>getenv('DB_NAME')?:'step_system','user'=>getenv('DB_USER')?:'step_user','pass'=>(string)(getenv('DB_PASS')?:'')];
    }
    public static function config(){
        $c=self::installed()?require self::configFile():self::envConfig();
        if(!isset($c['driver']))$c['driver']=isset($c['path'])?'sqlite':'mysql';
        return $c;
    }
    public static function driver(){if(self::$driver)return self::$driver;$c=self::config();return self::$driver=strtolower((string)($c['driver']??'mysql'));}
    public static function pdo(){
        if(self::$pdo)return self::$pdo;
        $c=self::config();$driver=strtolower((string)($c['driver']??'mysql'));self::$driver=$driver;
        if($driver==='sqlite'){
            $path=(string)($c['path']??__DIR__.'/../../storage/step-system.sqlite');
            if(!is_dir(dirname($path)))mkdir(dirname($path),0775,true);
            self::$pdo=new PDO('sqlite:'.$path,null,null,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
            self::$pdo->exec('PRAGMA foreign_keys=ON');
        }else{
            $dsn='mysql:host='.$c['host'].';dbname='.$c['name'].';charset=utf8mb4';
            self::$pdo=new PDO($dsn,$c['user'],$c['pass'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);
        }
        self::migrate(self::$pdo);return self::$pdo;
    }
    public static function migrate(PDO $p){self::driver()==='sqlite'?self::migrateSqlite($p):self::migrateMysql($p);}
    private static function migrateMysql(PDO $p){
        $p->exec("CREATE TABLE IF NOT EXISTS users(id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,username VARCHAR(64) NOT NULL UNIQUE,password VARCHAR(255) NOT NULL,role VARCHAR(20) NOT NULL DEFAULT 'user',status TINYINT NOT NULL DEFAULT 1,expires_at DATETIME DEFAULT NULL,created_at DATETIME NOT NULL,last_login_at DATETIME DEFAULT NULL,zepp_username VARCHAR(128) DEFAULT NULL,zepp_password VARCHAR(255) DEFAULT NULL,step_min INT NOT NULL DEFAULT 3000,step_max INT NOT NULL DEFAULT 8000,run_key VARCHAR(64) DEFAULT NULL,auto_run TINYINT NOT NULL DEFAULT 0,run_time CHAR(5) NOT NULL DEFAULT '07:30',last_step_run_date DATE DEFAULT NULL,yh_userid VARCHAR(64) DEFAULT NULL,yh_nickname VARCHAR(128) DEFAULT NULL,yh_level INT DEFAULT 0,UNIQUE KEY uq_users_yh_userid(yh_userid),INDEX idx_role(role),INDEX idx_status(status),INDEX idx_expires(expires_at),INDEX idx_run_key(run_key),INDEX idx_auto(auto_run,run_time,last_step_run_date)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        self::ensureColumn($p,'users','zepp_username',"ALTER TABLE users ADD zepp_username VARCHAR(128) DEFAULT NULL");self::ensureColumn($p,'users','zepp_password',"ALTER TABLE users ADD zepp_password VARCHAR(255) DEFAULT NULL");self::ensureColumn($p,'users','step_min',"ALTER TABLE users ADD step_min INT NOT NULL DEFAULT 3000");self::ensureColumn($p,'users','step_max',"ALTER TABLE users ADD step_max INT NOT NULL DEFAULT 8000");self::ensureColumn($p,'users','run_key',"ALTER TABLE users ADD run_key VARCHAR(64) DEFAULT NULL");self::ensureColumn($p,'users','auto_run',"ALTER TABLE users ADD auto_run TINYINT NOT NULL DEFAULT 0");self::ensureColumn($p,'users','run_time',"ALTER TABLE users ADD run_time CHAR(5) NOT NULL DEFAULT '07:30'");self::ensureColumn($p,'users','last_step_run_date',"ALTER TABLE users ADD last_step_run_date DATE DEFAULT NULL");self::ensureColumn($p,'users','yh_userid',"ALTER TABLE users ADD yh_userid VARCHAR(64) DEFAULT NULL");self::ensureColumn($p,'users','yh_nickname',"ALTER TABLE users ADD yh_nickname VARCHAR(128) DEFAULT NULL");self::ensureColumn($p,'users','yh_level',"ALTER TABLE users ADD yh_level INT DEFAULT 0");try{$p->exec("ALTER TABLE users ADD UNIQUE KEY uq_users_yh_userid (yh_userid)");}catch(\Throwable $e){}
        $p->exec("CREATE TABLE IF NOT EXISTS admin_logs(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,user_id INT UNSIGNED NULL,action VARCHAR(120) NOT NULL,detail TEXT NULL,ip VARCHAR(64) NULL,created_at DATETIME NOT NULL,INDEX idx_created(created_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        $p->exec("CREATE TABLE IF NOT EXISTS step_logs(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,user_id INT UNSIGNED NOT NULL,steps INT DEFAULT NULL,status VARCHAR(20) NOT NULL,message VARCHAR(255) NOT NULL,created_at DATETIME NOT NULL,INDEX idx_user(user_id),INDEX idx_created(created_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        $p->exec("CREATE TABLE IF NOT EXISTS settings(`key` VARCHAR(120) NOT NULL PRIMARY KEY,`value` TEXT NULL,updated_at DATETIME NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }
    private static function migrateSqlite(PDO $p){
        $p->exec("CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT NOT NULL UNIQUE,password TEXT NOT NULL,role TEXT NOT NULL DEFAULT 'user',status INTEGER NOT NULL DEFAULT 1,expires_at TEXT DEFAULT NULL,created_at TEXT NOT NULL,last_login_at TEXT DEFAULT NULL,zepp_username TEXT DEFAULT NULL,zepp_password TEXT DEFAULT NULL,step_min INTEGER NOT NULL DEFAULT 3000,step_max INTEGER NOT NULL DEFAULT 8000,run_key TEXT DEFAULT NULL,auto_run INTEGER NOT NULL DEFAULT 0,run_time TEXT NOT NULL DEFAULT '07:30',last_step_run_date TEXT DEFAULT NULL,yh_userid TEXT DEFAULT NULL UNIQUE,yh_nickname TEXT DEFAULT NULL,yh_level INTEGER DEFAULT 0)");
        self::ensureColumn($p,'users','zepp_username',"ALTER TABLE users ADD COLUMN zepp_username TEXT DEFAULT NULL");self::ensureColumn($p,'users','zepp_password',"ALTER TABLE users ADD COLUMN zepp_password TEXT DEFAULT NULL");self::ensureColumn($p,'users','step_min',"ALTER TABLE users ADD COLUMN step_min INTEGER NOT NULL DEFAULT 3000");self::ensureColumn($p,'users','step_max',"ALTER TABLE users ADD COLUMN step_max INTEGER NOT NULL DEFAULT 8000");self::ensureColumn($p,'users','run_key',"ALTER TABLE users ADD COLUMN run_key TEXT DEFAULT NULL");self::ensureColumn($p,'users','auto_run',"ALTER TABLE users ADD COLUMN auto_run INTEGER NOT NULL DEFAULT 0");self::ensureColumn($p,'users','run_time',"ALTER TABLE users ADD COLUMN run_time TEXT NOT NULL DEFAULT '07:30'");self::ensureColumn($p,'users','last_step_run_date',"ALTER TABLE users ADD COLUMN last_step_run_date TEXT DEFAULT NULL");self::ensureColumn($p,'users','yh_userid',"ALTER TABLE users ADD COLUMN yh_userid TEXT DEFAULT NULL");self::ensureColumn($p,'users','yh_nickname',"ALTER TABLE users ADD COLUMN yh_nickname TEXT DEFAULT NULL");self::ensureColumn($p,'users','yh_level',"ALTER TABLE users ADD COLUMN yh_level INTEGER DEFAULT 0");
        $p->exec("CREATE UNIQUE INDEX IF NOT EXISTS uq_users_yh_userid ON users(yh_userid)");$p->exec("CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)");$p->exec("CREATE INDEX IF NOT EXISTS idx_users_status ON users(status)");$p->exec("CREATE INDEX IF NOT EXISTS idx_users_expires ON users(expires_at)");$p->exec("CREATE INDEX IF NOT EXISTS idx_users_run_key ON users(run_key)");$p->exec("CREATE INDEX IF NOT EXISTS idx_users_auto ON users(auto_run,run_time,last_step_run_date)");
        $p->exec("CREATE TABLE IF NOT EXISTS admin_logs(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NULL,action TEXT NOT NULL,detail TEXT NULL,ip TEXT NULL,created_at TEXT NOT NULL)");$p->exec("CREATE INDEX IF NOT EXISTS idx_admin_logs_created ON admin_logs(created_at)");
        $p->exec("CREATE TABLE IF NOT EXISTS step_logs(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL,steps INTEGER DEFAULT NULL,status TEXT NOT NULL,message TEXT NOT NULL,created_at TEXT NOT NULL)");$p->exec("CREATE INDEX IF NOT EXISTS idx_step_logs_user ON step_logs(user_id)");$p->exec("CREATE INDEX IF NOT EXISTS idx_step_logs_created ON step_logs(created_at)");
        $p->exec("CREATE TABLE IF NOT EXISTS settings(key TEXT NOT NULL PRIMARY KEY,value TEXT NULL,updated_at TEXT NOT NULL)");
    }
    private static function ensureColumn(PDO $p,$table,$column,$sql){
        if(self::driver()==='sqlite'){$s=$p->query("PRAGMA table_info(".$table.")");foreach($s->fetchAll() as $r){if(($r['name']??'')===$column)return;}$p->exec($sql);return;}
        $s=$p->prepare("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND COLUMN_NAME=?");$s->execute([$table,$column]);if(!(int)$s->fetchColumn())$p->exec($sql);
    }
}
