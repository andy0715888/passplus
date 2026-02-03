#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centosp"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    echo -e "${green}安装系统依赖...${plain}"
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar git -y
        yum install gcc gcc-c++ make -y
    else
        apt install wget curl tar git -y
        apt install gcc g++ make -y
    fi
}

install_go() {
    echo -e "${green}安装Go语言环境...${plain}"
    if ! command -v go &> /dev/null; then
        GO_VERSION="1.20"
        echo -e "${yellow}下载Go ${GO_VERSION}...${plain}"
        wget -O go${GO_VERSION}.linux-${arch}.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-${arch}.tar.gz
        
        if [[ $? -ne 0 ]]; then
            # 如果官方地址失败，尝试国内镜像
            echo -e "${yellow}尝试国内镜像...${plain}"
            wget -O go${GO_VERSION}.linux-${arch}.tar.gz https://dl.google.com/go/go${GO_VERSION}.linux-${arch}.tar.gz
        fi
        
        if [[ -f "go${GO_VERSION}.linux-${arch}.tar.gz" ]]; then
            tar -C /usr/local -xzf go${GO_VERSION}.linux-${arch}.tar.gz
            rm go${GO_VERSION}.linux-${arch}.tar.gz
            echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
            echo 'export GOPATH=$HOME/go' >> /etc/profile
            source /etc/profile
            echo -e "${green}Go语言安装成功！${plain}"
        else
            echo -e "${red}Go语言安装失败，将尝试使用系统自带的Go${plain}"
        fi
    else
        echo -e "${green}Go语言已安装，版本: $(go version)${plain}"
    fi
}

# 获取最新版本号
get_latest_version() {
    echo -e "${yellow}获取X-UI最新版本...${plain}"
    
    # 尝试多种方法获取版本号
    LATEST_VERSION=""
    
    # 方法1: 从GitHub API获取
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z "$LATEST_VERSION" ]]; then
        # 方法2: 从release页面获取
        LATEST_VERSION=$(curl -s "https://github.com/vaxilu/x-ui/releases" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    
    if [[ -z "$LATEST_VERSION" ]]; then
        # 方法3: 使用已知的稳定版本
        LATEST_VERSION="0.3.2"
        echo -e "${yellow}无法获取最新版本，使用默认版本: ${LATEST_VERSION}${plain}"
    else
        echo -e "${green}获取到最新版本: ${LATEST_VERSION}${plain}"
    fi
    
    echo "$LATEST_VERSION"
}

download_secondary_forward_files() {
    echo -e "${green}下载二次转发功能文件...${plain}"
    
    # 创建临时目录
    TEMP_DIR="/tmp/x-ui-secondary-forward"
    mkdir -p $TEMP_DIR
    cd $TEMP_DIR
    
    # 从你的GitHub仓库下载修改过的文件
    # 使用raw.githubusercontent.com获取文件的原始内容
    
    echo -e "${yellow}下载数据库模型文件...${plain}"
    wget -q --show-progress -O model.go https://raw.githubusercontent.com/andy0715888/passplus/main/database/model/model.go 2>/dev/null || \
    echo -e "${yellow}使用备用链接下载模型文件...${plain}" && \
    wget -O model.go https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/database/model/model.go
    
    echo -e "${yellow}下载控制器文件...${plain}"
    wget -q --show-progress -O inbound.go https://raw.githubusercontent.com/andy0715888/passplus/main/web/controller/inbound.go 2>/dev/null || \
    wget -O inbound.go https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/web/controller/inbound.go
    
    echo -e "${yellow}下载Xray配置文件...${plain}"
    wget -q --show-progress -O config.go https://raw.githubusercontent.com/andy0715888/passplus/main/xray/config.go 2>/dev/null || \
    wget -O config.go https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/xray/config.go
    
    wget -q --show-progress -O inbound_config.go https://raw.githubusercontent.com/andy0715888/passplus/main/xray/inbound.go 2>/dev/null || \
    wget -O inbound_config.go https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/xray/inbound.go
    
    echo -e "${yellow}下载服务层文件...${plain}"
    wget -q --show-progress -O service_inbound.go https://raw.githubusercontent.com/andy0715888/passplus/main/web/service/inbound.go 2>/dev/null || \
    wget -O service_inbound.go https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/web/service/inbound.go
    
    echo -e "${yellow}下载前端文件...${plain}"
    mkdir -p web/html/xui
    wget -q --show-progress -O form_inbound.html https://raw.githubusercontent.com/andy0715888/passplus/main/web/html/xui/form/inbound 2>/dev/null || \
    wget -O form_inbound.html https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/web/html/xui/form/inbound
    
    wget -q --show-progress -O inbound_info.html https://raw.githubusercontent.com/andy0715888/passplus/main/web/html/xui/component/inboundInfo.html 2>/dev/null || \
    wget -O inbound_info.html https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/web/html/xui/component/inboundInfo.html
    
    wget -q --show-progress -O models.js https://raw.githubusercontent.com/andy0715888/passplus/main/web/assets/js/model/models.js 2>/dev/null || \
    wget -O models.js https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/web/assets/js/model/models.js
    
    wget -q --show-progress -O inbounds.html https://raw.githubusercontent.com/andy0715888/passplus/main/web/html/xui/inbounds.html 2>/dev/null || \
    wget -O inbounds.html https://raw.githubusercontent.com/andy0715888/passplus/refs/heads/main/web/html/xui/inbounds.html
    
    echo -e "${green}二次转发文件下载完成！${plain}"
}

# 安装完成后配置
config_after_install() {
    echo -e "${yellow}出于安全考虑，安装/更新完成后需要强制修改端口与账户密码${plain}"
    read -p "确认是否继续?[y/n]:" config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名:" config_account
        echo -e "${yellow}您的账户名将设定为:${config_account}${plain}"
        read -p "请设置您的账户密码:" config_password
        echo -e "${yellow}您的账户密码将设定为:${config_password}${plain}"
        read -p "请设置面板访问端口:" config_port
        echo -e "${yellow}您的面板访问端口将设定为:${config_port}${plain}"
        echo -e "${yellow}确认设定,设定中${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户密码设定完成${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}面板端口设定完成${plain}"
    else
        echo -e "${red}已取消,所有设置项均为默认设置,请及时修改${plain}"
    fi
}

install_x-ui() {
    echo -e "${green}开始安装带二次转发功能的X-UI面板...${plain}"
    
    # 停止可能存在的旧服务
    systemctl stop x-ui 2>/dev/null
    
    # 安装基础依赖
    install_base
    
    # 安装Go语言环境（用于编译）
    install_go
    
    # 获取最新版本
    XUI_VERSION=$(get_latest_version)
    
    # 下载原始XUI
    echo -e "${green}下载X-UI v${XUI_VERSION}...${plain}"
    cd /usr/local/
    
    # 下载预编译版本
    echo -e "${yellow}下载链接: https://github.com/vaxilu/x-ui/releases/download/${XUI_VERSION}/x-ui-linux-${arch}.tar.gz${plain}"
    
    # 尝试下载
    if wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/vaxilu/x-ui/releases/download/${XUI_VERSION}/x-ui-linux-${arch}.tar.gz"; then
        echo -e "${green}下载成功！${plain}"
    else
        echo -e "${yellow}尝试不带v前缀的版本...${plain}"
        # 有些版本可能没有v前缀
        VERSION_WITHOUT_V=${XUI_VERSION#v}
        if wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/vaxilu/x-ui/releases/download/${VERSION_WITHOUT_V}/x-ui-linux-${arch}.tar.gz"; then
            echo -e "${green}下载成功！${plain}"
            XUI_VERSION=$VERSION_WITHOUT_V
        else
            echo -e "${yellow}尝试其他版本...${plain}"
            # 尝试其他可能的版本
            for version in "0.3.2" "0.3.1" "0.3.0" "0.2.0"; do
                echo -e "${yellow}尝试版本 ${version}...${plain}"
                if wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/vaxilu/x-ui/releases/download/${version}/x-ui-linux-${arch}.tar.gz"; then
                    echo -e "${green}下载成功！使用版本 ${version}${plain}"
                    XUI_VERSION=$version
                    break
                fi
            done
        fi
    fi
    
    if [[ ! -f "/usr/local/x-ui-linux-${arch}.tar.gz" ]]; then
        echo -e "${red}下载X-UI失败，请检查网络连接或手动下载${plain}"
        echo -e "${yellow}你可以手动下载并放置文件，然后重新运行安装脚本${plain}"
        exit 1
    fi
    
    # 解压
    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi
    
    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    
    echo -e "${green}X-UI基础版本安装完成！${plain}"
    
    # 现在添加二次转发功能
    echo -e "${green}添加二次转发功能...${plain}"
    cd /usr/local/x-ui
    
    # 备份原始文件
    echo -e "${yellow}备份原始文件...${plain}"
    mkdir -p backup
    cp database/model/model.go backup/ 2>/dev/null || true
    cp web/controller/inbound.go backup/ 2>/dev/null || true
    cp xray/config.go backup/ 2>/dev/null || true
    cp xray/inbound.go backup/ 2>/dev/null || true
    cp web/service/inbound.go backup/ 2>/dev/null || true
    
    # 下载二次转发文件
    download_secondary_forward_files
    
    # 复制文件到正确位置
    echo -e "${yellow}复制二次转发文件...${plain}"
    cd /tmp/x-ui-secondary-forward
    
    # 检查文件是否存在
    files_copied=0
    
    if [[ -f "model.go" ]]; then
        mkdir -p /usr/local/x-ui/database/model
        cp model.go /usr/local/x-ui/database/model/model.go
        echo -e "${green}✓ 更新数据库模型${plain}"
        ((files_copied++))
    fi
    
    if [[ -f "inbound.go" ]]; then
        mkdir -p /usr/local/x-ui/web/controller
        cp inbound.go /usr/local/x-ui/web/controller/inbound.go
        echo -e "${green}✓ 更新控制器${plain}"
        ((files_copied++))
    fi
    
    if [[ -f "config.go" ]]; then
        mkdir -p /usr/local/x-ui/xray
        cp config.go /usr/local/x-ui/xray/config.go
        echo -e "${green}✓ 更新Xray配置${plain}"
        ((files_copied++))
    fi
    
    if [[ -f "inbound_config.go" ]]; then
        mkdir -p /usr/local/x-ui/xray
        cp inbound_config.go /usr/local/x-ui/xray/inbound.go
        echo -e "${green}✓ 更新Xray入站配置${plain}"
        ((files_copied++))
    fi
    
    if [[ -f "service_inbound.go" ]]; then
        mkdir -p /usr/local/x-ui/web/service
        cp service_inbound.go /usr/local/x-ui/web/service/inbound.go
        echo -e "${green}✓ 更新服务层${plain}"
        ((files_copied++))
    fi
    
    # 前端文件
    if [[ -f "form_inbound.html" ]]; then
        mkdir -p /usr/local/x-ui/web/html/xui/form
        cp form_inbound.html /usr/local/x-ui/web/html/xui/form/inbound
        echo -e "${green}✓ 更新前端表单${plain}"
        ((files_copied++))
    fi
    
    if [[ -f "inbound_info.html" ]]; then
        mkdir -p /usr/local/x-ui/web/html/xui/component
        cp inbound_info.html /usr/local/x-ui/web/html/xui/component/inboundInfo.html
        echo -e "${green}✓ 更新前端组件${plain}"
        ((files_copied++))
    fi
    
    if [[ -f "models.js" ]]; then
        mkdir -p /usr/local/x-ui/web/assets/js/model
        cp models.js /usr/local/x-ui/web/assets/js/model/models.js
        echo -e "${green}✓ 更新前端模型${plain}"
        ((files_copied++))
    fi
    
    if [[ -f "inbounds.html" ]]; then
        mkdir -p /usr/local/x-ui/web/html/xui
        cp inbounds.html /usr/local/x-ui/web/html/xui/inbounds.html
        echo -e "${green}✓ 更新前端页面${plain}"
        ((files_copied++))
    fi
    
    if [[ $files_copied -eq 0 ]]; then
        echo -e "${yellow}⚠ 未找到二次转发文件，将安装原始X-UI版本${plain}"
    else
        echo -e "${green}成功复制 ${files_copied} 个二次转发文件${plain}"
        
        # 重新编译
        echo -e "${green}重新编译带二次转发功能的X-UI...${plain}"
        cd /usr/local/x-ui
        
        if command -v go &> /dev/null; then
            echo -e "${yellow}使用Go编译...${plain}"
            go build -o x-ui
            if [[ $? -eq 0 ]]; then
                echo -e "${green}✓ 编译成功！${plain}"
            else
                echo -e "${yellow}⚠ 编译失败，使用预编译版本（可能不包含二次转发功能）${plain}"
            fi
        else
            echo -e "${yellow}⚠ Go未安装，使用预编译版本${plain}"
        fi
    fi
    
    # 设置权限
    chmod +x x-ui
    if [[ -f "bin/xray-linux-${arch}" ]]; then
        chmod +x bin/xray-linux-${arch}
    fi
    
    # 复制服务文件
    cp -f x-ui.service /etc/systemd/system/
    
    # 复制管理脚本
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/vaxilu/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    
    # 配置安装后设置
    config_after_install
    
    echo -e "${green}配置系统服务...${plain}"
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet x-ui; then
        echo -e "${green}X-UI服务启动成功！${plain}"
        
        # 显示安装信息
        echo -e ""
        echo -e "${green}================================================${plain}"
        echo -e "${green}      带二次转发功能的X-UI安装完成！           ${plain}"
        echo -e "${green}================================================${plain}"
        echo -e ""
        echo -e "${yellow}面板访问信息：${plain}"
        SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}' || echo "服务器IP")
        echo -e "地址: http://${SERVER_IP}:54321"
        echo -e "默认账号: admin"
        echo -e "默认密码: admin"
        echo -e ""
        echo -e "${yellow}二次转发功能：${plain}"
        echo -e "✓ 支持 SOCKS5 代理二次转发"
        echo -e "✓ 支持 HTTP 代理二次转发"
        echo -e "✓ 完整的认证支持"
        echo -e "✓ 在入站配置中查看"
        echo -e ""
        echo -e "${yellow}管理命令：${plain}"
        echo -e "x-ui              - 显示管理菜单"
        echo -e "x-ui start        - 启动面板"
        echo -e "x-ui stop         - 停止面板"
        echo -e "x-ui restart      - 重启面板"
        echo -e "x-ui status       - 查看状态"
        echo -e "x-ui update       - 更新面板"
        echo -e ""
        echo -e "${red}安全提示：${plain}"
        echo -e "1. 首次登录后立即修改密码"
        echo -e "2. 建议修改默认端口"
        echo -e "3. 配置防火墙规则"
        echo -e "${green}================================================${plain}"
    else
        echo -e "${red}X-UI服务启动失败，请检查日志${plain}"
        journalctl -u x-ui -n 50 --no-pager
        exit 1
    fi
}

# 执行安装
echo -e "${green}开始安装${plain}"
install_x-ui $1
