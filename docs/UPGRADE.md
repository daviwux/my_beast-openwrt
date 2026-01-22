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
