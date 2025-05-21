# 这是一个修改版的client_stream.py文件，添加了设备选择功能

from util.client_cosmic import console, Cosmic
import numpy as np
import sounddevice as sd
import asyncio
import sys
import time
import threading
import os


def record_callback(
    indata: np.ndarray, frames: int, time_info, status: sd.CallbackFlags
) -> None:
    if not Cosmic.on:
        return
    asyncio.run_coroutine_threadsafe(
        Cosmic.queue_in.put(
            {
                "type": "data",
                "time": time.time(),
                "data": indata.copy(),
            },
        ),
        Cosmic.loop,
    )


def stream_close(signum, frame):
    Cosmic.stream.close()


def stream_reopen():
    if not threading.main_thread().is_alive():
        return
    print("重启音频流")

    # 关闭旧流
    Cosmic.stream.close()

    # 重载 PortAudio，更新设备列表
    sd._terminate()
    sd._ffi.dlclose(sd._lib)
    sd._lib = sd._ffi.dlopen(sd._libname)
    sd._initialize()

    # 打开新流
    time.sleep(0.1)
    Cosmic.stream = stream_open()


def list_input_devices():
    """列出所有可用的输入设备"""
    devices = sd.query_devices()
    input_devices = []

    console.print("\n可用的输入设备:", style="bold green")
    for i, device in enumerate(devices):
        if device["max_input_channels"] > 0:
            input_devices.append((i, device))
            console.print(
                f"[{i}] {device['name']} (通道数: {device['max_input_channels']})"
            )

    return input_devices


def select_device():
    """让用户选择输入设备"""
    input_devices = list_input_devices()

    if not input_devices:
        console.print("未检测到输入设备!", style="bold red")
        return None

    # 检查环境变量以允许指定设备
    env_device = os.environ.get("CAPS_WRITER_AUDIO_DEVICE")
    if env_device is not None:
        try:
            device_id = int(env_device)
            for i, device in input_devices:
                if i == device_id:
                    console.print(
                        f"使用环境变量指定的设备 [{device_id}]: {device['name']}"
                    )
                    return device
        except (ValueError, IndexError):
            console.print(
                f"环境变量CAPS_WRITER_AUDIO_DEVICE={env_device}无效，将使用默认设备",
                style="yellow",
            )

    # 如果只有一个输入设备，直接使用它
    if len(input_devices) == 1:
        idx, device = input_devices[0]
        console.print(f"只有一个输入设备，将使用: [{idx}] {device['name']}")
        return device

    # 获取默认输入设备
    try:
        default_device = sd.query_devices(kind="input")
        console.print(f"默认设备: {default_device['name']}")
    except Exception as e:
        console.print(f"无法获取默认设备: {e}", style="red")
        default_device = None

    # 手动选择设备
    try:
        choice = input("\n请选择输入设备编号 [回车使用默认设备]: ")
        if choice.strip() == "":
            return default_device

        choice = int(choice)
        for i, device in input_devices:
            if i == choice:
                console.print(f"已选择设备 [{choice}]: {device['name']}")
                return device

        console.print(f"无效的设备编号: {choice}，将使用默认设备", style="yellow")
        return default_device
    except ValueError:
        console.print("输入无效，将使用默认设备", style="yellow")
        return default_device
    except Exception as e:
        console.print(f"发生错误: {e}，将使用默认设备", style="red")
        return default_device


def check_pipewire_devices():
    """检查PipeWire设备（如果可用）"""
    try:
        import subprocess

        result = subprocess.run(
            ["pw-cli", "list-objects"], capture_output=True, text=True, check=False
        )

        if result.returncode == 0 and "bluez_input" in result.stdout:
            console.print("\n检测到PipeWire蓝牙输入设备!", style="bold green")
            console.print(
                "注意: 如果在sounddevice设备列表中看不到蓝牙设备，需要配置PipeWire与ALSA的桥接"
            )
            console.print(
                "提示: 可以通过设置环境变量解决: export ALSA_CONFIG_PATH=/usr/share/alsa/alsa.conf.d/99-pipewire-default.conf"
            )
    except Exception:
        # 忽略错误
        pass


def stream_open():
    # 检查PipeWire设备
    check_pipewire_devices()

    # 显示所有可用输入设备并让用户选择
    selected_device = select_device()

    # 如果没有选择设备，尝试使用默认设备
    if selected_device is None:
        try:
            selected_device = sd.query_devices(kind="input")
        except Exception as e:
            console.print(f"无法获取默认输入设备: {e}", style="bright_red")
            console.print("没有找到麦克风设备", style="bright_red")
            input("按回车键退出")
            sys.exit()

    # 获取设备ID和通道数
    device_id = selected_device["index"] if "index" in selected_device else None
    channels = min(2, selected_device["max_input_channels"])

    console.print(
        f"使用音频设备：[italic]{selected_device['name']}，声道数：{channels}",
        style="green",
    )

    stream = sd.InputStream(
        samplerate=48000,
        blocksize=int(0.05 * 48000),  # 0.05 seconds
        device=device_id,  # 使用选择的设备ID
        dtype="float32",
        channels=channels,
        callback=record_callback,
        finished_callback=stream_reopen,
    )
    stream.start()

    return stream
