from greeter.api import app  # noqa: F401 # pyright:ignore[reportUnusedImport]
from greeter.env import app_host, app_port, env, log_level
from uvicorn import run

if __name__ == "__main__":  # pragma: no cover
    # TODO: this should be handled probably more elegantly
    if env is None:
        raise RuntimeError("Missing required ENV environment variable!")

    run(
        "greeter.api:app",
        host=app_host,
        port=app_port,
        reload=False,
        log_level=log_level,
    )
