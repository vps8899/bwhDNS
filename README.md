# BWH DNS 修复工具

一键修复VPS的DNS配置问题，防止重启后DNS被重置为172内网地址。

## 🚀 一键安装

### 超级一键安装（自动处理所有依赖）
```
curl -sSL https://raw.githubusercontent.com/vps8899/bwhDNS/main/install.sh | bash
```

备用安装方式
如果上述命令失败，可以尝试：
```
bash <(curl -sSL https://raw.githubusercontent.com/vps8899/bwhDNS/main/install.sh)
```
✨ 特点

🔧 自动检测系统类型并安装依赖（sudo、curl）
🌐 设置可靠的DNS服务器（8.8.8.8 和 1.1.1.1）
🛡️ 多重防护机制，防止重启后配置丢失
📦 支持主流Linux发行版
🔄 自动监控和修复DNS配置
💾 自动备份原始配置

🖥️ 支持系统

Ubuntu/Debian
CentOS/RHEL 7/8/9
Fedora
Arch Linux
OpenSUSE
Alpine Linux


这样用户只需要复制一条命令就能完成所有操作，包括自动安装sudo和curl！脚本会智能检测系统环境并自动处理所有依赖。
