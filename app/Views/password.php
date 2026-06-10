<?php $isAdmin=($user['role']??'')==='admin'; ?>
<div class="card form">
  <h2><?=$isAdmin?'账号与密码':'修改密码'?></h2>
  <form method="post">
    <input type="hidden" name="csrf_token" value="<?=h($_SESSION['csrf_token']??'')?>">
    <?php if($isAdmin): ?>
      <label>管理员用户名</label>
      <input name="username" value="<?=h($user['username']??'')?>" required maxlength="64" autocomplete="username">
      <p class="muted">管理员可在这里修改登录账号。用户名长度 3-64 位，不能与已有用户重复。</p>
    <?php endif; ?>
    <label>原密码</label>
    <input name="old_password" type="password" autocomplete="current-password" required>
    <label>新密码</label>
    <input name="new_password" type="password" autocomplete="new-password" minlength="6" placeholder="留空则不修改密码">
    <p class="muted">保存任何修改都需要先输入原密码。</p>
    <p class="actions"><button class="btn green">保存修改</button><a class="btn gray" href="index.php?r=dashboard">返回用户中心</a></p>
  </form>
</div>
