#!/bin/bash

set -e

echo "📦 正在检测并安装依赖：curl 和 sudo"

install_if_missing() {
    local cmd=$1
    local pkg=$2

    if ! command -v "$cmd" &>/dev/null; then
        echo "🔧 未检测到 $cmd，正在尝试安装 $pkg..."
        if command -v apt &>/dev/null; then
            apt update && apt install -y "$pkg"
        elif command -v dnf &>/dev/null; then
            dnf install -y "$pkg"
        elif command -v yum &>/dev/null; then
            yum install -y "$pkg"
        elif command -v pacman &>/dev/null; then
            pacman -Sy --noconfirm "$pkg"
        else
            echo "❌ 未支持的系统，请手动安装 $pkg 后重试。"
            exit 1
        fi
    fi
}

install_if_missing curl curl
install_if_missing sudo sudo

echo "📥 正在下载 bwhDNS.sh..."

curl -sSL https://raw.githubusercontent.com/<你的用户名>/fix-dns/main/bwhDNS.sh -o /tmp/bwhDNS.sh
chmod +x /tmp/bwhDNS.sh

echo "🚀 执行中：bwhDNS.sh"
sudo /tmp/bwhDNS.sh

