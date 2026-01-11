# Docker Xray 全能工具箱：IPv6 Reality 直连 + CF Tunnel 救急双模版

[![Docker](https://img.shields.io/badge/Docker-Enabled-blue?logo=docker)](https://www.docker.com/)
[![Xray](https://img.shields.io/badge/Xray-Core-green)](https://github.com/XTLS/Xray-core)
[![IPv6](https://img.shields.io/badge/IPv6-Ready-purple)]()
[![Cloudflare](https://img.shields.io/badge/Cloudflare-Zero%20Trust-orange?logo=cloudflare)](https://www.cloudflare.com/)

本项目提供基于 Docker 的**双模**科学上网解决方案。两个方案**完全独立、互不冲突**，可在同一台服务器上共存，助你打造“主备分离”的完美网络环境。

| 模式 | 🟢 模式一：IPv6 Reality (主力) | 🟡 模式二：CF Tunnel (备用) |
| :--- | :--- | :--- |
| **核心优势** | **极速、低延迟、原生IP** | **永不失联、隐藏IP、穿透内网** |
| **适用场景** | 日常主力使用，秒开 4K/8K 视频 | IPv6 抽风、IP 被墙、特殊时期救急 |
| **网络模式** | Docker Host (直通宿主机网卡) | Docker Bridge (隔离网络) |
| **依赖条件** | 服务器需有 IPv6 地址 | 需要 Cloudflare 账号 |
| **端口占用** | 占用宿主机端口 (默认 8443) | **0 端口占用** (无感穿透) |

---

## 🛠️ 准备工作

1.  一台 Linux 服务器 (Debian / Ubuntu / CentOS)。
2.  已安装 `curl` 或 `wget`。
3.  **模式一需求**：确认服务器拥有公网 IPv6 地址（运行 `ip -6 addr` 查看）。
4.  **模式二需求**：拥有 Cloudflare 账号及 Tunnel Token。

---

## 🚀 模式一：IPv6 Reality 极速部署 (推荐)

利用 Xray 的 VLESS-Vision-Reality 协议，配合 Docker 的 Host 模式，直接利用宿主机的 IPv6 通道，实现物理直连的极致速度。

### 一键安装命令
\bash
wget -N https://raw.githubusercontent.com/irol765/Cloudflare-Tunnel-/main/install_ipv6_reality.sh && chmod +x install_ipv6_reality.sh && ./install_ipv6_reality.sh
\

*(注：请确保将链接中的 `irol765/Cloudflare-Tunnel-` 替换为你实际的 GitHub 用户名和仓库名)*

### 配置说明
* **端口**：脚本默认使用 `8443`，完美避开 443 (可与 Nginx/FRP 共存)。
* **伪装**：默认伪装为 `www.apple.com`。
* **客户端**：安装完成后，**务必在客户端将地址栏修改为服务器的 IPv6 地址**。

---

## 🛡️ 模式二：Cloudflare Tunnel 救急部署 (保底)

利用 Cloudflare Argo Tunnel 进行内网穿透，将流量通过 Cloudflare 边缘节点中转。即使服务器 IP 被墙，或者没有公网 IPv6，依然能连接。

### 1. 获取 Token
登录 [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) -> `Networks` -> `Tunnels` -> `Create a tunnel` -> 复制 `--token` 后的字符串。

### 2. 一键安装命令
\bash
wget -N https://raw.githubusercontent.com/irol765/Cloudflare-Tunnel-/main/install_cf_xray.sh && chmod +x install_cf_xray.sh && ./install_cf_xray.sh
\

### 3. 后续配置 (Public Hostname)
脚本运行后，去 Cloudflare Tunnel 后台添加 Public Hostname：
* **Service**: `HTTP`
* **URL**: `xray-node:10000` (注意：直接填容器名，不要填 IP)

---

## 📂 文件与容器结构

两套系统使用独立的容器和配置目录，**互不干扰**。

| 项目 | IPv6 Reality (新) | CF Tunnel (旧) |
| :--- | :--- | :--- |
| **容器名称** | `xray-ipv6-reality` | `cf-tunnel-node` & `xray-node` |
| **配置文件** | `/etc/xray_ipv6_reality/config.json` | `/etc/xray_cf_tunnel/config.json` |
| **主要端口** | UDP/TCP 8443 (可改) | 无公网端口 |

## ⚠️ 免责声明

* 本脚本仅供学习交流和服务器维护使用。
* 请勿使用本方案进行任何违反当地法律法规的行为。
