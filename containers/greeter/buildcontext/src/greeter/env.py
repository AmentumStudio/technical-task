from locale import atoi
from os import getenv


def int_from_env(key: str, default: int) -> int:
    try:
        return atoi(getenv(key, ""))
    except ValueError:
        return default


log_level = str.lower(getenv("LOG_LEVEL") or "info")  # TODO: type as logging.loglevel
database_url = getenv("DATABASE_URL") or "sqlite://memory"
timeout_seconds = int_from_env("TIMEOUT_SECONDS", 30)

app_host = getenv("HOST") or "0.0.0.0"
app_port = int_from_env("PORT", 8085)

# TODO: rename?
env = getenv("ENV")
