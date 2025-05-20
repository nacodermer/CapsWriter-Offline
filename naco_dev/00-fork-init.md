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

## 客户端 系统依赖, for debian based linux os, ubuntu 24.04

```bash
sudo apt install pipewire-alsa libportaudio2 ffmpeg xclip
```

## proj feature dependencies environment and task

```bash
# in proj dir cotools
# https://pixi.sh/latest/workspace/multi_environment
# https://pixi.sh/latest/tutorials/multi_environment
# https://pixi.sh/latest/workspace/advanced_tasks

# add dependencies for feature
pixi add --feature py38 python=3.8
pixi add --feature common --pypi rich websockets numpy
pixi add --feature server --pypi typeguard==2.13.3 sherpa_onnx==1.8.11 funasr_onnx==0.2.5 kaldi-native-fbank==1.17 jieba
pixi add --feature client --pypi pynput pyclip sounddevice pypinyin watchdog typer srt colorama
pixi add --feature dev ruff watchfiles
pixi add --feature test pytest

# add workspace environment with feature; --force is used to overwrite the environment
pixi workspace environment add server --feature py38 --feature common --feature server --solve-group sg_prod --force
pixi workspace environment add client --feature py38 --feature common --feature client --solve-group sg_prod --force
pixi workspace environment add dev --feature py38 --feature common --feature server --feature client --feature dev --solve-group sg_prod --force
pixi workspace environment add test --feature py38 --feature common --feature server --feature client --feature test --solve-group sg_prod --force
pixi workspace environment add default --feature py38 --feature common --feature server --feature client --feature dev --feature test --solve-group sg_prod --force

# echo "prod dev test default" | xargs -n 1 pixi list -x -e

# add tasks
pixi task add --feature dev fmt -- "ruff format ."
pixi task add --feature dev lint -- "ruff check ."
pixi task add --feature dev linf -- "ruff check --fix ."
pixi task add --feature dev style "pwd" --depends-on linf fmt # like 'pixi task alias' but with --feature
pixi task add --feature server --platform linux-64 server -- "python start_server.py"
pixi task add --feature client --platform linux-64 client -- "python start_client.py"
```

## install dependencies and environment

```bash
# in proj dir cotools
rm -rf .pixi/envs
rm pixi.lock
pixi install # or, pixi run (https://pixi.sh/latest/workspace/lockfile/#how-to-use-a-lock-file)
```

## use

```bash
pixi run style
```
