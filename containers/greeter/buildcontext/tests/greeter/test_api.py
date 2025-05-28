from unittest.mock import patch

import pytest
from fastapi import status
from fastapi.testclient import TestClient
from greeter.api import app


@pytest.mark.asyncio()
async def test_liveliness_check():
    from greeter.api import liveliness_check

    result = await liveliness_check()

    assert result == {"status": "ok"}


# TODO: reuse common code
@pytest.mark.asyncio()
async def test_readiness_check_force_healthy():
    # force healthy
    with patch.object(app.state, "healthy", True, create=True):
        with TestClient(app) as client:
            response = client.get("/ready")
            assert response.status_code == status.HTTP_200_OK
            assert response.content == b'{"status":"ready"}'


@pytest.mark.asyncio()
async def test_readiness_check_force_unhealthy():
    # force unhealthy
    with patch.object(app.state, "healthy", False, create=True):
        with TestClient(app) as client:
            response = client.get("/ready")
            assert response.status_code == status.HTTP_503_SERVICE_UNAVAILABLE
            assert response.content == b'{"detail":"Not ready yet"}'


@pytest.mark.asyncio()
async def test_readiness_check_default():
    # default
    with TestClient(app) as client:
        response = client.get("/ready")
        assert response.status_code == status.HTTP_503_SERVICE_UNAVAILABLE
        assert response.content == b'{"detail":"Not ready yet"}'
