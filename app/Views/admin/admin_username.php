<?php $current=$admin['username']??''; ?>
<div class="card form">
  <h2>修改管理员用户名</h2>
  <form method="post">
    <input type="hidden" name="csrf_token" value="<?=h($_SESSION['csrf_token']??'')?>">
    <label>当前管理员用户名</label>
    <input value="<?=h($current)?>" disabled>
    <label>新管理员用户名</label>
    <input name="username" value="<?=h($current)?>" required maxlength="64" autocomplete="username">
    <p class="muted">只修改登录用户名，不修改密码、角色或有效期。用户名长度 3-64 位，不能与现有用户重复。</p>
    <p><button class="btn">保存</button> <a class="btn gray" href="index.php?r=admin">返回</a></p>
  </form>
</div>
