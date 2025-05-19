#!/usr/bin/env bash
# pixi.bashrc - 用于 pixi 环境的自动配置
#
# 使用说明:
# 1. 将此文件放置在项目的 .vscode 目录中
# 2. 在 .bashrc 或 .zshrc 中添加以下内容:
#    if [ -f .vscode/pixi.bashrc ]; then
#        source .vscode/pixi.bashrc
#    fi
# 3. 当您打开终端时，函数 setup_pixi_environment 将被自动调用
# 4. 检查执行结果:
#    - 返回值: echo $? (0 表示成功, 1 表示失败)
#    - 环境变量: $PIXI_ENV_SETUP_SUCCESS (true 表示成功, false 表示失败)
#
# 注意: 此脚本需要 pixi 命令已安装在系统中

# 设置 pixi 环境的函数
setup_pixi_environment() {
    # 默认设置失败状态
    export PIXI_ENV_SETUP_SUCCESS=false

    # 检测当前目录是否存在 pixi.toml 文件
    if [ -f "pixi.toml" ]; then
        # 检查 pixi 命令是否可用
        if command -v pixi &>/dev/null; then
            echo "检测到 pixi 项目和命令，从 pixi.bashrc 配置环境..."

            # 激活 pixi shell hook
            eval "$(pixi shell-hook)"

            # 启用 pixi 命令补全
            eval "$(pixi completion --shell $(basename $SHELL))"

            echo "pixi 环境从 pixi.bashrc 配置完成"

            # 设置成功状态
            export PIXI_ENV_SETUP_SUCCESS=true
            return 0
        else
            echo "警告: 检测到 pixi.toml 文件，但 pixi 命令不可用"
            echo "请安装 pixi: https://pixi.sh/latest"
            return 1
        fi
    else
        # 没有找到 pixi.toml 文件，静默返回
        return 1
    fi
}

# 调用函数设置 pixi 环境
setup_pixi_environment
