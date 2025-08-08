#!/bin/bash
set -e

# 🚀 自动安装 curl（如未安装），并重新执行脚本
if ! command -v curl &>/dev/null; then
    echo "🔍 未检测到 curl，正在安装 curl..."

    if command -v apt &>/dev/null; then
        apt update && apt install -y curl
    elif command -v yum &>/dev/null; then
        yum install -y curl
    elif command -v dnf &>/dev/null; then
        dnf install -y curl
    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm curl
    else
        echo "❌ 未识别的 Linux 包管理器，请手动安装 curl 后重试。"
        exit 1
    fi

    echo "✅ curl 安装完成，重新执行脚本..."
    exec curl -sSL https://raw.githubusercontent.com/vps8899/bwhDNS/main/install.sh | bash
fi

# ✅ 检查 sudo
if ! command -v sudo &>/dev/null; then
    echo "🔍 未检测到 sudo，正在安装 sudo..."

    if command -v apt &>/dev/null; then
        apt update && apt install -y sudo
    elif command -v yum &>/dev/null; then
        yum install -y sudo
    elif command -v dnf &>/dev/null; then
        dnf install -y sudo
    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm sudo
    else
        echo "❌ 无法自动安装 sudo，请手动安装。"
        exit 1
    fi
fi

echo "📥 正在下载 bwhDNS.sh 主脚本..."
curl -sSL https://raw.githubusercontent.com/vps8899/bwhDNS/main/bwhDNS.sh -o /tmp/bwhDNS.sh
chmod +x /tmp/bwhDNS.sh

echo "🚀 开始执行 DNS 固定脚本..."
sudo /tmp/bwhDNS.sh
