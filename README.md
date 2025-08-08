# BWH DNS 修复工具

一键修复VPS的DNS配置问题，防止重启后DNS被重置为内网地址。

## 快速安装

### 一键安装（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/vps8899/bwhDNS/main/bwhDNS.sh | sudo bash
或者使用 wget
bashwget -qO- https://raw.githubusercontent.com/vps8899/bwhDNS/main/bwhDNS.sh | sudo bash
功能特点

自动备份原始配置
设置可靠的DNS服务器（8.8.8.8 和 1.1.1.1）
多重防护机制，防止重启后配置丢失
支持主流Linux发行版
自动监控和修复DNS配置


**推荐使用方法一的curl命令**，因为它：
- 使用了安全的HTTPS连接
- `-fsSL`参数确保静默下载且失败时报错
- 最为简洁易记

用户只需要复制粘贴一行命令就能完成安装，非常方便！
