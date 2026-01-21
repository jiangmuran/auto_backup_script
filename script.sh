#!/bin/bash
###############################################################################
#
# 服务器备份脚本
#
# 功能：
#   - 备份 /var/www/html 目录
#   - 备份 /etc/nginx 目录
#   - 备份 openlist 配置和数据
#   - 上传备份文件到 WebDAV
#
# 执行频率：每3天执行一次（通过cron）
#
###############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/var/log/server-backup.log"

# WebDAV配置
WEBDAV_URL="https://127.0.0.1:5244/dav"
WEBDAV_USER="backup"
WEBDAV_PASS=""

# 临时备份目录
TEMP_BACKUP_DIR="/tmp/server_backup_$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE_NAME="backup_$(date +%Y%m%d_%H%M%S).tar.gz"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

# 清理函数
cleanup() {
    if [ -d "$TEMP_BACKUP_DIR" ]; then
        rm -rf "$TEMP_BACKUP_DIR"
        log_info "清理临时目录: $TEMP_BACKUP_DIR"
    fi
    if [ -f "/tmp/$BACKUP_FILE_NAME" ]; then
        rm -f "/tmp/$BACKUP_FILE_NAME"
        log_info "清理临时备份文件: /tmp/$BACKUP_FILE_NAME"
    fi
}

# 设置退出时清理
trap cleanup EXIT

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 获取openlist安装路径
get_openlist_path() {
    # 从 service 文件中获取工作目录
    if [ -f "/etc/systemd/system/openlist.service" ]; then
        installed_path=$(grep "WorkingDirectory=" /etc/systemd/system/openlist.service | cut -d'=' -f2)
        if [ -f "$installed_path/openlist" ]; then
            echo "$installed_path"
            return 0
        fi
    fi

    # 如果服务文件中的路径无效，尝试常见位置
    for path in "/opt/openlist" "/usr/local/openlist" "/home/openlist"; do
        if [ -f "$path/openlist" ]; then
            echo "$path"
            return 0
        fi
    done

    # 如果都找不到，返回默认路径
    echo "/opt/openlist"
}

# 备份openlist
backup_openlist() {
    log_info "开始备份 openlist..."
    
    local openlist_path=$(get_openlist_path)
    log_info "找到 openlist 安装路径: $openlist_path"
    
    if [ ! -d "$openlist_path/data" ]; then
        log_warning "openlist data 目录不存在: $openlist_path/data，跳过 openlist 备份"
        return 0
    fi
    
    local openlist_backup_dir="$TEMP_BACKUP_DIR/openlist_backup"
    mkdir -p "$openlist_backup_dir"
    
    if cp -r "$openlist_path/data" "$openlist_backup_dir/"; then
        log_success "openlist 备份成功: $openlist_path/data -> $openlist_backup_dir/data"
        return 0
    else
        log_error "openlist 备份失败"
        return 1
    fi
}

# 备份 /var/www/html
backup_www() {
    log_info "开始备份 /var/www/html..."
    
    if [ ! -d "/var/www/html" ]; then
        log_warning "/var/www/html 目录不存在，跳过备份"
        return 0
    fi
    
    local www_backup_dir="$TEMP_BACKUP_DIR/www"
    mkdir -p "$www_backup_dir"
    
    if cp -r /var/www/html "$www_backup_dir/"; then
        log_success "/var/www/html 备份成功"
        return 0
    else
        log_error "/var/www/html 备份失败"
        return 1
    fi
}

# 备份 /etc/nginx
backup_nginx() {
    log_info "开始备份 /etc/nginx..."
    
    if [ ! -d "/etc/nginx" ]; then
        log_warning "/etc/nginx 目录不存在，跳过备份"
        return 0
    fi
    
    local nginx_backup_dir="$TEMP_BACKUP_DIR/nginx"
    mkdir -p "$nginx_backup_dir"
    
    if cp -r /etc/nginx "$nginx_backup_dir/"; then
        log_success "/etc/nginx 备份成功"
        return 0
    else
        log_error "/etc/nginx 备份失败"
        return 1
    fi
}

# 打包备份文件
pack_backup() {
    log_info "开始打包备份文件..."
    
    cd "$TEMP_BACKUP_DIR" || {
        log_error "无法进入临时备份目录"
        return 1
    }
    
    if tar -czf "/tmp/$BACKUP_FILE_NAME" .; then
        local file_size=$(du -h "/tmp/$BACKUP_FILE_NAME" | cut -f1)
        log_success "备份文件打包成功: /tmp/$BACKUP_FILE_NAME (大小: $file_size)"
        return 0
    else
        log_error "备份文件打包失败"
        return 1
    fi
}

# 上传到WebDAV
upload_to_webdav() {
    log_info "开始上传备份文件到 WebDAV..."
    
    if [ ! -f "/tmp/$BACKUP_FILE_NAME" ]; then
        log_error "备份文件不存在: /tmp/$BACKUP_FILE_NAME"
        return 1
    fi
    
    # 使用curl上传文件到WebDAV
    local upload_url="${WEBDAV_URL}/${BACKUP_FILE_NAME}"
    
    log_info "上传URL: $upload_url"
    
    local http_code=$(curl -s -o /tmp/webdav_upload_response.txt -w "%{http_code}" \
        -X PUT \
        -u "${WEBDAV_USER}:${WEBDAV_PASS}" \
        --data-binary "@/tmp/$BACKUP_FILE_NAME" \
        "$upload_url")
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        log_success "备份文件上传成功 (HTTP $http_code)"
        rm -f /tmp/webdav_upload_response.txt
        return 0
    else
        log_error "备份文件上传失败 (HTTP $http_code)"
        if [ -f /tmp/webdav_upload_response.txt ]; then
            log_error "响应内容: $(cat /tmp/webdav_upload_response.txt)"
            rm -f /tmp/webdav_upload_response.txt
        fi
        return 1
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始服务器备份任务"
    log_info "=========================================="
    
    check_root
    
    # 创建临时备份目录
    mkdir -p "$TEMP_BACKUP_DIR" || {
        log_error "无法创建临时备份目录"
        exit 1
    }
    
    local backup_failed=0
    
    # 备份各个组件
    backup_openlist || backup_failed=1
    backup_www || backup_failed=1
    backup_nginx || backup_failed=1
    
    # 打包备份文件
    if ! pack_backup; then
        log_error "备份打包失败，终止上传"
        exit 1
    fi
    
    # 上传到WebDAV
    if ! upload_to_webdav; then
        log_error "WebDAV上传失败"
        exit 1
    fi
    
    if [ $backup_failed -eq 0 ]; then
        log_success "=========================================="
        log_success "服务器备份任务完成"
        log_success "=========================================="
    else
        log_warning "=========================================="
        log_warning "服务器备份任务完成，但有部分备份失败"
        log_warning "=========================================="
    fi
}

# 执行主函数
main
