# 服务器备份脚本

自动化备份脚本，用于定期备份服务器关键目录和配置文件到 WebDAV 存储。

## 功能特性

- ✅ 自动备份 `/var/www/html` 网站目录
- ✅ 自动备份 `/etc/nginx` Nginx 配置文件
- ✅ 自动备份 OpenList 配置和数据
- ✅ 自动打包为压缩文件（tar.gz）
- ✅ 自动上传到 WebDAV 存储
- ✅ 详细的日志记录
- ✅ 定时自动执行（每3天）

## 备份内容

脚本会备份以下内容：

1. **OpenList 数据**
   - 自动查找 OpenList 安装路径
   - 备份 `$INSTALL_PATH/data` 目录（包含配置和数据库）

2. **网站文件**
   - `/var/www/html` 目录

3. **Nginx 配置**
   - `/etc/nginx` 目录（包含所有配置文件）

## 安装

### 1. 复制脚本到系统目录

```bash
sudo cp server-backup.sh /usr/local/bin/server-backup.sh
sudo chmod +x /usr/local/bin/server-backup.sh
```

### 2. 配置 WebDAV 信息

编辑脚本文件，修改以下配置：

```bash
sudo nano /usr/local/bin/server-backup.sh
```

找到以下配置项并修改：

```bash
# WebDAV配置
WEBDAV_URL="https://your-webdav-server.com/dav"
WEBDAV_USER="your_username"
WEBDAV_PASS="your_password"
```

### 3. 设置定时任务

脚本已自动配置 cron 任务，每3天凌晨2点执行：

```bash
# 查看定时任务
crontab -l | grep server-backup

# 手动编辑（如需要）
sudo crontab -e
```

定时任务格式：
```
0 2 */3 * * /usr/local/bin/server-backup.sh >> /var/log/server-backup.log 2>&1
```

## 使用方法

### 手动执行备份

```bash
sudo /usr/local/bin/server-backup.sh
```

### 查看备份日志

```bash
# 查看最新日志
sudo tail -f /var/log/server-backup.log

# 查看所有日志
sudo cat /var/log/server-backup.log

# 查看最近的50行日志
sudo tail -50 /var/log/server-backup.log
```

### 查看定时任务状态

```bash
# 查看 cron 任务
crontab -l

# 查看 cron 服务状态
sudo systemctl status cron
```

## 备份文件格式

备份文件命名格式：`backup_YYYYMMDD_HHMMSS.tar.gz`

例如：`backup_20260121_132536.tar.gz`

备份文件结构：
```
backup_YYYYMMDD_HHMMSS.tar.gz
├── openlist_backup/
│   └── data/          # OpenList 配置和数据
├── www/
│   └── html/          # 网站文件
└── nginx/
    └── nginx/         # Nginx 配置文件
```

## 日志说明

日志文件位置：`/var/log/server-backup.log`

日志包含以下信息：
- 备份开始和结束时间
- 每个备份步骤的执行状态
- 备份文件大小
- WebDAV 上传结果
- 错误和警告信息

日志级别：
- `INFO`: 一般信息
- `SUCCESS`: 成功操作
- `WARNING`: 警告信息（不影响备份继续）
- `ERROR`: 错误信息

## 故障排除

### 1. 权限问题

如果遇到权限错误，确保：
- 脚本以 root 权限运行
- `/var/log/server-backup.log` 文件可写

```bash
sudo touch /var/log/server-backup.log
sudo chmod 644 /var/log/server-backup.log
```

### 2. WebDAV 上传失败

检查：
- WebDAV URL 是否正确
- 用户名和密码是否正确
- WebDAV 服务器是否可访问
- WebDAV 目录是否有写入权限

测试 WebDAV 连接：
```bash
curl -X PROPFIND -u "username:password" "https://your-webdav-server.com/dav/"
```

### 3. OpenList 备份失败

如果 OpenList 未安装或找不到：
- 脚本会记录警告但继续执行其他备份
- 检查 OpenList 是否已安装：`ls -la /opt/openlist`
- 检查服务文件：`cat /etc/systemd/system/openlist.service`

### 4. 磁盘空间不足

确保 `/tmp` 目录有足够空间：
```bash
df -h /tmp
```

如果空间不足，可以修改脚本中的临时目录位置。

### 5. Cron 任务未执行

检查 cron 服务：
```bash
sudo systemctl status cron
sudo systemctl start cron
```

查看 cron 日志：
```bash
sudo grep CRON /var/log/syslog
```

## 配置说明

### 修改备份频率

编辑 crontab：
```bash
sudo crontab -e
```

修改时间表达式：
- 每天凌晨2点：`0 2 * * *`
- 每3天凌晨2点：`0 2 */3 * *`
- 每周一凌晨2点：`0 2 * * 1`
- 每月1号凌晨2点：`0 2 1 * *`

### 修改日志文件位置

编辑脚本，修改 `LOG_FILE` 变量：
```bash
LOG_FILE="/path/to/your/logfile.log"
```

### 修改临时目录

编辑脚本，修改 `TEMP_BACKUP_DIR` 变量：
```bash
TEMP_BACKUP_DIR="/path/to/temp/dir"
```

## 恢复备份

### 1. 从 WebDAV 下载备份文件

```bash
curl -u "username:password" \
  "https://your-webdav-server.com/dav/backup_20260121_132536.tar.gz" \
  -o backup.tar.gz
```

### 2. 解压备份文件

```bash
mkdir restore
tar -xzf backup.tar.gz -C restore
```

### 3. 恢复文件

```bash
# 恢复网站文件
sudo cp -r restore/www/html/* /var/www/html/

# 恢复 Nginx 配置
sudo cp -r restore/nginx/nginx/* /etc/nginx/

# 恢复 OpenList 数据（需要先停止服务）
sudo systemctl stop openlist
sudo cp -r restore/openlist_backup/data/* /opt/openlist/data/
sudo systemctl start openlist
```

## 安全注意事项

1. **密码安全**
   - WebDAV 密码以明文形式存储在脚本中
   - 建议限制脚本文件权限：`sudo chmod 600 /usr/local/bin/server-backup.sh`
   - 或使用配置文件存储敏感信息

2. **日志安全**
   - 日志文件可能包含敏感信息
   - 定期清理旧日志文件
   - 限制日志文件访问权限

3. **备份文件**
   - 备份文件包含敏感数据
   - 确保 WebDAV 服务器安全
   - 定期检查备份文件完整性

## 系统要求

- Linux 系统（支持 systemd）
- Root 权限
- curl 工具
- tar 工具
- 足够的磁盘空间（临时目录）

## 版本历史

- **v1.0** (2026-01-21)
  - 初始版本
  - 支持备份 /var/www/html、/etc/nginx 和 OpenList
  - WebDAV 上传功能
  - 定时任务支持

## 许可证

MIT License

## 作者

服务器备份脚本

## 支持

如有问题或建议，请查看日志文件或联系系统管理员。
