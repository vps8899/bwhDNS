#!/bin/bash
set -e

echo "🔧 正在配置 DNS..."

# 移除符号链接
if [ -L /etc/resolv.conf ]; then
    rm -f /etc/resolv.conf
    touch /etc/resolv.conf
fi

# 写入固定 DNS
cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

# 锁定文件
chattr +i /etc/resolv.conf

# 禁用 systemd-resolved（如存在）
if systemctl is-enabled systemd-resolved &>/dev/null; then
    systemctl disable --now systemd-resolved
fi

# 配置 rc.local（防重启恢复）
if [ ! -f /etc/rc.local ]; then
    echo -e "#!/bin/bash\nexit 0" > /etc/rc.local
    chmod +x /etc/rc.local
fi

grep -q "resolv.conf" /etc/rc.local || sed -i '1i\chattr -i /etc/resolv.conf; echo -e "nameserver 8.8.8.8\\nnameserver 1.1.1.1" > /etc/resolv.conf; chattr +i /etc/resolv.conf' /etc/rc.local

echo "✅ DNS 固定完成，当前使用 8.8.8.8 和 1.1.1.1"
