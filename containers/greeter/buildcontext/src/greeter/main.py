import os
import time

import uvicorn
from fastapi import FastAPI, HTTPException

app = FastAPI()

env = os.getenv("ENV")
if env is None:
    raise RuntimeError("Missing required ENV environment variable!")

log_level = os.getenv("LOG_LEVEL", "debug")
database_url = os.getenv("DATABASE_URL", "sqlite://memory")
timeout_seconds = int(os.getenv("TIMEOUT_SECONDS", "30"))


@app.on_event("startup")
async def startup_event():
    time.sleep(15)
    app.state.healthy = True


@app.get("/health")
async def health_check():
    return {"status": "ok"}


@app.get("/ready")
async def readiness_check():
    if getattr(app.state, "healthy", False):
        return {"status": "ready"}
    else:
        raise HTTPException(status_code=503, detail="Not ready yet")


@app.get("/")
async def root():
    return {"message": f"Hello from {env} environment!"}


@app.post("/data")
async def create_data(item: dict):
    return {"received": item}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8085, reload=False)
