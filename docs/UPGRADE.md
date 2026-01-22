# 固件升级指南

### 推荐方式：不保留配置（最干净）

1. 下载最新 .img.gz 文件
2. 通过 LuCI → System → Backup / Flash Firmware 上传文件
   - 勾选 "Do not preserve old configuration"（不保留旧配置）
3. 等待刷机完成并重启

### 保留配置方式（慎用，可能引入冲突）

1. 先备份当前配置：
   ```bash
   sysupgrade -b /tmp/backup.tar.gz

刷新固件（保留配置）
sysupgrade /tmp/new.img.gz
重启后检查：
PassWall2 是否正常
Docker 服务是否启动
Argon 主题是否生效


注意事项

每次大版本升级（2.0 → 3.0）建议不保留配置，避免旧配置与新包冲突
升级后建议立即运行 sh /etc/passwall2-setup.sh 重新安装 PassWall2（以匹配新内核）

这些就是 **2.0 版本目前最完整、最新的所有文件代码**。

你可以直接把它们复制到对应路径，git add . → commit → push，即可拥有完整的、可长期维护的 2.0 项目架构。

如果编译过程中遇到任何 feeds 警告、包缺失、Argon 没出现等问题，贴出日志，我帮你继续优化。  
祝 2.0 编译顺利，刷机后 LuCI 登录页美美哒！
