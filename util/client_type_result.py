from config import ClientConfig as Config
from pynput.keyboard import Key, Controller
import pyclip
import platform
import asyncio

# 创建键盘控制器
keyboard_controller = Controller()


async def type_result(text):
    # 模拟粘贴
    if Config.paste:
        # 保存剪切板
        try:
            temp = pyclip.paste().decode("utf-8")
        except:
            temp = ""

        # 复制结果
        pyclip.copy(text)

        # 粘贴结果
        if platform.system() == "Darwin":
            # macOS: Command+V
            keyboard_controller.press(Key.cmd)
            keyboard_controller.press("v")
            keyboard_controller.release("v")
            keyboard_controller.release(Key.cmd)
        else:
            # Windows/Linux: Ctrl+V
            keyboard_controller.press(Key.ctrl)
            keyboard_controller.press("v")
            keyboard_controller.release("v")
            keyboard_controller.release(Key.ctrl)

        # 还原剪贴板
        if Config.restore_clip:
            await asyncio.sleep(0.1)
            pyclip.copy(temp)

    # 模拟打印
    else:
        # 逐字输入文本
        for char in text:
            keyboard_controller.press(char)
            keyboard_controller.release(char)
            # 小延迟，防止输入太快
            await asyncio.sleep(0.01)
