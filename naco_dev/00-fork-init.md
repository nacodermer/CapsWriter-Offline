# fork and init

## fork

```text
此项目从
https://github.com/HaujetZhao/CapsWriter-Offline/commit/a072f5312031e31706b294e9242d516fb8979fc6
fork 至
https://github.com/nacodermer/CapsWriter-Offline/commit/a072f5312031e31706b294e9242d516fb8979fc6

自此 commit 开始 进行深度 更改 定制 开发
```

## clone

```bash
git clone https://github.com/nacodermer/CapsWriter-Offline
cd CapsWriter-Offline
git checkout -b naco-00
```

## pixi env init

```bash
# curl -fsSL https://pixi.sh/install.sh | sh # 安装 pixi 工具
pixi init .         # 将当前目录初始化为pixi项目
cat << EOF >> .gitignore

# projet ignore
__pycache__
tmp
data
EOF
git add .
git commit -m "pixi env init"
```

## vscode 配置 for pixi

```text
所有文件 均位于 .vscode 内
```
