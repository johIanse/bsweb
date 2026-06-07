<?php
$query=$_GET;
$query['r']='yh';
header('Location: /index.php?'.http_build_query($query), true, 302);
exit;
