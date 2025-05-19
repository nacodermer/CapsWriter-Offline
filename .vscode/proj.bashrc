# 首选 .vscode/pixi.bashrc 方案
# 此方案可作为附加方案，且与上述方案兼容，但需要手动切换

source ~/.bashrc

# 首先检查 pixi 命令是否可用
if command -v pixi &>/dev/null; then
    # 然后检查 PIXI_ENV_SETUP_SUCCESS 状态
    if [ "${PIXI_ENV_SETUP_SUCCESS:-false}" = "false" ]; then
        echo "从 proj.bashrc 配置 pixi 环境..."
        eval "$(pixi shell-hook)"
        eval "$(pixi completion --shell $(basename $SHELL))"
        echo "pixi 环境从 proj.bashrc 配置完成"
    else
        echo "pixi 环境已由 pixi.bashrc 配置，跳过 proj.bashrc 配置"
    fi
fi
