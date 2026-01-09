# Cloudflare Tunnel + Xray 一键部署脚本 (Docker)

[![Docker](https://img.shields.io/badge/Docker-Enabled-blue?logo=docker)](https://www.docker.com/)
[![Xray](https://img.shields.io/badge/Xray-Core-green)](https://github.com/XTLS/Xray-core)
[![Cloudflare](https://img.shields.io/badge/Cloudflare-Zero%20Trust-orange?logo=cloudflare)](https://www.cloudflare.com/)

一个基于 Docker 的自动化脚本，用于快速部署 **Cloudflare Tunnel (Argo)** 与 **Xray (VLESS-WebSocket)**。

无需公网 IP，无需开放防火墙端口，隐藏服务器真实 IP，实现安全的加密通信与内网穿透。是作为**备用救援线路**的绝佳方案。

## ✨ 特性

* **🐳 纯净容器化**：基于 `teddysun/xray` 和官方 `cloudflared` 镜像，环境隔离，不污染宿主机。
* **🔒 极致隐蔽**：服务器无需开放任何入站端口（0 Open Ports），防火墙可全关，有效防止主动探测和扫描。
* **⚡ 自动配置**：自动生成 UUID、配置 Docker 内部网络、生成 VLESS 订阅链接。
* **🌐 灵活定制**：支持自定义子域名、端口和 WebSocket 路径。
* **🚀 救活被墙 IP**：通过 Cloudflare 边缘节点中转，即使 VPS IP 被 TCP 阻断也能正常连接。

## 🛠️ 准备工作

在使用本脚本前，你需要：

1.  一台 Linux 服务器 (Debian / Ubuntu / CentOS)。
2.  已安装 `curl` 或 `wget`。
3.  一个 Cloudflare 账号，并将你的域名托管在 Cloudflare 上。
4.  **Cloudflare Tunnel Token** (获取方式见下文)。

## 🚀 快速开始

### 1. 获取 Cloudflare Tunnel Token
1.  登录 [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)。
2.  进入 `Networks` -> `Tunnels` -> `Create a tunnel`。
3.  选择 `Cloudflared`，点击 Next。
4.  在 "Install and run a connector" 页面，找到下方的命令代码。
5.  **复制 `--token` 后面的那长串字符** (这就是脚本需要的 Token)。

### 2. 一键运行脚本
在服务器终端执行以下命令：

```bash
wget -N https://raw.githubusercontent.com/irol765/Cloudflare-Tunnel-/main/install_cf_xray.sh && chmod +x install_cf_xray.sh && ./install_cf_xray.sh
```

### 3. 根据提示输入信息
脚本交互过程中需要输入以下内容：
* **Token**: 刚才复制的 Cloudflare Tunnel Token。
* **主域名**: 例如 `example.com`。
* **二级域名前缀**: 例如 `vpn` (最终域名为 `vpn.example.com`)。
* **内部端口**: 默认为 `10000` (可回车跳过)。
* **WS 路径**: 默认为 `/argo` (可回车跳过)。

## ⚙️ 后续配置 (关键步骤)

脚本运行成功后，会输出 **Xray 内部地址** (例如 `xray-node:10000`)。你需要去 Cloudflare 后台完成最后一步映射。

1.  回到 Cloudflare Tunnel 页面，点击你的 Tunnel，进入 **Public Hostname** 标签页。
2.  点击 **Add a public hostname**。
3.  填写如下信息：
    * **Subdomain**: 填写你在脚本中输入的前缀 (如 `vpn`)。
    * **Domain**: 选择你的主域名。
    * **Path**: 留空。
    * **Type**: 选择 `HTTP`。
    * **URL**: 填写 `xray-node:10000` (或你自定义的端口)。
    * *(注意：URL 这里直接填容器名，**不要**填 IP 地址)*。
4.  点击 **Save hostname**。

## 📱 客户端连接

脚本运行结束时会直接输出 **VLESS 链接**，复制该链接导入到你的客户端即可。

**手动配置参考：**
* **地址 (Address)**: `vpn.example.com` (你的完整域名)
* **端口 (Port)**: `443`
* **用户 ID (UUID)**: 查看脚本输出或 `config.json`
* **流控 (Flow)**: 空
* **传输协议 (Network)**: `ws` (WebSocket)
* **伪装域名 (Host)**: `vpn.example.com`
* **路径 (Path)**: `/argo` (或你自定义的路径)
* **传输层安全 (TLS)**: `tls` (开启)

## 📂 文件结构

* 脚本工作目录：`/etc/xray_cf_tunnel`
* Xray 配置文件：`/etc/xray_cf_tunnel/config.json`

## ⚠️ 免责声明

* 本脚本仅供学习交流和服务器维护使用。
* 请勿使用本方案进行任何违反当地法律法规的行为。
* 请勿长时间占用 Cloudflare 大量带宽（如 BT 下载），以免账号被封禁。

---
**如果觉得好用，请给个 Star ⭐️ 吧！**
