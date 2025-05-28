import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from greeter.env import env, log_level
from starlette import status

# configure app logger
logger = logging.getLogger("uvicorn.error")
logger.setLevel(str.upper(log_level))


# TODO: add startup probe?
async def deferred_ready(app: FastAPI, duration: int = 15):
    logger.info("lifespan: waiting to set ready")
    await asyncio.sleep(duration)
    logger.info("lifespan: setting ready")
    app.state.healthy = True


# https://fastapi.tiangolo.com/advanced/events/#lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("lifespan: start")
    _ = asyncio.create_task(deferred_ready(app))
    yield
    # app is already shutting down, no need to wait for task to finish
    logger.info("lifespan: end")


app = FastAPI(
    title="Greeter",
    lifespan=lifespan,
)


# leaving this endpoint due to legacy reasons
@app.get("/health")
async def health_check():
    return await liveliness_check()


@app.get("/live")  # TODO: this probably should be /livez
async def liveliness_check():
    return {"status": "ok"}


@app.get("/ready")  # TODO: this probably should be /readyz
async def readiness_check():
    if getattr(app.state, "healthy", False):
        return {"status": "ready"}
    else:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Not ready yet",
        )


@app.get("/")
async def root():
    return {"message": f"Hello from {env} environment!"}


# TODO: not sure if dict[str, Any] would be better
@app.post("/data")
async def create_data(item: dict[str, str]):
    return {"received": item}
