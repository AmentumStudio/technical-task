import os

from uvicorn import run

from greeter import api.app

log_level = os.getenv("LOG_LEVEL", "debug")
database_url = os.getenv("DATABASE_URL", "sqlite://memory")
timeout_seconds = int(os.getenv("TIMEOUT_SECONDS", "30"))

if __name__ == "__main__":
    run("main:app", host="0.0.0.0", port=8085, reload=False,)
