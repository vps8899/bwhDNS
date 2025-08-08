#!/bin/bash
# BWH DNS 一键安装脚本
# GitHub: https://github.com/vps8899/bwhDNS

set -e

echo "========================================="
echo "BWH DNS 修复工具 - 一键安装"
echo "========================================="

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        OS="unknown"
    fi
    echo "检测到操作系统: $OS"
}

# 检查root权限
check_root() {
    if [ "$EUID" -eq 0 ]; then
        SUDO=""
        echo "当前为root用户"
    else
        SUDO="sudo"
        echo "当前为普通用户，将使用sudo权限"
        
        # 检查sudo是否存在，不存在则安装
        if ! command -v sudo >/dev/null 2>&1; then
            echo "正在安装sudo..."
            install_package "sudo"
        fi
    fi
}

# 安装软件包
install_package() {
    local package=$1
    echo "正在安装 $package..."
    
    case $OS in
        ubuntu|debian)
            apt-get update >/dev/null 2>&1 && apt-get install -y $package
            ;;
        centos|rhel)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y $package
            else
                yum install -y $package
            fi
            ;;
        fedora)
            dnf install -y $package
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm $package
            ;;
        opensuse*|sles)
            zypper install -y $package
            ;;
        alpine)
            apk add $package
            ;;
        *)
            echo "错误：不支持的操作系统 $OS"
            echo "请手动安装 $package 后重试"
            exit 1
            ;;
    esac
}

# 检查并安装下载工具
install_downloader() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl -fsSL"
        echo "使用curl下载"
        return 0
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget -qO-"
        echo "使用wget下载"
        return 0
    fi
    
    echo "未找到下载工具，正在安装curl..."
    install_package "curl"
    
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl -fsSL"
        echo "curl安装成功"
    else
        echo "curl安装失败，尝试安装wget..."
        install_package "wget"
        
        if command -v wget >/dev/null 2>&1; then
            DOWNLOADER="wget -qO-"
            echo "wget安装成功"
        else
            echo "错误：无法安装下载工具"
            exit 1
        fi
    fi
}

# 下载并执行主脚本
download_and_run() {
    echo ""
    echo "正在下载BWH DNS修复脚本..."
    
    # 尝试从GitHub下载
    local script_url="https://raw.githubusercontent.com/vps8899/bwhDNS/main/bwhDNS.sh"
    
    if $DOWNLOADER "$script_url" | $SUDO bash; then
        echo ""
        echo "========================================="
        echo "BWH DNS修复脚本执行完成！"
        echo "========================================="
    else
        echo "错误：脚本下载或执行失败"
        echo "请检查网络连接或手动下载安装"
        echo "手动安装方法："
        echo "1. 下载脚本: wget https://raw.githubusercontent.com/vps8899/bwhDNS/main/bwhDNS.sh"
        echo "2. 添加执行权限: chmod +x bwhDNS.sh"  
        echo "3. 运行脚本: sudo ./bwhDNS.sh"
        exit 1
    fi
}

# 主函数
main() {
    detect_os
    check_root
    install_downloader
    download_and_run
}

# 执行主函数
main