
echo "docker安装完毕 开始安装arl"



# 拉取镜像
docker pull crpi-hsrhdrw6lwo73b0g.cn-shanghai.personal.cr.aliyuncs.com/yunyanck/arlmod:latest

# 检查容器名是否已存在，若存在则停止并移除
if docker ps -a --format '{{.Names}}' | grep -q '^arlmod$'; then
    docker stop arlmod > /dev/null 2>&1
    docker rm arlmod > /dev/null 2>&1
fi

# 启动容器，并获取容器 ID
container_id=$(docker run -d --name arlmod crpi-hsrhdrw6lwo73b0g.cn-shanghai.personal.cr.aliyuncs.com/yunyanck/arlmod:latest)

# 检查容器是否启动成功
if [ -z "$container_id" ]; then
    echo "容器启动失败，请检查配置和镜像。"
    exit 1
fi

# 容器启动成功，继续执行后续操作
echo "容器启动成功，容器ID：$container_id"
# 在这里继续执行其他操作，比如等待容器运行，或进行容器内操作等

#!
echo "开始拉取镜像..."
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

