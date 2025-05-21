#!/bin/bash

# 错误处理函数
handle_error() {
    echo "错误: $1"
    exit 1
}

# 检查pixi是否已安装
if ! command -v pixi &>/dev/null; then
    handle_error "pixi 未安装，请先安装 pixi: https://github.com/prefix-dev/pixi"
fi

# 检查是否安装了tmux
if ! command -v tmux &>/dev/null; then
    echo "tmux 未安装，正在安装..."
    sudo apt-get update || handle_error "更新软件源失败"
    sudo apt-get install tmux -y || handle_error "安装tmux失败"
else
    echo "tmux 已安装"
fi

# 使用tmux实现命令行的左右分屏 (左边是 server, 右边是 client)

# 检查是否存在名为capswriter的会话
if tmux has-session -t capswriter 2>/dev/null; then
    echo "关闭现有的capswriter会话..."
    tmux kill-session -t capswriter
fi

# 启动 tmux 会话，并创建左右分屏
tmux new-session -d -s capswriter || handle_error "创建tmux会话失败"
tmux split-window -h

# 在左侧面板中打来 server
tmux send-keys -t capswriter:0.0 'pixi run server' Enter

# 等待服务器启动
echo "正在启动服务器，请稍候..."
sleep 2

# 切换到右侧面板
tmux select-pane -t capswriter:0.1

# 在右侧面板中打开 client
tmux send-keys -t capswriter:0.1 'pixi run client' Enter

# 进入 tmux 会话
tmux attach-session -t capswriter
