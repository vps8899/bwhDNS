#!/bin/bash
set -e

# ===== 🎨 颜色定义 =====
GREEN='\033[0;32m'    # 成功
RED='\033[0;31m'      # 错误
YELLOW='\033[1;33m'   # 警告
BLUE='\033[0;34m'     # 信息
NC='\033[0m'          # 重置颜色

# ===== 🔍 自动安装 curl =====
echo -e "${BLUE}📦 检查 curl...${NC}"
if ! command -v curl &>/dev/null; then
    echo -e "${YELLOW}⚠️ 未检测到 curl，尝试自动安装...${NC}"
    if command -v apt &>/dev/null; then
        apt update && apt install -y curl
    elif command -v yum &>/dev/null; then
        yum install -y curl
    elif command -v dnf &>/dev/null; then
        dnf install -y curl
    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm curl
    else
        echo -e "${RED}❌ 不支持的包管理器，无法安装 curl${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ curl 安装成功${NC}"
fi

# ===== 🔍 自动安装 sudo =====
echo -e "${BLUE}📦 检查 sudo...${NC}"
if ! command -v sudo &>/dev/null; then
    echo -e "${YELLOW}⚠️ 未检测到 sudo，尝试自动安装...${NC}"
    if command -v apt &>/dev/null; then
        apt update && apt install -y sudo
    elif command -v yum &>/dev/null; then
        yum install -y sudo
    elif command -v dnf &>/dev/null; then
        dnf install -y sudo
    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm sudo
    else
        echo -e "${RED}❌ 不支持的包管理器，无法安装 sudo${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ sudo 安装成功${NC}"
fi

# ===== 🔧 开始修复 DNS =====
echo -e "${BLUE}🔧 正在配置 DNS（8.8.8.8 / 1.1.1.1）...${NC}"

# 取消 resolv.conf 的符号链接（如有）
if [ -L /etc/resolv.conf ]; then
    sudo rm -f /etc/resolv.conf
    sudo touch /etc/resolv.conf
fi

# 写入固定 DNS
sudo bash -c 'cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF'

# 添加不可变锁
sudo chattr +i /etc/resolv.conf
echo -e "${GREEN}✅ resolv.conf 设置成功并已锁定${NC}"

# 禁用 systemd-resolved（如存在）
if systemctl is-enabled systemd-resolved &>/dev/null; then
    echo -e "${YELLOW}⚠️ 正在禁用 systemd-resolved...${NC}"
    sudo systemctl disable --now systemd-resolved
    echo -e "${GREEN}✅ 已禁用 systemd-resolved${NC}"
fi

# 添加到 /etc/rc.local 防止重启失效
if [ ! -f /etc/rc.local ]; then
    echo -e "#!/bin/bash\nexit 0" | sudo tee /etc/rc.local >/dev/null
    sudo chmod +x /etc/rc.local
fi

# 避免重复添加
if ! grep -q "resolv.conf" /etc/rc.local; then
    sudo sed -i '1i\chattr -i /etc/resolv.conf; echo -e "nameserver 8.8.8.8\\nnameserver 1.1.1.1" > /etc/resolv.conf; chattr +i /etc/resolv.conf' /etc/rc.local
    echo -e "${GREEN}✅ 已写入 /etc/rc.local 保持重启持久${NC}"
fi

# ===== ✅ 完成提示 =====
echo -e "${GREEN}🎉 DNS 配置成功并锁定为 8.8.8.8 / 1.1.1.1，重启后仍将生效。${NC}"
echo -e "${BLUE}📢 欢迎加入搬瓦工交流群：${NC}${YELLOW}https://t.me/bwh86${NC}"
