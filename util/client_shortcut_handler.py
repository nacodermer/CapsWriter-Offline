from pynput import keyboard
from util.client_cosmic import Cosmic
from config import ClientConfig as Config

import time
import asyncio
from threading import Event
from concurrent.futures import ThreadPoolExecutor
from util.client_send_audio import send_audio
from util.my_status import Status


task = asyncio.Future()
status = Status("开始录音", spinner="point")
pool = ThreadPoolExecutor()
pressed = False
released = True
event = Event()
listener = None
key_controller = keyboard.Controller()


def get_pynput_key(key_name):
    """将配置中的按键名称转换为 pynput 的按键对象"""
    key_name = key_name.lower()

    # 特殊按键映射
    special_keys = {
        "caps lock": keyboard.Key.caps_lock,
        "shift": keyboard.Key.shift,
        "ctrl": keyboard.Key.ctrl,
        "alt": keyboard.Key.alt,
        "space": keyboard.Key.space,
        "tab": keyboard.Key.tab,
        "esc": keyboard.Key.esc,
        "enter": keyboard.Key.enter,
    }

    if key_name in special_keys:
        return special_keys[key_name]
    elif len(key_name) == 1:
        return key_name
    return None


def is_target_key(key, target_key):
    """检查按键是否是目标快捷键"""
    if isinstance(target_key, keyboard.Key):
        return key == target_key
    elif hasattr(key, "char") and key.char:
        return key.char.lower() == target_key
    return False


def launch_task():
    global task

    # 记录开始时间
    t1 = time.time()

    # 将开始标志放入队列
    asyncio.run_coroutine_threadsafe(
        Cosmic.queue_in.put({"type": "begin", "time": t1, "data": None}), Cosmic.loop
    )

    # 通知录音线程可以向队列放数据了
    Cosmic.on = t1

    # 打印动画：正在录音
    status.start()

    # 启动识别任务
    task = asyncio.run_coroutine_threadsafe(
        send_audio(),
        Cosmic.loop,
    )


def cancel_task():
    # 通知停止录音，关掉滚动条
    Cosmic.on = False
    status.stop()

    # 取消协程任务
    task.cancel()


def finish_task():
    global task

    # 通知停止录音，关掉滚动条
    Cosmic.on = False
    status.stop()

    # 通知结束任务
    asyncio.run_coroutine_threadsafe(
        Cosmic.queue_in.put(
            {"type": "finish", "time": time.time(), "data": None},
        ),
        Cosmic.loop,
    )


def send_key(key_name):
    """模拟发送按键"""
    target_key = get_pynput_key(key_name)
    if target_key:
        if isinstance(target_key, keyboard.Key):
            key_controller.tap(target_key)
        else:
            key_controller.tap(target_key)


# =================单击模式======================


def count_down(e: Event):
    """按下后，开始倒数"""
    time.sleep(Config.threshold)
    e.set()


def manage_task(e: Event):
    """
    通过检测 e 是否在 threshold 时间内被触发，判断是单击，还是长按
    进行下一步的动作
    """

    # 记录是否有任务
    on = Cosmic.on

    # 先运行任务
    if not on:
        # 延迟开始录音提示，留足准备时间
        # 延迟时间等于阈值时间，确保用户看到提示时，前面的录音已经处理
        time.sleep(Config.threshold)
        launch_task()

    # 及时松开按键了，是单击
    if e.wait(timeout=Config.threshold * 0.8):
        # 如果有任务在运行，就结束任务
        if Cosmic.on and on:
            # 延迟片刻，让音频采集到结尾内容
            time.sleep(Config.end_capture_delay)
            finish_task()

    # 没有及时松开按键，是长按
    else:
        # 就取消本栈启动的任务
        if not on:
            cancel_task()

        # 长按，发送按键
        send_key(Config.shortcut)


# ======================长按模式==================================


# ======================pynput 按键处理==========================


def on_press(key):
    global pressed, released, event
    target_key = get_pynput_key(Config.shortcut)

    if is_target_key(key, target_key):
        if Config.hold_mode:
            # 长按模式
            if not Cosmic.on:
                # 延迟开始录音提示，留足准备时间
                # 延迟时间等于阈值时间，确保用户看到提示时，前面的录音已经处理
                time.sleep(Config.threshold)
                # 记录开始时间
                launch_task()
        else:
            # 单击模式
            if released:
                pressed, released = True, False
                event = Event()
                pool.submit(count_down, event)
                pool.submit(manage_task, event)


def on_release(key):
    global pressed, released, event
    target_key = get_pynput_key(Config.shortcut)

    if is_target_key(key, target_key):
        if Config.hold_mode:
            # 长按模式
            if Cosmic.on:
                # 记录持续时间，并标识录音线程停止向队列放数据
                duration = time.time() - Cosmic.on

                # 取消或停止任务
                if duration < Config.threshold:
                    cancel_task()
                else:
                    # 延迟片刻，让音频采集到结尾内容
                    time.sleep(Config.end_capture_delay)
                    finish_task()

                    # 松开快捷键后，再按一次，恢复 CapsLock 或 Shift 等按键的状态
                    if Config.restore_key:
                        time.sleep(0.01)
                        send_key(Config.shortcut)
        else:
            # 单击模式
            if pressed:
                pressed, released = False, True
                event.set()


def bond_shortcut():
    """使用 pynput 绑定快捷键监听"""
    global listener

    # 创建并启动监听器
    listener = keyboard.Listener(
        on_press=on_press,
        on_release=on_release,
        suppress=Config.suppress,  # 注意：pynput在某些系统上可能不支持suppress
    )
    listener.start()
    return listener
