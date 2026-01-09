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
echo -e "${SKYBLUE}#     Cloudflare Tunnel + Xray 自动化部署       #${PLAIN}"
echo -e "${SKYBLUE}#################################################${PLAIN}"
echo ""

# ===========================
# 1. 信息采集
# ===========================

# 1. Token
read -p "1. 请粘贴 Cloudflare Tunnel Token: " CF_TOKEN
if [[ -z "$CF_TOKEN" ]]; then echo -e "${RED}Token 不能为空${PLAIN}"; exit 1; fi

# 2. 域名 (主域名)
read -p "2. 请输入你的主域名 (如 ip.sb): " ROOT_DOMAIN
if [[ -z "$ROOT_DOMAIN" ]]; then echo -e "${RED}域名不能为空${PLAIN}"; exit 1; fi

# 3. 前缀 (Subdomain) - 新增，为了输出更精准
read -p "3. 请输入你想使用的二级域名前缀 (如 www 或 vpn): " SUB_DOMAIN
if [[ -z "$SUB_DOMAIN" ]]; then SUB_DOMAIN="vpn"; fi

FULL_DOMAIN="${SUB_DOMAIN}.${ROOT_DOMAIN}"

# 4. 端口
read -p "4. 请定义内部端口 [默认: 10000]: " PORT
[[ -z "$PORT" ]] && PORT=10000

# 5. 路径
read -p "5. 请定义 WS 路径 [默认: /argo]: " WSPATH
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
# 3. 容器运行
# ===========================

# 清理旧容器
docker rm -f xray-node cf-tunnel-node &> /dev/null

echo -e "${YELLOW}正在启动 Xray...${PLAIN}"
docker run -d --name xray-node --restart unless-stopped --network $NET_NAME \
    -v $WORK_DIR/config.json:/etc/xray/config.json \
    teddysun/xray > /dev/null

echo -e "${YELLOW}正在启动 Tunnel...${PLAIN}"
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
echo -e "   ${RED}*注意：URL 处必须填 xray-node，不要填 IP，也不要加 http://前缀${PLAIN}"
echo ""
echo -e "${YELLOW}👉 第二步：复制订阅链接${PLAIN}"
echo -e "   ------------------------------------------------------------"
echo -e "${SKYBLUE}${LINK}${PLAIN}"
echo -e "   ------------------------------------------------------------"
echo ""
