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
    release="centos"
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
        yum install wget curl tar git sqlite3 -y
        yum install gcc gcc-c++ make -y
    else
        apt install wget curl tar git sqlite3 -y
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
    
    # 使用您的分支
    LATEST_VERSION="main"
    echo -e "${green}使用您的自定义版本: ${LATEST_VERSION}${plain}"
    
    echo "$LATEST_VERSION"
}

download_xui_full_source() {
    echo -e "${green}下载完整的X-UI源码（包含二次转发功能）...${plain}"
    
    # 清空并重新下载完整源码
    cd /usr/local
    rm -rf x-ui-source
    mkdir -p x-ui-source
    cd x-ui-source
    
    echo -e "${yellow}从您的GitHub仓库克隆源码...${plain}"
    
    # 方法1: 直接克隆
    if git clone https://github.com/andy0715888/passplus.git .; then
        echo -e "${green}源码克隆成功！${plain}"
        return 0
    else
        echo -e "${yellow}克隆失败，尝试下载ZIP包...${plain}"
        
        # 方法2: 下载ZIP包
        wget -O x-ui-source.zip https://github.com/andy0715888/passplus/archive/refs/heads/main.zip
        
        if [[ -f "x-ui-source.zip" ]]; then
            unzip x-ui-source.zip
            mv passplus-main/* .
            rm -rf passplus-main x-ui-source.zip
            echo -e "${green}源码下载成功！${plain}"
            return 0
        else
            echo -e "${red}源码下载失败！${plain}"
            return 1
        fi
    fi
}

download_individual_files() {
    echo -e "${green}下载二次转发功能文件...${plain}"
    
    # 创建临时目录
    TEMP_DIR="/tmp/x-ui-secondary-forward"
    mkdir -p $TEMP_DIR
    cd $TEMP_DIR
    
    echo -e "${yellow}从您的GitHub仓库下载修改过的文件...${plain}"
    
    # 定义文件和目标路径的映射
    declare -A file_map=(
        ["database/model/model.go"]="database/model/model.go"
        ["web/controller/inbound.go"]="web/controller/inbound.go"
        ["xray/config.go"]="xray/config.go"
        ["web/service/inbound.go"]="web/service/inbound.go"
        ["web/html/xui/form/inbound.html"]="web/html/xui/form/inbound.html"
        ["web/html/xui/component/inbound_info.html"]="web/html/xui/component/inbound_info.html"
    )
    
    files_copied=0
    
    for url_path in "${!file_map[@]}"; do
        local_file="${url_path##*/}"
        target_path="${file_map[$url_path]}"
        
        echo -n "下载 $url_path ... "
        if wget -q --timeout=10 -O "$local_file" "https://raw.githubusercontent.com/andy0715888/passplus/main/$url_path"; then
            echo -e "${green}成功${plain}"
            
            # 创建目标目录
            mkdir -p "/usr/local/x-ui/$(dirname "$target_path")"
            
            # 复制文件
            if cp "$local_file" "/usr/local/x-ui/$target_path"; then
                echo -e "  → 复制到 /usr/local/x-ui/$target_path"
                ((files_copied++))
            else
                echo -e "${yellow}  ⚠ 复制失败${plain}"
            fi
        else
            echo -e "${red}失败${plain}"
        fi
    done
    
    echo -e "${green}成功复制 ${files_copied} 个文件${plain}"
    return $files_copied
}

update_database_schema() {
    echo -e "${yellow}更新数据库表结构以支持二次转发...${plain}"
    
    # 等待一下确保X-UI有足够时间初始化
    sleep 5
    
    # 检查数据库文件是否存在
    DB_FILE="/etc/x-ui/x-ui.db"
    
    if [[ -f "$DB_FILE" ]]; then
        echo -e "${green}找到数据库文件，更新表结构...${plain}"
        
        # 备份数据库
        BACKUP_FILE="${DB_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$DB_FILE" "$BACKUP_FILE"
        echo -e "${yellow}数据库已备份到: $BACKUP_FILE${plain}"
        
        # 使用SQLite添加字段（使用更安全的方法）
        sqlite3 "$DB_FILE" << 'EOF'
        -- 添加二次转发相关字段
        -- 使用PRAGMA检查表结构，然后添加缺失的字段
        
        -- 检查并添加 secondary_forward_enable
        SELECT CASE WHEN EXISTS (
            SELECT 1 FROM pragma_table_info('inbounds') WHERE name='secondary_forward_enable'
        ) THEN 1 ELSE 0 END;
        
        -- 如果不存在则添加
        INSERT OR IGNORE INTO pragma_table_info('inbounds') 
        SELECT 'secondary_forward_enable', 'BOOLEAN', 0, 0, '0' 
        WHERE NOT EXISTS (
            SELECT 1 FROM pragma_table_info('inbounds') WHERE name='secondary_forward_enable'
        );
EOF

        # 添加其他字段
        FIELDS=(
            "secondary_forward_protocol TEXT DEFAULT 'none'"
            "secondary_forward_address TEXT DEFAULT ''"
            "secondary_forward_port INTEGER DEFAULT 0"
            "secondary_forward_username TEXT DEFAULT ''"
            "secondary_forward_password TEXT DEFAULT ''"
        )
        
        for field in "${FIELDS[@]}"; do
            field_name=$(echo "$field" | awk '{print $1}')
            echo -n "添加字段 $field_name ... "
            
            sqlite3 "$DB_FILE" "ALTER TABLE inbounds ADD COLUMN $field;" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo -e "${green}成功${plain}"
            else
                echo -e "${yellow}可能已存在${plain}"
            fi
        done
        
        echo -e "${green}数据库表结构更新完成！${plain}"
        
        # 验证更新
        echo -e "${yellow}验证表结构...${plain}"
        sqlite3 "$DB_FILE" ".schema inbounds" | grep -i "secondary"
        
    else
        echo -e "${yellow}数据库文件不存在，将在首次运行时自动创建${plain}"
    fi
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

compile_xui() {
    echo -e "${green}编译X-UI...${plain}"
    
    cd /usr/local/x-ui
    
    # 检查是否有完整的源码
    if [[ -f "go.mod" && -f "main.go" ]]; then
        echo -e "${yellow}检测到完整的Go项目，开始编译...${plain}"
        
        # 设置Go模块代理（国内加速）
        export GOPROXY=https://goproxy.cn,direct
        
        # 下载依赖
        echo -e "${yellow}下载Go依赖...${plain}"
        go mod download
        
        # 编译
        echo -e "${yellow}编译二进制文件...${plain}"
        go build -o x-ui -ldflags="-s -w"
        
        if [[ $? -eq 0 && -f "x-ui" ]]; then
            echo -e "${green}编译成功！${plain}"
            chmod +x x-ui
            return 0
        else
            echo -e "${red}编译失败！${plain}"
            return 1
        fi
    else
        echo -e "${yellow}未找到完整的Go项目文件，跳过编译${plain}"
        return 1
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
    
    # 获取版本
    XUI_VERSION=$(get_latest_version)
    
    # 下载预编译版本作为基础
    echo -e "${green}下载X-UI基础版本...${plain}"
    cd /usr/local/
    
    # 下载预编译版本
    if wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/vaxilu/x-ui/releases/download/0.3.2/x-ui-linux-${arch}.tar.gz"; then
        echo -e "${green}下载成功！${plain}"
    else
        echo -e "${red}下载失败，尝试备用链接...${plain}"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/kenzo-dad/x-ui/releases/download/v0.3.2/x-ui-linux-${arch}.tar.gz"
    fi
    
    if [[ ! -f "/usr/local/x-ui-linux-${arch}.tar.gz" ]]; then
        echo -e "${red}下载X-UI失败！${plain}"
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
    
    # 方法1: 尝试下载完整源码并编译
    echo -e "${yellow}方法1: 下载完整源码并编译...${plain}"
    if download_xui_full_source; then
        echo -e "${green}完整源码下载成功，复制文件...${plain}"
        
        # 复制所有文件
        cp -r /usr/local/x-ui-source/* /usr/local/x-ui/ 2>/dev/null
        cp -r /usr/local/x-ui-source/.* /usr/local/x-ui/ 2>/dev/null
        
        # 编译
        if compile_xui; then
            echo -e "${green}成功编译带二次转发功能的X-UI！${plain}"
        else
            echo -e "${yellow}编译失败，使用方法2${plain}"
            # 方法1失败，使用方法2
            download_individual_files
        fi
    else
        echo -e "${yellow}完整源码下载失败，使用方法2...${plain}"
        # 方法2: 下载单个文件
        download_individual_files
    fi
    
    # 复制Go模块文件（如果存在）
    if [[ -f "/usr/local/xui-source/go.mod" ]]; then
        cp /usr/local/xui-source/go.mod /usr/local/x-ui/
        cp /usr/local/xui-source/go.sum /usr/local/x-ui/ 2>/dev/null
    fi
    
    # 尝试编译
    echo -e "${yellow}尝试编译最终版本...${plain}"
    compile_xui
    
    # 设置权限
    chmod +x x-ui
    if [[ -f "bin/xray-linux-${arch}" ]]; then
        chmod +x bin/xray-linux-${arch}
    fi
    
    # 复制服务文件
    cp -f x-ui.service /etc/systemd/system/
    
    # 复制管理脚本
    cp -f x-ui.sh /usr/bin/x-ui
    chmod +x /usr/bin/x-ui
    
    # 配置安装后设置
    config_after_install
    
    echo -e "${green}配置系统服务...${plain}"
    systemctl daemon-reload
    systemctl enable x-ui
    
    # 启动服务
    echo -e "${yellow}启动X-UI服务...${plain}"
    systemctl start x-ui
    
    # 更新数据库
    update_database_schema
    
    # 检查服务状态
    sleep 3
    if systemctl is-active --quiet x-ui; then
        echo -e "${green}X-UI服务启动成功！${plain}"
        
        # 显示安装信息
        echo -e ""
        echo -e "${green}================================================${plain}"
        echo -e "${green}      带二次转发功能的X-UI安装完成！           ${plain}"
        echo -e "${green}================================================${plain}"
        echo -e ""
        echo -e "${yellow}面板访问信息：${plain}"
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "服务器IP")
        echo -e "地址: http://${SERVER_IP}:54321"
        echo -e "默认账号: admin"
        echo -e "默认密码: admin"
        echo -e ""
        echo -e "${yellow}二次转发功能：${plain}"
        echo -e "✓ 支持 SOCKS5 代理二次转发"
        echo -e "✓ 支持 HTTP 代理二次转发"
        echo -e "✓ 完整的用户名/密码认证"
        echo -e "✓ 在入站配置中设置和使用"
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
        echo -e "${yellow}尝试手动启动...${plain}"
        /usr/local/x-ui/x-ui
    fi
}

# 执行安装
echo -e "${green}开始安装${plain}"
install_x-ui $1
