#!/bin/bash

# DNS固定配置脚本
# 用途：删除所有DNS服务器，设置为8.8.8.8和1.1.1.1，并防止重启后恢复

echo "========================================="
echo "DNS固定配置脚本开始执行..."
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "错误：请以root权限运行此脚本"
    echo "使用方法: sudo $0"
    exit 1
fi

# 备份原始配置文件
backup_dir="/root/dns_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

echo "1. 创建备份目录: $backup_dir"

# 备份相关配置文件
files_to_backup=(
    "/etc/resolv.conf"
    "/etc/systemd/resolved.conf"
    "/etc/netplan"
    "/etc/network/interfaces"
    "/etc/dhcp/dhclient.conf"
)

for file in "${files_to_backup[@]}"; do
    if [ -e "$file" ]; then
        cp -r "$file" "$backup_dir/" 2>/dev/null
        echo "   已备份: $file"
    fi
done

echo ""
echo "2. 停止可能干扰的服务..."

# 停止systemd-resolved服务（如果存在）
if systemctl is-active --quiet systemd-resolved; then
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    echo "   已停止并禁用 systemd-resolved"
fi

# 停止NetworkManager的DNS管理（如果存在）
if systemctl is-active --quiet NetworkManager; then
    echo "   检测到 NetworkManager，将配置其DNS设置"
fi

echo ""
echo "3. 配置DNS解析..."

# 删除原有的resolv.conf并创建新的
rm -f /etc/resolv.conf

# 创建新的resolv.conf
cat > /etc/resolv.conf << 'EOF'
# 固定DNS配置 - 由脚本自动生成
# 请勿手动修改此文件
nameserver 8.8.8.8
nameserver 1.1.1.1
options timeout:2
options attempts:3
options rotate
EOF

echo "   已设置DNS服务器为 8.8.8.8 和 1.1.1.1"

echo ""
echo "4. 防止重启后DNS配置被覆盖..."

# 方法1: 设置resolv.conf为不可变
chattr +i /etc/resolv.conf 2>/dev/null && echo "   已设置 /etc/resolv.conf 为不可变文件"

# 方法2: 配置systemd-resolved（如果存在）
if [ -f /etc/systemd/resolved.conf ]; then
    cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
    cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=
Domains=
LLMNR=no
MulticastDNS=no
DNSSEC=no
Cache=yes
DNSStubListener=no
EOF
    echo "   已配置 systemd-resolved.conf"
fi

# 方法3: 配置NetworkManager（如果存在）
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    # 检查是否已有dns=none配置
    if ! grep -q "dns=none" /etc/NetworkManager/NetworkManager.conf; then
        sed -i '/\[main\]/a dns=none' /etc/NetworkManager/NetworkManager.conf
        echo "   已配置 NetworkManager 不管理DNS"
        # 重启NetworkManager
        systemctl restart NetworkManager 2>/dev/null
    fi
fi

# 方法4: 配置dhclient不更新DNS
if [ -f /etc/dhcp/dhclient.conf ]; then
    # 备份原文件
    cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.bak
    
    # 添加或修改supersede domain-name-servers配置
    if grep -q "supersede domain-name-servers" /etc/dhcp/dhclient.conf; then
        sed -i 's/.*supersede domain-name-servers.*/supersede domain-name-servers 8.8.8.8, 1.1.1.1;/' /etc/dhcp/dhclient.conf
    else
        echo "supersede domain-name-servers 8.8.8.8, 1.1.1.1;" >> /etc/dhcp/dhclient.conf
    fi
    echo "   已配置 dhclient 使用固定DNS"
fi

# 方法5: 配置netplan（Ubuntu 18.04+）
netplan_files=$(find /etc/netplan -name "*.yaml" -o -name "*.yml" 2>/dev/null)
if [ ! -z "$netplan_files" ]; then
    for netplan_file in $netplan_files; do
        # 备份netplan文件
        cp "$netplan_file" "${netplan_file}.bak"
        
        # 这里只是提示，因为netplan配置较复杂，需要根据具体配置修改
        echo "   检测到netplan配置文件: $netplan_file"
        echo "   建议手动编辑netplan文件，在网络接口下添加："
        echo "     nameservers:"
        echo "       addresses: [8.8.8.8, 1.1.1.1]"
    done
fi

echo ""
echo "5. 创建监控脚本..."

# 创建DNS监控和恢复脚本
cat > /usr/local/bin/dns-guard.sh << 'EOF'
#!/bin/bash
# DNS监控脚本

TARGET_DNS1="8.8.8.8"
TARGET_DNS2="1.1.1.1"

# 检查当前DNS设置
current_dns=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')

if [[ "$current_dns" != *"$TARGET_DNS1"* ]] || [[ "$current_dns" != *"$TARGET_DNS2"* ]]; then
    echo "$(date): DNS被修改，正在恢复..." >> /var/log/dns-guard.log
    
    # 移除不可变属性
    chattr -i /etc/resolv.conf 2>/dev/null
    
    # 重新写入DNS配置
    cat > /etc/resolv.conf << 'DNSEOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
options timeout:2
options attempts:3
options rotate
DNSEOF
    
    # 重新设置不可变
    chattr +i /etc/resolv.conf 2>/dev/null
    
    echo "$(date): DNS已恢复为 8.8.8.8 和 1.1.1.1" >> /var/log/dns-guard.log
fi
EOF

chmod +x /usr/local/bin/dns-guard.sh
echo "   已创建DNS监控脚本: /usr/local/bin/dns-guard.sh"

# 添加crontab任务
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/dns-guard.sh") | crontab -
echo "   已添加crontab监控任务（每5分钟检查一次）"

# 创建systemd服务（开机自动执行）
cat > /etc/systemd/system/dns-fix.service << 'EOF'
[Unit]
Description=Fix DNS Configuration
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/dns-guard.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable dns-fix.service
echo "   已创建开机自启动服务: dns-fix.service"

echo ""
echo "6. 测试DNS解析..."

# 测试DNS解析
if nslookup google.com 8.8.8.8 >/dev/null 2>&1; then
    echo "   ✓ DNS解析测试成功"
else
    echo "   ✗ DNS解析测试失败，请检查网络连接"
fi

echo ""
echo "========================================="
echo "DNS配置完成！"
echo "========================================="
echo "当前DNS设置:"
cat /etc/resolv.conf
echo ""
echo "备份文件位置: $backup_dir"
echo "日志文件: /var/log/dns-guard.log"
echo ""
echo "如需撤销所有更改，请运行:"
echo "  chattr -i /etc/resolv.conf"
echo "  cp $backup_dir/resolv.conf /etc/resolv.conf"
echo "  crontab -l | grep -v dns-guard.sh | crontab -"
echo "  systemctl disable dns-fix.service"
echo "  rm /etc/systemd/system/dns-fix.service"
echo "  rm /usr/local/bin/dns-guard.sh"
echo ""
echo "建议重启系统测试配置是否生效!"
echo "========================================="
EOF