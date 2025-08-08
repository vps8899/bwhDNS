#!/bin/bash

# fix-dns.sh
# 强制设置 DNS 为 8.8.8.8 和 1.1.1.1，适用于 VPS 和本地 Linux

set -e

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "请以 root 用户运行本脚本。"
    exit 1
fi

echo "[1/5] 处理 /etc/resolv.conf..."

# 取消符号链接
if [[ -L /etc/resolv.conf ]]; then
    echo "取消 /etc/resolv.conf 的符号链接..."
    rm -f /etc/resolv.conf
    touch /etc/resolv.conf
fi

echo "[2/5] 设置固定 DNS..."
cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

echo "[3/5] 设置不可变属性防止篡改..."
chattr +i /etc/resolv.conf

echo "[4/5] 禁用 systemd-resolved（如存在）..."
if systemctl is-enabled systemd-resolved &>/dev/null; then
    systemctl disable --now systemd-resolved
fi

echo "[5/5] 配置 /etc/rc.local 防重启恢复..."
RCLOCAL="/etc/rc.local"
if [ ! -f "$RCLOCAL" ]; then
    echo "#!/bin/bash" > "$RCLOCAL"
    chmod +x "$RCLOCAL"
fi

grep -q "resolv.conf" "$RCLOCAL" || cat >> "$RCLOCAL" <<'EOF'

# DNS 固定写入策略
chattr -i /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf
EOF

echo "✅ DNS 固定完成！当前配置为 8.8.8.8 与 1.1.1.1，重启后仍将生效。"
