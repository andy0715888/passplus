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
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar git gcc g++ make -y
    else
        apt install wget curl tar git gcc g++ make -y
    fi
}

# 安装Go语言环境
install_go() {
    echo -e "${yellow}安装Go语言环境...${plain}"
    if ! command -v go &> /dev/null; then
        GO_VERSION="1.20"
        echo -e "${green}下载Go ${GO_VERSION}...${plain}"
        wget https://golang.org/dl/go${GO_VERSION}.linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载Go语言失败${plain}"
            exit 1
        fi
        tar -C /usr/local -xzf go${GO_VERSION}.linux-${arch}.tar.gz
        rm go${GO_VERSION}.linux-${arch}.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        echo 'export GOPATH=$HOME/go' >> /etc/profile
        source /etc/profile
        
        # 验证安装
        if command -v go &> /dev/null; then
            echo -e "${green}Go语言安装成功！版本: $(go version)${plain}"
        else
            echo -e "${red}Go语言安装失败${plain}"
            exit 1
        fi
    else
        echo -e "${green}Go语言已安装，版本: $(go version)${plain}"
    fi
}

# 克隆和编译源代码
install_from_source() {
    echo -e "${yellow}从源代码安装带二次转发功能的XUI...${plain}"
    
    # 切换到工作目录
    cd /usr/local/
    
    # 检查是否已存在x-ui目录
    if [[ -e /usr/local/x-ui/ ]]; then
        echo -e "${yellow}检测到已存在的x-ui目录，进行备份...${plain}"
        mv /usr/local/x-ui /usr/local/x-ui-backup-$(date +%Y%m%d%H%M%S)
    fi
    
    # 克隆你的仓库
    echo -e "${green}克隆你的仓库...${plain}"
    git clone https://github.com/andy0715888/passplus.git x-ui
    if [[ $? -ne 0 ]]; then
        echo -e "${red}克隆仓库失败${plain}"
        exit 1
    fi
    
    cd x-ui
    
    # 检查是否是x-ui目录结构
    if [[ ! -f "main.go" ]] && [[ ! -f "x-ui.go" ]]; then
        echo -e "${yellow}检测到可能是仓库根目录，查找x-ui相关文件...${plain}"
        # 假设x-ui代码在仓库的某个子目录中
        # 这里需要根据你的实际目录结构调整
        # 如果x-ui代码就在根目录，则继续
    fi
    
    # 安装Go依赖
    echo -e "${green}安装Go依赖...${plain}"
    go mod download
    if [[ $? -ne 0 ]]; then
        echo -e "${yellow}尝试初始化go模块...${plain}"
        go mod init x-ui
        go mod tidy
    fi
    
    # 编译
    echo -e "${green}编译XUI...${plain}"
    go build -o x-ui
    if [[ $? -ne 0 ]]; then
        echo -e "${red}编译失败，请检查Go环境和代码${plain}"
        exit 1
    fi
    
    # 检查必要的文件
    if [[ ! -f "x-ui" ]]; then
        echo -e "${red}编译成功但未找到x-ui可执行文件${plain}"
        exit 1
    fi
    
    # 复制二进制文件
    if [[ -f "bin/xray-linux-${arch}" ]]; then
        echo -e "${green}找到Xray二进制文件${plain}"
    else
        echo -e "${yellow}未找到预编译的Xray二进制文件，可能需要手动下载${plain}"
        # 这里可以添加下载xray的逻辑
    fi
    
    echo -e "${green}源代码编译完成！${plain}"
}

# 配置安装后的设置
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
        
        # 使用新编译的x-ui设置
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户密码设定完成${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}面板端口设定完成${plain}"
    else
        echo -e "${red}已取消,所有设置项均为默认设置,请及时修改${plain}"
        echo -e "${green}默认账号: admin${plain}"
        echo -e "${green}默认密码: admin${plain}"
        echo -e "${green}默认端口: 54321${plain}"
    fi
}

# 创建系统服务
create_service() {
    echo -e "${yellow}创建系统服务...${plain}"
    
    # 创建服务文件
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=X-UI Panel Service with Secondary Forward
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/x-ui
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    
    # 创建管理脚本
    cat > /usr/bin/x-ui << 'EOF'
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

# 管理菜单
show_menu() {
    echo -e "
  ${green}X-UI 面板管理脚本${plain}
  ${green}带二次转发功能版本${plain}
  ${green}0.${plain} 退出脚本
  ${green}1.${plain} 启动 X-UI
  ${green}2.${plain} 停止 X-UI
  ${green}3.${plain} 重启 X-UI
  ${green}4.${plain} 查看 X-UI 状态
  ${green}5.${plain} 查看 X-UI 日志
  ${green}6.${plain} 设置 X-UI 开机自启
  ${green}7.${plain} 取消 X-UI 开机自启
  ${green}8.${plain} 修改 X-UI 配置
  ${green}9.${plain} 更新 X-UI
  ${green}10.${plain} 卸载 X-UI
  ${green}11.${plain} 重置用户名密码
  ${green}12.${plain} 重置面板设置
  ${green}13.${plain} 查看面板信息
  ${green}14.${plain} 查看二次转发说明
 "
    echo && read -p "请输入选择 [0-14]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        systemctl start x-ui
        echo -e "${green}已启动 X-UI${plain}"
        ;;
    2)
        systemctl stop x-ui
        echo -e "${green}已停止 X-UI${plain}"
        ;;
    3)
        systemctl restart x-ui
        echo -e "${green}已重启 X-UI${plain}"
        ;;
    4)
        systemctl status x-ui -l
        ;;
    5)
        journalctl -u x-ui -f
        ;;
    6)
        systemctl enable x-ui
        echo -e "${green}已设置 X-UI 开机自启${plain}"
        ;;
    7)
        systemctl disable x-ui
        echo -e "${green}已取消 X-UI 开机自启${plain}"
        ;;
    8)
        /usr/local/x-ui/x-ui
        ;;
    9)
        update_x-ui
        ;;
    10)
        uninstall_x-ui
        ;;
    11)
        reset_user
        ;;
    12)
        reset_config
        ;;
    13)
        show_info
        ;;
    14)
        show_secondary_forward_info
        ;;
    *)
        echo -e "${red}请输入正确的数字 [0-14]${plain}"
        ;;
    esac
}

# 更新函数
update_x-ui() {
    echo -e "${yellow}开始更新 X-UI...${plain}"
    
    # 停止服务
    systemctl stop x-ui
    
    # 备份数据库
    if [[ -f "/etc/x-ui/x-ui.db" ]]; then
        BACKUP_FILE="/etc/x-ui/x-ui.db.backup.$(date +%Y%m%d%H%M%S)"
        cp /etc/x-ui/x-ui.db "$BACKUP_FILE"
        echo -e "${green}数据库已备份到: $BACKUP_FILE${plain}"
    fi
    
    # 更新代码
    cd /usr/local/x-ui
    git pull
    if [[ $? -ne 0 ]]; then
        echo -e "${red}代码更新失败${plain}"
        systemctl start x-ui
        return 1
    fi
    
    # 重新编译
    go build -o x-ui
    if [[ $? -ne 0 ]]; then
        echo -e "${red}编译失败${plain}"
        systemctl start x-ui
        return 1
    fi
    
    # 重启服务
    systemctl start x-ui
    
    if systemctl is-active --quiet x-ui; then
        echo -e "${green}X-UI 更新完成！${plain}"
        echo -e "${yellow}请访问面板查看二次转发功能是否正常${plain}"
    else
        echo -e "${red}服务启动失败${plain}"
        journalctl -u x-ui -n 50 --no-pager
    fi
}

# 卸载函数
uninstall_x-ui() {
    echo -e "${red}警告：这将卸载 X-UI 面板${plain}"
    read -p "确定要卸载 X-UI 吗？(y/n): " confirm
    if [[ x"${confirm}" == x"y" || x"${confirm}" == x"Y" ]]; then
        systemctl stop x-ui
        systemctl disable x-ui
        rm -f /etc/systemd/system/x-ui.service
        rm -f /usr/bin/x-ui
        rm -rf /usr/local/x-ui
        systemctl daemon-reload
        echo -e "${green}X-UI 已卸载${plain}"
    else
        echo -e "${green}已取消卸载${plain}"
    fi
}

# 重置用户
reset_user() {
    echo -e "${yellow}重置用户名密码${plain}"
    /usr/local/x-ui/x-ui
}

# 重置配置
reset_config() {
    echo -e "${yellow}重置面板设置${plain}"
    /usr/local/x-ui/x-ui
}

# 显示信息
show_info() {
    echo -e "${green}=== X-UI 面板信息 ===${plain}"
    echo -e "版本: 带二次转发功能版"
    echo -e "安装路径: /usr/local/x-ui"
    echo -e "数据库路径: /etc/x-ui/x-ui.db"
    echo -e "服务状态: $(systemctl is-active x-ui)"
    echo -e "开机自启: $(systemctl is-enabled x-ui)"
    echo ""
    echo -e "${green}管理命令:${plain}"
    echo -e "启动: systemctl start x-ui"
    echo -e "停止: systemctl stop x-ui"
    echo -e "重启: systemctl restart x-ui"
    echo -e "状态: systemctl status x-ui"
    echo -e "日志: journalctl -u x-ui -f"
}

# 显示二次转发说明
show_secondary_forward_info() {
    echo -e "${green}=== 二次转发功能说明 ===${plain}"
    echo -e "此版本X-UI新增了二次转发功能，支持："
    echo -e "1. SOCKS5 代理转发"
    echo -e "2. HTTP 代理转发"
    echo -e ""
    echo -e "${yellow}使用方法：${plain}"
    echo -e "1. 登录面板后，添加或编辑入站配置"
    echo -e "2. 在表单中找到'二次转发配置'部分"
    echo -e "3. 启用二次转发"
    echo -e "4. 选择协议（SOCKS/HTTP）"
    echo -e "5. 填写转发服务器信息："
    echo -e "   - 地址：转发服务器IP或域名"
    echo -e "   - 端口：转发服务器端口"
    echo -e "   - 用户名：如果需要认证"
    echo -e "   - 密码：如果需要认证"
    echo -e ""
    echo -e "${green}功能特点：${plain}"
    echo -e "✓ 支持多种协议二次转发"
    echo -e "✓ 完整的认证支持"
    echo -e "✓ 流量统计和限制"
    echo -e "✓ 用户友好的Web界面"
}

# 主逻辑
if [[ $# > 0 ]]; then
    case $1 in
    "start")
        systemctl start x-ui
        ;;
    "stop")
        systemctl stop x-ui
        ;;
    "restart")
        systemctl restart x-ui
        ;;
    "status")
        systemctl status x-ui
        ;;
    "enable")
        systemctl enable x-ui
        ;;
    "disable")
        systemctl disable x-ui
        ;;
    "log")
        journalctl -u x-ui -f
        ;;
    "v2-ui")
        /usr/local/x-ui/x-ui v2-ui
        ;;
    "update")
        update_x-ui
        ;;
    "install")
        echo -e "${green}请运行安装脚本进行安装${plain}"
        ;;
    "uninstall")
        uninstall_x-ui
        ;;
    *) 
        show_menu
        ;;
    esac
else
    show_menu
fi
EOF
    
    chmod +x /usr/bin/x-ui
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
}

# 安装完成提示
show_install_info() {
    echo -e ""
    echo -e "${green}================================================${plain}"
    echo -e "${green}      X-UI 带二次转发功能版安装完成！          ${plain}"
    echo -e "${green}================================================${plain}"
    echo -e ""
    echo -e "${yellow}面板访问信息：${plain}"
    echo -e "地址: http://你的服务器IP:54321"
    echo -e "用户名: admin (请及时修改)"
    echo -e "密码: admin (请及时修改)"
    echo -e ""
    echo -e "${yellow}二次转发功能：${plain}"
    echo -e "✓ 支持 SOCKS5 代理转发"
    echo -e "✓ 支持 HTTP 代理转发"
    echo -e "✓ 完整认证支持"
    echo -e "✓ 流量统计和限制"
    echo -e ""
    echo -e "${yellow}管理命令：${plain}"
    echo -e "x-ui              - 显示管理菜单"
    echo -e "x-ui start        - 启动面板"
    echo -e "x-ui stop         - 停止面板"
    echo -e "x-ui restart      - 重启面板"
    echo -e "x-ui status       - 查看状态"
    echo -e "x-ui update       - 更新面板"
    echo -e "x-ui uninstall    - 卸载面板"
    echo -e ""
    echo -e "${red}安全提示：${plain}"
    echo -e "1. 首次登录后立即修改密码"
    echo -e "2. 建议配置SSL/TLS加密"
    echo -e "3. 配置防火墙规则"
    echo -e "4. 定期备份数据库"
    echo -e "${green}================================================${plain}"
    
    # 显示服务器IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "你的服务器IP")
    echo -e "${green}访问地址: http://${SERVER_IP}:54321${plain}"
}

# 主安装函数
install_x-ui() {
    echo -e "${green}开始安装带二次转发功能的X-UI面板...${plain}"
    
    # 停止可能存在的旧服务
    systemctl stop x-ui 2>/dev/null
    
    # 安装基础依赖
    install_base
    
    # 安装Go语言
    install_go
    
    # 从源代码安装
    install_from_source
    
    # 配置安装后设置
    config_after_install
    
    # 创建系统服务
    create_service
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet x-ui; then
        echo -e "${green}X-UI服务启动成功！${plain}"
        show_install_info
    else
        echo -e "${red}X-UI服务启动失败，请检查日志${plain}"
        journalctl -u x-ui -n 50 --no-pager
        exit 1
    fi
}

# 执行安装
echo -e "${green}开始安装${plain}"
install_x-ui
