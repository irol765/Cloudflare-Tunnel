#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

clear
echo -e "${SKYBLUE}#################################################${PLAIN}"
echo -e "${SKYBLUE}#       Xray IPv6 Reality 极速部署脚本          #${PLAIN}"
echo -e "${SKYBLUE}#     (Docker Host模式 / VLESS-Vision)          #${PLAIN}"
echo -e "${SKYBLUE}#################################################${PLAIN}"
echo ""

# 1. 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}未检测到 Docker，正在安装...${PLAIN}"
    curl -fsSL https://get.docker.com | bash
    systemctl start docker
    systemctl enable docker
fi

# 2. 交互配置
# 端口
echo ""
read -e -p "请输入端口 (默认 8443，避免与 FRP 443 冲突): " PORT
[[ -z "$PORT" ]] && PORT=8443

# 伪装域名
echo ""
read -e -p "请输入伪装域名 (默认 www.apple.com): " DEST_DOMAIN
[[ -z "$DEST_DOMAIN" ]] && DEST_DOMAIN="www.apple.com"

# 3. 生成密钥与 UUID
echo ""
echo -e "${YELLOW}正在生成密钥和 UUID...${PLAIN}"

# 临时启动一个容器来生成 ID 和 Key，确保无需在宿主机安装 xray
TEMP_INFO=$(docker run --rm teddysun/xray sh -c "echo UUID: \$(xray uuid) && xray x25519")

UUID=$(echo "$TEMP_INFO" | grep "UUID:" | awk '{print $2}')
PRIVATE_KEY=$(echo "$TEMP_INFO" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$TEMP_INFO" | grep "Public key:" | awk '{print $3}')

if [[ -z "$UUID" || -z "$PRIVATE_KEY" ]]; then
    echo -e "${RED}错误：无法生成 UUID 或密钥，请检查 Docker 是否正常。${PLAIN}"
    exit 1
fi

echo -e "UUID: ${GREEN}$UUID${PLAIN}"
echo -e "Private Key: ${GREEN}$PRIVATE_KEY${PLAIN}"
echo -e "Public Key: ${GREEN}$PUBLIC_KEY${PLAIN}"

# 4. 创建配置文件
WORK_DIR="/etc/xray_ipv6_reality"
mkdir -p $WORK_DIR

cat > $WORK_DIR/config.json <<JSON
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "::",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${DEST_DOMAIN}:443",
          "serverNames": [ "${DEST_DOMAIN}" ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [ "1688", "8888" ]
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
JSON

# 5. 启动容器 (Host 模式)
CONTAINER_NAME="xray-ipv6-reality"

echo ""
echo -e "${YELLOW}正在启动容器...${PLAIN}"
# 清理旧容器
docker rm -f $CONTAINER_NAME &> /dev/null

# 启动新容器
# 注意：network_mode: host 是 IPv6 直连的关键
docker run -d --name $CONTAINER_NAME \
    --restart unless-stopped \
    --network host \
    -v $WORK_DIR/config.json:/etc/xray/config.json \
    teddysun/xray > /dev/null

# 6. 获取 IPv6 地址 (尝试自动获取)
IPV6_ADDR=$(curl -s6m 5 https://ip.sb)
if [[ -z "$IPV6_ADDR" ]]; then
    IPV6_ADDR=$(ip -6 addr show | grep global | grep -v 'fd00' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
fi
[[ -z "$IPV6_ADDR" ]] && IPV6_ADDR="[你的IPv6地址]"

# 7. 生成分享链接
LINK="vless://${UUID}@${IPV6_ADDR}:${PORT}?security=reality&encryption=none&pbk=${PUBLIC_KEY}&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=${DEST_DOMAIN}&sid=1688#IPv6-Reality"

clear
echo -e "${SKYBLUE}======================================================${PLAIN}"
echo -e "${GREEN}                  部署成功！                  ${PLAIN}"
echo -e "${SKYBLUE}======================================================${PLAIN}"
echo -e "端口: ${GREEN}${PORT}${PLAIN}"
echo -e "UUID: ${GREEN}${UUID}${PLAIN}"
echo -e "Public Key: ${GREEN}${PUBLIC_KEY}${PLAIN}"
echo -e "IPv6 地址: ${GREEN}${IPV6_ADDR}${PLAIN}"
echo -e "------------------------------------------------------"
echo -e "${YELLOW}🚀 VLESS 链接 (直接复制导入):${PLAIN}"
echo -e "${SKYBLUE}${LINK}${PLAIN}"
echo -e "------------------------------------------------------"
echo -e "${YELLOW}⚠️ 注意：${PLAIN}"
echo -e "1. 客户端地址栏必须是 IPv6 地址 (如果是 v2rayN，直接粘贴链接即可)。"
echo -e "2. 确保你的本地网络已开启 IPv6 (test-ipv6.com 10/10)。"
echo -e "3. 如果链接里的 IP 不对，请手动修改为你在搬瓦工后台看到的 IPv6 地址。"
echo ""
