from config import ClientConfig as Config


def strip_punc(text: str) -> str:
    if Config.strip_end_punc:
        return text.strip(Config.trash_punc)
    return text
