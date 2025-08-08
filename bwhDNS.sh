#!/usr/bin/env bash
set -Eeuo pipefail

# ========= 参数解析 =========
IFACE=""
ADDR=""     # 例: 192.168.1.50/24 | 或者传 keep
GW=""       # 例: 192.168.1.1    | 或者传 keep
DNS=""      # 例: "8.8.8.8 1.1.1.1"
APPLY_ONLY_DNS=false

usage() {
  cat <<'EOF'
Usage:
  sudo set-static-ip.sh --iface eth0 --addr 192.168.1.50/24 --gw 192.168.1.1 --dns "8.8.8.8 1.1.1.1"

Notes:
  - --addr keep --gw keep  只更新 DNS，不改 IP/网关（适合你“只想把 DHCP 下来的 172.* DNS 改掉”的情况）
  - 脚本会自动检测当前使用的网络栈：netplan / NetworkManager / ifupdown
  - 不会锁定 /etc/resolv.conf，也不会禁用 systemd-resolved；DNS 将通过网络栈持久化
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iface) IFACE="$2"; shift 2 ;;
    --addr)  ADDR="$2";  shift 2 ;;
    --gw)    GW="$2";    shift 2 ;;
    --dns)   DNS="$2";   shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "请用 root 运行（sudo）" >&2; exit 1
fi
if [[ -z "${IFACE}" ]]; then
  echo "--iface 必填" >&2; usage; exit 1
fi
if [[ -z "${DNS}" ]]; then
  echo "--dns 必填（空格分隔多个）" >&2; usage; exit 1
fi
if [[ "${ADDR:-}" == "keep" && "${GW:-}" == "keep" ]]; then
  APPLY_ONLY_DNS=true
fi

# ========= 环境检测 =========
has_cmd(){ command -v "$1" &>/dev/null; }

NETSTACK="unknown"   # netplan | nm | ifupdown
RENDERER=""

if compgen -G "/etc/netplan/*.yaml" >/dev/null; then
  NETSTACK="netplan"
  # 尝试从现有 netplan 里找 renderer
  RENDERER=$(grep -R "renderer:" /etc/netplan/*.yaml 2>/dev/null | awk -F: '{print $NF}' | tr -d ' ' | tail -n1 || true)
  RENDERER=${RENDERER:-networkd}
elif has_cmd nmcli && nmcli -t -f STATE general status 2>/dev/null | grep -q connected; then
  NETSTACK="nm"
elif [[ -f /etc/network/interfaces || -d /etc/network/interfaces.d ]]; then
  NETSTACK="ifupdown"
elif has_cmd nmcli; then
  NETSTACK="nm"
fi

echo "检测到网络栈: ${NETSTACK}${RENDERER:+ (renderer=${RENDERER})}"

# ========= 工具函数 =========
backup_file(){
  local f="$1"
  [[ -f "$f" ]] && cp -a "$f" "${f}.bak.$(date +%s)"
}

# ========= 各栈实现 =========

apply_netplan(){
  local file="/etc/netplan/99-${IFACE}-static.yaml"
  local cur_renderer="${RENDERER:-networkd}"

  if $APPLY_ONLY_DNS; then
    # 只改 DNS：保留地址配置（不触碰 dhcp 设置），通过 nameservers 覆盖
    # 为避免覆盖现有文件复杂结构，这里生成一个合并片段（netplan 支持多文件合并）
    backup_file "$file"
    cat > "$file" <<EOF
network:
  version: 2
  renderer: ${cur_renderer}
  ethernets:
    ${IFACE}:
      nameservers:
        addresses: [$(echo "$DNS" | sed 's/ /, /g')]
      dhcp4-overrides:
        use-dns: false
EOF
  else
    if [[ -z "${ADDR}" || -z "${GW}" ]]; then
      echo "netplan 模式需要 --addr 和 --gw" >&2; exit 1
    fi
    backup_file "$file"
    cat > "$file" <<EOF
network:
  version: 2
  renderer: ${cur_renderer}
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses: [${ADDR}]
      routes:
        - to: default
          via: ${GW}
      nameservers:
        addresses: [$(echo "$DNS" | sed 's/ /, /g')]
EOF
  fi

  netplan generate
  netplan apply
  # 若系统在用 NetworkManager 的 renderer，顺手踢一下
  systemctl try-reload-or-restart NetworkManager 2>/dev/null || true
  systemctl try-reload-or-restart systemd-networkd 2>/dev/null || true
}

apply_nm(){
  # 找到 iface 对应的连接名（优先有线）
  local con
  con=$(nmcli -t -f NAME,DEVICE,TYPE connection show --active | awk -F: -v i="${IFACE}" '$2==i{print $1}' | head -n1)
  if [[ -z "$con" ]]; then
    # 不在激活列表，尝试按设备名匹配配置
    con=$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v i="${IFACE}" '$2==i{print $1}' | head -n1)
  fi
  if [[ -z "$con" ]]; then
    # 创建一个新连接
    con="${IFACE}-manual"
    nmcli connection add type ethernet ifname "${IFACE}" con-name "${con}" >/dev/null
  fi

  if $APPLY_ONLY_DNS; then
    nmcli connection modify "${con}" \
      ipv4.ignore-auto-dns yes \
      ipv4.dns "$(echo "$DNS" | tr ' ' ',')" \
      ipv4.dns-search ""
  else
    if [[ -z "${ADDR}" || -z "${GW}" ]]; then
      echo "NetworkManager 模式需要 --addr 和 --gw（若只想改 DNS，用 --addr keep --gw keep）" >&2; exit 1
    fi
    nmcli connection modify "${con}" \
      ipv4.method manual \
      ipv4.addresses "${ADDR}" \
      ipv4.gateway "${GW}" \
      ipv4.ignore-auto-dns yes \
      ipv4.dns "$(echo "$DNS" | tr ' ' ',')" \
      ipv4.dns-search "" \
      connection.autoconnect yes
    nmcli connection modify "${con}" ipv6.method ignore || true
  fi

  nmcli connection down "${con}" >/dev/null 2>&1 || true
  nmcli connection up "${con}"
}

apply_ifupdown(){
  mkdir -p /etc/network/interfaces.d
  local file="/etc/network/interfaces.d/${IFACE}"
  backup_file "$file"

  if $APPLY_ONLY_DNS; then
    # 保留现有地址设置，仅通过 resolvconf/ifupdown 提供 dns-nameservers
    # 注意：dns-nameservers 依赖 resolvconf 包来写 resolv.conf
    if ! dpkg -s resolvconf &>/dev/null; then
      apt-get update && apt-get install -y resolvconf
    fi
    # 尝试读取现有 stanza，不改 auto/up 等
    cat > "$file" <<EOF
allow-hotplug ${IFACE}
iface ${IFACE} inet dhcp
    dns-nameservers ${DNS}
EOF
  else
    if [[ -z "${ADDR}" || -z "${GW}" ]]; then
      echo "ifupdown 模式需要 --addr 和 --gw" >&2; exit 1
    fi
    local ip=$(echo "$ADDR" | cut -d/ -f1)
    local pre=$(echo "$ADDR" | cut -d/ -f2)
    # 转换 prefix 为 netmask
    mask() {
      local p=$1; local m=0xffffffff; ((m<<=(32-p))); local a=$(( (0xffffffff ^ m) & 0xffffffff ))
      printf "%d.%d.%d.%d" $(( (a>>24)&255 )) $(( (a>>16)&255 )) $(( (a>>8)&255 )) $(( a&255 ))
    }
    local netmask; netmask=$(mask "$pre")

    cat > "$file" <<EOF
auto ${IFACE}
iface ${IFACE} inet static
    address ${ip}
    netmask ${netmask}
    gateway ${GW}
    dns-nameservers ${DNS}
EOF
  fi

  ifdown "${IFACE}" 2>/dev/null || true
  ifup "${IFACE}"
}

# ========= 执行 =========
case "$NETSTACK" in
  netplan)      apply_netplan ;;
  nm)           apply_nm ;;
  ifupdown)     apply_ifupdown ;;
  *)
    echo "无法识别网络栈。请安装并使用 netplan 或 NetworkManager，或手动维护 /etc/network/interfaces。" >&2
    exit 1
    ;;
esac

echo "✅ 完成：网络配置已更新（${NETSTACK}${RENDERER:+/${RENDERER}}）。"
echo "   接口: ${IFACE}"
$APPLY_ONLY_DNS || echo "   IPv4: ${ADDR}  网关: ${GW}"
echo "   DNS : ${DNS}"
