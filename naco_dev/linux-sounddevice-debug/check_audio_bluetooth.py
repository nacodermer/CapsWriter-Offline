#!/usr/bin/env python3
# coding: utf-8
# 检查系统音频和蓝牙设备

import sounddevice as sd
import subprocess
import sys
import os


def run_command(cmd):
    """运行系统命令并返回输出"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"命令 '{cmd}' 执行失败: {e}")
        print(f"错误输出: {e.stderr}")
        return None


def check_sounddevice_devices():
    """检查sounddevice可见的设备"""
    print("\n===== SoundDevice/PortAudio 可见设备 =====")
    try:
        devices = sd.query_devices()

        input_devices = []
        output_devices = []

        for i, device in enumerate(devices):
            device_type = []
            if device["max_input_channels"] > 0:
                device_type.append("输入")
                input_devices.append((i, device))
            if device["max_output_channels"] > 0:
                device_type.append("输出")
                output_devices.append((i, device))

            device_type_str = "、".join(device_type)
            print(f"设备 {i}: {device['name']} ({device_type_str})")
            print(f"  - 主机API: {device['hostapi']}")
            print(f"  - 输入通道数: {device['max_input_channels']}")
            print(f"  - 输出通道数: {device['max_output_channels']}")
            print(f"  - 默认采样率: {device['default_samplerate']}")
            if "bluetooth" in device["name"].lower():
                print("  - 蓝牙设备!")
            print()

        # 显示默认设备
        try:
            default_input = sd.query_devices(kind="input")
            print(
                f"默认输入设备: {default_input['name']} (ID: {default_input['index'] if 'index' in default_input else '未知'})"
            )
        except Exception as e:
            print(f"无法获取默认输入设备: {e}")

        try:
            default_output = sd.query_devices(kind="output")
            print(
                f"默认输出设备: {default_output['name']} (ID: {default_output['index'] if 'index' in default_output else '未知'})"
            )
        except Exception as e:
            print(f"无法获取默认输出设备: {e}")

        print("\n===== 音频主机API =====")
        apis = sd.query_hostapis()
        for i, api in enumerate(apis):
            print(f"API {i}: {api['name']}")
            print(f"  - 设备数量: {len(api['devices'])}")
            print(f"  - 默认输入设备: {api['default_input_device']}")
            print(f"  - 默认输出设备: {api['default_output_device']}")
            print()

        return True
    except Exception as e:
        print(f"检查sounddevice设备时出错: {e}")
        import traceback

        traceback.print_exc()
        return False


def check_pulseaudio():
    """检查PulseAudio设备和配置"""
    print("\n===== PulseAudio 状态 =====")

    # 检查PulseAudio是否运行
    pa_pid = run_command("pgrep -x pulseaudio")
    if pa_pid and pa_pid.strip():
        print(f"PulseAudio正在运行 (PID: {pa_pid.strip()})")
    else:
        print("PulseAudio似乎没有运行")
        # 检查是否安装了PulseAudio
        pulse_check = run_command("which pulseaudio")
        if pulse_check and pulse_check.strip():
            print(f"PulseAudio已安装: {pulse_check.strip()}")
        else:
            print("PulseAudio可能未安装")
            return

    print("\n--- PulseAudio 输入设备 ---")
    sources = run_command(
        "pactl list sources | grep -E 'Source|Name|Description|device.product.name|bluetooth'"
    )
    if sources:
        print(sources)
    else:
        print("无法获取PulseAudio输入设备信息")

    print("\n--- PulseAudio 输出设备 ---")
    sinks = run_command(
        "pactl list sinks | grep -E 'Sink|Name|Description|device.product.name|bluetooth'"
    )
    if sinks:
        print(sinks)
    else:
        print("无法获取PulseAudio输出设备信息")

    print("\n--- PulseAudio 蓝牙模块 ---")
    modules = run_command("pactl list modules | grep -A 5 -B 5 bluetooth")
    if modules:
        print(modules)
    else:
        print("未找到PulseAudio蓝牙模块信息")


def check_alsa_devices():
    """检查ALSA设备"""
    print("\n===== ALSA 设备 =====")

    # 列出所有ALSA设备
    alsa_devices = run_command("aplay -l")
    if alsa_devices:
        print("--- 播放设备 (aplay -l) ---")
        print(alsa_devices)
    else:
        print("无法获取ALSA播放设备信息")

    # 列出所有ALSA捕获设备
    alsa_capture = run_command("arecord -l")
    if alsa_capture:
        print("\n--- 捕获设备 (arecord -l) ---")
        print(alsa_capture)
    else:
        print("无法获取ALSA捕获设备信息")


def check_bluetooth_devices():
    """检查系统蓝牙设备"""
    print("\n===== 蓝牙设备 =====")

    # 检查蓝牙服务是否运行
    bt_status = run_command("systemctl status bluetooth | grep Active")
    if bt_status:
        print(f"蓝牙服务状态: {bt_status.strip()}")
    else:
        print("无法获取蓝牙服务状态")

    # 检查配对的蓝牙设备
    paired_devices = run_command("bluetoothctl paired-devices")
    if paired_devices:
        print("\n配对的蓝牙设备:")
        print(paired_devices)
    else:
        print("无法获取配对的蓝牙设备或没有配对设备")

    # 检查已连接的蓝牙设备
    connected_devices = run_command("bluetoothctl devices Connected")
    if connected_devices and connected_devices.strip():
        print("\n已连接的蓝牙设备:")
        print(connected_devices)
    else:
        print("\n没有已连接的蓝牙设备或无法获取信息")

    # 检查是否加载了蓝牙音频相关模块
    bt_modules = run_command("lsmod | grep -E 'bluetooth|snd.*bt'")
    if bt_modules:
        print("\n已加载的蓝牙相关内核模块:")
        print(bt_modules)
    else:
        print("\n未找到已加载的蓝牙音频相关内核模块")

    # 检查pulse的蓝牙模块
    check_pulse_bt = run_command("pactl list modules short | grep -i bluetooth")
    if check_pulse_bt:
        print("\nPulseAudio蓝牙模块:")
        print(check_pulse_bt)
    else:
        print("\nPulseAudio中没有找到蓝牙模块")


def check_pipewire():
    """检查是否使用PipeWire"""
    print("\n===== PipeWire 状态 =====")

    # 检查PipeWire是否运行
    pw_pid = run_command("pgrep -x pipewire")
    if pw_pid and pw_pid.strip():
        print(f"PipeWire正在运行 (PID: {pw_pid.strip()})")

        # 检查PipeWire设备
        pw_devices = run_command(
            "pw-cli list-objects | grep -E 'node.name|media.class|device.product.name|bluetooth'"
        )
        if pw_devices:
            print("\nPipeWire设备:")
            print(pw_devices)
        else:
            print("\n无法获取PipeWire设备信息")
    else:
        print("PipeWire似乎没有运行")
        # 检查是否安装了PipeWire
        pw_check = run_command("which pipewire")
        if pw_check and pw_check.strip():
            print(f"PipeWire已安装: {pw_check.strip()}")
        else:
            print("PipeWire可能未安装")


def main():
    """主函数"""
    print("========== Linux音频与蓝牙设备诊断 ==========")
    print(f"Python版本: {sys.version}")
    print(f"sounddevice版本: {sd.__version__}")
    print(f"PortAudio版本: {sd.get_portaudio_version()}")
    print(f"操作系统: {os.uname().sysname} {os.uname().release}")

    check_sounddevice_devices()
    check_alsa_devices()
    check_pulseaudio()
    check_pipewire()
    check_bluetooth_devices()

    print("\n=== 可能的问题和解决建议 ===")
    print("1. 如果蓝牙设备已连接但未显示在音频设备中，可能是配置文件问题")
    print("   - 确认设备处于HSP/HFP模式而非A2DP模式")
    print("   - 尝试在PulseAudio/PipeWire中将蓝牙设备设置为默认输入设备")
    print("2. 如果ALSA无法看到蓝牙设备:")
    print("   - PulseAudio可能未正确桥接蓝牙设备到ALSA")
    print("   - 尝试加载必要的PulseAudio蓝牙模块(module-bluetooth-discover等)")
    print("3. 检查~/.asoundrc文件是否有特殊配置影响蓝牙设备的识别")


if __name__ == "__main__":
    main()
