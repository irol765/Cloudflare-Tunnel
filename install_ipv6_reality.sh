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
echo -e "${SKYBLUE}#   (特洛伊木马版：挂载官方核心生成唯一密钥)    #${PLAIN}"
echo -e "${SKYBLUE}#################################################${PLAIN}"
echo ""

# 1. 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}未检测到 Docker，正在安装...${PLAIN}"
    curl -fsSL https://get.docker.com | bash
    systemctl start docker
    systemctl enable docker
fi

# 2. 检查并安装 Unzip (解压需要)
if ! command -v unzip &> /dev/null; then
    echo -e "${YELLOW}正在安装 unzip...${PLAIN}"
    if [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y unzip
    elif [ -f /etc/redhat-release ]; then
        yum install -y unzip
    fi
fi

# 3. 交互配置
echo ""
read -e -p "请输入端口 (默认 8443，避免与 FRP 443 冲突): " PORT
[[ -z "$PORT" ]] && PORT=8443

echo ""
read -e -p "请输入伪装域名 (默认 www.apple.com): " DEST_DOMAIN
[[ -z "$DEST_DOMAIN" ]] && DEST_DOMAIN="www.apple.com"

# 4. 【核心黑科技】下载官方 Xray 核心并挂载生成密钥
echo ""
echo -e "${YELLOW}正在使用“特洛伊木马”策略生成唯一密钥...${PLAIN}"

# 检测架构
ARCH=$(uname -m)
if [[ $ARCH == "x86_64" ]]; then
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip"
elif [[ $ARCH == "aarch64" ]]; then
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-arm64-v8a.zip"
else
    echo -e "${RED}不支持的架构: $ARCH${PLAIN}"
    exit 1
fi

# 下载官方核心到临时目录
mkdir -p /tmp/xray_temp_gen
wget -qO /tmp/xray_temp_gen/xray.zip $DOWNLOAD_URL
unzip -q /tmp/xray_temp_gen/xray.zip -d /tmp/xray_temp_gen
chmod +x /tmp/xray_temp_gen/xray

# 启动容器：使用 teddysun 镜像（绕过看门狗），但挂载 /tmp/xray_temp_gen/xray 进去执行
TEMP_INFO=$(docker run --rm \
    -v /tmp/xray_temp_gen/xray:/xray_bin \
    --entrypoint /xray_bin \
    teddysun/xray x25519)

# 清理临时文件
rm -rf /tmp/xray_temp_gen

# 提取密钥
UUID=$(cat /proc/sys/kernel/random/uuid) # 使用系统原生 UUID
PRIVATE_KEY=$(echo "$TEMP_INFO" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$TEMP_INFO" | grep "Public key:" | awk '{print $3}')

# 检查是否成功
if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
    echo -e "${RED}错误：密钥生成失败。${PLAIN}"
    echo -e "调试信息: $TEMP_INFO"
    exit 1
fi

echo -e "UUID: ${GREEN}$UUID${PLAIN} (随机生成)"
echo -e "Private Key: ${GREEN}$PRIVATE_KEY${PLAIN} (官方核心生成)"
echo -e "Public Key: ${GREEN}$PUBLIC_KEY${PLAIN} (官方核心生成)"

# 5. 创建配置文件
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

# 6. 启动容器 (Host 模式)
CONTAINER_NAME="xray-ipv6-reality"

echo ""
echo -e "${YELLOW}正在启动容器...${PLAIN}"
docker rm -f $CONTAINER_NAME &> /dev/null

# 正常运行时依然使用 teddysun 镜像
docker run -d --name $CONTAINER_NAME \
    --restart unless-stopped \
    --network host \
    -v $WORK_DIR/config.json:/etc/xray/config.json \
    teddysun/xray > /dev/null

# 7. 获取 IPv6 地址 (优先读取网卡，失败再尝试 curl)
echo -e "${YELLOW}正在获取 IPv6 地址...${PLAIN}"
IPV6_ADDR=$(ip -6 addr show | grep global | grep -v 'fd00' | grep -v 'fe80' | awk '{print $2}' | cut -d/ -f1 | head -n 1)

if [[ -z "$IPV6_ADDR" ]]; then
    # 如果网卡没读到，再尝试 curl
    IPV6_ADDR=$(curl -s6m 5 https://ifconfig.co)
fi

# 再次兜底
[[ -z "$IPV6_ADDR" || "$IPV6_ADDR" == *"html"* ]] && IPV6_ADDR="[你的IPv6地址]"

# 8. 生成分享链接
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
echo -e "1. 如果链接里的地址依然不正确，请手动将 '[你的IPv6地址]' 替换为 VPS 的真实 IPv6。"
echo -e "2. 请确保本地网络已开启 IPv6。"
echo ""
