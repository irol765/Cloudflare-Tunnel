#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

# 检查 root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 必须使用 root 用户运行此脚本！${PLAIN}" 
   exit 1
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}未检测到 Docker，正在安装...${PLAIN}"
    curl -fsSL https://get.docker.com | bash
    systemctl start docker
    systemctl enable docker
fi

clear
echo -e "${SKYBLUE}#################################################${PLAIN}"
echo -e "${SKYBLUE}#     Cloudflare Tunnel + Xray 智能部署版       #${PLAIN}"
echo -e "${SKYBLUE}#################################################${PLAIN}"
echo ""

# ===========================
# 1. 智能信息采集
# ===========================

# 1. Token (支持粘贴整段命令)
echo -e "${YELLOW}1. Cloudflare Token 设置${PLAIN}"
echo -e "   您可以直接粘贴 Cloudflare 网页上那段完整的 'docker run ...' 命令，"
echo -e "   也可以只粘贴 '--token' 后面的那串字符。"
read -e -p "   请粘贴: " RAW_INPUT

# 自动提取 Token (正则匹配 ey 开头的长字符串)
# 逻辑：查找以 ey 开头，由字母数字破折号下划线组成，且长度超过 50 的字符串
CF_TOKEN=$(echo "$RAW_INPUT" | grep -oE 'ey[A-Za-z0-9\-_]{50,}' | head -n 1)

if [[ -z "$CF_TOKEN" ]]; then
    echo -e "${RED}错误：无法从您的输入中识别出有效的 Token。${PLAIN}"
    echo -e "请确保输入包含以 'ey' 开头的 Token 字符串。"
    exit 1
else
    echo -e "${GREEN}✔ 成功识别 Token!${PLAIN}"
fi

# 2. 域名 (主域名)
echo ""
read -e -p "2. 请输入你的主域名 (如 ip.sb): " ROOT_DOMAIN
if [[ -z "$ROOT_DOMAIN" ]]; then echo -e "${RED}域名不能为空${PLAIN}"; exit 1; fi

# 3. 前缀 (Subdomain)
echo ""
read -e -p "3. 请输入二级域名前缀 (如 www 或 vpn): " SUB_DOMAIN
if [[ -z "$SUB_DOMAIN" ]]; then SUB_DOMAIN="vpn"; fi

FULL_DOMAIN="${SUB_DOMAIN}.${ROOT_DOMAIN}"

# 4. 端口
echo ""
read -e -p "4. 请定义内部端口 [默认: 10000]: " PORT
[[ -z "$PORT" ]] && PORT=10000

# 5. 路径
echo ""
read -e -p "5. 请定义 WS 路径 [默认: /argo]: " WSPATH
[[ -z "$WSPATH" ]] && WSPATH="/argo"
if [[ "${WSPATH:0:1}" != "/" ]]; then WSPATH="/$WSPATH"; fi

# UUID 生成
UUID=$(cat /proc/sys/kernel/random/uuid)

# ===========================
# 2. 环境搭建
# ===========================

NET_NAME="cf_xray_net"
if ! docker network ls | grep -q "$NET_NAME"; then
    docker network create $NET_NAME > /dev/null
fi

WORK_DIR="/etc/xray_cf_tunnel"
mkdir -p $WORK_DIR

# 生成配置
cat > $WORK_DIR/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$UUID", "level": 0 } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "$WSPATH" }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

# ===========================
# 3. 容器运行 (自动清理旧容器)
# ===========================

echo ""
echo -e "${YELLOW}正在清理旧服务...${PLAIN}"
docker rm -f xray-node cf-tunnel-node &> /dev/null

echo -e "${YELLOW}正在启动 Xray...${PLAIN}"
docker run -d --name xray-node --restart unless-stopped --network $NET_NAME \
    -v $WORK_DIR/config.json:/etc/xray/config.json \
    teddysun/xray > /dev/null

echo -e "${YELLOW}正在启动 Cloudflare Tunnel...${PLAIN}"
# 注意：这里直接使用我们提取出来的纯净 CF_TOKEN
docker run -d --name cf-tunnel-node --restart unless-stopped --network $NET_NAME \
    cloudflare/cloudflared:latest tunnel --no-autoupdate run --token "$CF_TOKEN" > /dev/null

# ===========================
# 4. 结果输出
# ===========================

LINK="vless://${UUID}@${FULL_DOMAIN}:443?encryption=none&security=tls&type=ws&host=${FULL_DOMAIN}&path=${WSPATH}#CF-${SUB_DOMAIN}"

clear
echo -e "${SKYBLUE}======================================================${PLAIN}"
echo -e "${GREEN}                  部署成功！请执行下一步                  ${PLAIN}"
echo -e "${SKYBLUE}======================================================${PLAIN}"
echo ""
echo -e "${YELLOW}👉 第一步：去 Cloudflare 后台配置 Public Hostname${PLAIN}"
echo -e "   位置：Zero Trust Dashboard -> Access -> Tunnels -> Configure -> Public Hostname -> Add"
echo -e "   ------------------------------------------------------------"
echo -e "   Subdomain (子域名) : ${GREEN}${SUB_DOMAIN}${PLAIN}"
echo -e "   Domain (主域名)    : ${GREEN}${ROOT_DOMAIN}${PLAIN}"
echo -e "   Path (路径)        : (留空)"
echo -e "   ------------------------------------------------------------"
echo -e "   Service (服务类型) : ${GREEN}HTTP${PLAIN}"
echo -e "   URL (目标地址)     : ${GREEN}xray-node:${PORT}${PLAIN}"
echo -e "   ------------------------------------------------------------"
echo -e "   ${RED}*注意：URL 处必须填 xray-node，不要填 IP${PLAIN}"
echo ""
echo -e "${YELLOW}👉 第二步：复制订阅链接${PLAIN}"
echo -e "   ------------------------------------------------------------"
echo -e "${SKYBLUE}${LINK}${PLAIN}"
echo -e "   ------------------------------------------------------------"
echo ""
