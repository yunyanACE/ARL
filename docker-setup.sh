#!/bin/bash

# 检查并安装 git 的函数
check_and_install_git() {
    echo "正在检测 git 是否安装..."
    if ! command -v git &> /dev/null; then
        echo "git 未安装，正在安装 git..."
        if [[ -f /etc/debian_version ]]; then
            # Debian/Ubuntu 系
            sudo apt-get update
            sudo apt-get install -y git
        elif [[ -f /etc/redhat-release ]]; then
            # CentOS/RHEL 系
            sudo yum install -y git
        elif [[ -f /etc/fedora-release ]]; then
            # Fedora 系
            sudo dnf install -y git
        elif [[ -f /etc/arch-release ]]; then
            # Arch Linux 系
            sudo pacman -S --noconfirm git
        else
            echo "不支持的 Linux 发行版，请手动安装 git。"
            exit 1
        fi
    else
        echo "git 已安装。"
    fi
}

# 国内检测必要工具是否安装
check_and_install_docker_tools() {
    tools=("wget" "tar" "iptables")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            echo "$tool 未安装，正在安装 $tool..."
            if [[ -f /etc/debian_version ]]; then
                sudo apt-get update
                sudo apt-get install -y $tool
            elif [[ -f /etc/redhat-release ]]; then
                sudo yum install -y $tool
            elif [[ -f /etc/fedora-release ]]; then
                sudo dnf install -y $tool
            elif [[ -f /etc/arch-release ]]; then
                sudo pacman -S --noconfirm $tool
            else
                echo "不支持的 Linux 发行版，请手动安装 $tool。"
                exit 1
            fi
        else
            echo "$tool 已安装。"
        fi
    done
}

# 检测 Docker 运行状态
check_run_docker() {
    status=$(systemctl is-active docker)
    if [ "$status" = "active" ]; then
        echo "Docker 运行正常"
    elif [ "$status" = "inactive" ] || [ "$status" = "unknown" ]; then
        echo "Docker 服务未运行，正在尝试启动"
        run=$(systemctl start docker)
        if [ "$?" = "0" ]; then
            echo "Docker 启动成功"
        else
            echo "Docker 启动失败"
            exit 1
        fi
    else
        echo "无法确定 Docker 状态"
        exit 1
    fi
}

# 国内 Docker 镜像加速
docker_mirrors_CN() {
    mkdir -p /etc/docker
    echo '{"registry-mirrors": ["https://hub.msqh.net"]}' > /etc/docker/daemon.json
    systemctl restart docker
    check_run_docker
}

# 国内检测 Docker 安装
check_install_docker_CN() {
    MAX_ATTEMPTS=3
    attempt=0
    success=false
    cpu_arch=$(uname -m)
    save_path="/opt/docker_tgz"
    mkdir -p $save_path
    docker_ver="docker-27.1.1.tgz"

    case $cpu_arch in
        "arm64" | "aarch64")
            url="https://raw.gitcode.com/msmoshang/arl_files/blobs/362611e3d3d50ddea6c1c179e76364dcb8d317d5/$docker_ver"
            ;;
        "x86_64")
            url="https://raw.gitcode.com/msmoshang/arl_files/blobs/2062dee5a2b85f820fc7e56a8e238525a3b06ea3/$docker_ver"
            ;;
        *)
            echo "不支持的 CPU 架构: $cpu_arch"
            exit 1
            ;;
    esac

    check_and_install_docker_tools

    if ! command -v docker &> /dev/null; then
        while [ $attempt -lt $MAX_ATTEMPTS ]; do
            attempt=$((attempt + 1))
            echo "Docker 未安装，正在进行安装..."
            wget -P "$save_path" "$url"
            if [ $? -eq 0 ]; then
                success=true
                break
            fi
            echo "Docker 安装失败，正在尝试重新下载 (尝试次数: $attempt)"
        done

        if $success; then
            tar -xzf $save_path/$docker_ver -C $save_path
            \cp $save_path/docker/* /usr/bin/
            rm -rf $save_path
            echo "Docker 安装成功，版本为：$(docker --version)"

            cat > /usr/lib/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP 
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl restart docker
            check_run_docker
            systemctl enable docker
        else
            echo "Docker 安装失败，请尝试手动安装"
            exit 1
        fi
    else
        echo "Docker 已安装，安装版本为：$(docker --version)"
        systemctl restart docker
        check_run_docker
    fi
}

# 执行安装流程
check_and_install_git
check_install_docker_CN
docker_mirrors_CN

#!/bin/bash

echo "docker安装完毕 开始安装arl"


docker pull crpi-hsrhdrw6lwo73b0g.cn-shanghai.personal.cr.aliyuncs.com/yunyanck/arl:latest

# 检查容器名是否已存在，若存在则停止并移除
if docker ps -a --format '{{.Names}}' | grep -q '^arl$'; then
    echo "容器名 arl 已存在，正在停止并移除该容器..."
    docker stop arl > /dev/null 2>&1
    docker rm arl > /dev/null 2>&1
fi

# 启动容器
container_id=$(docker run --privileged -it -d -p 5003:5003 --name=arl --restart=always -v /sys/fs/cgroup:/sys/fs/cgroup crpi-hsrhdrw6lwo73b0g.cn-shanghai.personal.cr.aliyuncs.com/yunyanck/arl:latest /usr/sbin/init)

if [ -z "$container_id" ]; then
    echo "容器启动失败，请检查配置和镜像。"
    exit 1
fi

# 在执行 rabbitmqctl 命令时设置环境变量并隐藏输出
execute_rabbitmq_command() {
    docker exec -it arl bash -c "export ELIXIR_ERL_OPTIONS='+fnu'; $1" > /dev/null 2>&1
}

# 等待容器启动稳定
echo "等待容器启动..."
sleep 5

# 启动 RabbitMQ
execute_rabbitmq_command "rabbitmqctl start_app"

echo "RabbitMQ 启动成功"
sleep 1

# 执行后续 RabbitMQ 配置命令
execute_rabbitmq_command "rabbitmqctl add_user arl arlpassword"
execute_rabbitmq_command "rabbitmqctl add_vhost arlv2host"
execute_rabbitmq_command "rabbitmqctl set_user_tags arl arltag"
execute_rabbitmq_command "rabbitmqctl set_permissions -p arlv2host arl \".*\" \".*\" \".*\""

# 重启服务
docker exec -it arl bash -c "cd /etc/systemd/system && systemctl restart arl*" > /dev/null 2>&1

# IP 查询
ipinfo() {
    ip=$(curl -s https://ipinfo.io/ip)
    
    echo -e "\033[1;32m ARL 访问链接为 \033[0m \033[1;42;30m https://$ip:5003 \033[0m"
    echo "初始密码 admin/arlpass"
}

ipinfo

