# 使用 pixi 安装、配置和运行 CapsWriter-Offline

```bash
shps # 配置代理

## 下载并解压 CapsWriter-Offline 源码 及 对应 models
./naco_dev/github_downloader.sh -u nacodermer -r CapsWriter-Offline -v commit:8c1a36e -f source -t PROJROOT -z -e # 指定提交源码 到 PROJROOT 下
./naco_dev/github_downloader.sh -u HaujetZhao -r CapsWriter-Offline -v v1.0 -f models.zip -t MODELS -e          # v1.0 模型 到 data/models 下

# 下载 win10_64位 一键启动包 CapsWriter-Offline-Windows-64bit.zip
# ./naco_dev/github_downloader.sh -u HaujetZhao -r CapsWriter-Offline -v latest -f CapsWriter-Offline-Windows-64bit.zip

## pixi 工具准备
# curl -fsSL <https://pixi.sh/install.sh> | sh # 安装 pixi 工具

## 安装 pixi 环境
pixi install

## 使用 pixi 运行 -- 推荐
pixi run server # 服务端
pixi run client # 客户端 - 设备选择模式
export CAPS_WRITER_AUDIO_DEVICE=6 && pixi run client # 客户端 - 指定设备序号
export PULSE_SINK=bluez_output PULSE_SOURCE=bluez_input ALSA_CONFIG_PATH=/usr/share/alsa/alsa.conf.d/99-pipewire-default.conf && pixi run client # 客户端 - 使用蓝牙设备

## 使用 py文件 运行 -- 不推荐
eval "$(pixi shell-hook)" && python start_server.py # 服务端
eval "$(pixi shell-hook)" && python start_client.py # 客户端 - 设备选择模式
export CAPS_WRITER_AUDIO_DEVICE=6 && eval "$(pixi shell-hook)" && python start_client.py # 客户端 - 指定设备序号
export PULSE_SINK=bluez_output PULSE_SOURCE=bluez_input ALSA_CONFIG_PATH=/usr/share/alsa/alsa.conf.d/99-pipewire-default.conf && eval "$(pixi shell-hook)" && python start_client.py # 客户端 - 使用蓝牙设备
```
