# syntax=docker/dockerfile:1.15.0
# check=error=true

ARG VERSION_ALPINE="3.21"
ARG VERSION_PYTHON="3.13.2"
ARG VERSION_UV="0.6.10"
ARG BASE_IMAGE="python:${VERSION_PYTHON:?}-alpine${VERSION_ALPINE:?}"
ARG UV_IMAGE="ghcr.io/astral-sh/uv:${VERSION_UV:?}"
ARG FLAVOUR="prod"

ARG UID=10000
ARG GID=10000
ARG USER="appuser"
ARG GROUP="appuser"

FROM "${UV_IMAGE:?}" AS uv-image
FROM "${BASE_IMAGE:?}" AS base
	SHELL [ "/bin/ash", "-exu", "-o", "pipefail", "-c" ]
	WORKDIR /app
	# to be used later
	ARG VERSION_PYTHON
	# just during build time, soft/hard-linking makes no sense
	# we have to perform full copy from cache to final image
	ARG UV_LINK_MODE=copy \
		UV_PYTHON_DOWNLOADS=never \
		UV_COMPILE_BYTECODE=1

FROM base AS app-dev
	ENV FLAVOUR="dev"
	RUN apk add \
		--no-cache \
			curl \
			jq \
			yq \
		;
	COPY \
	--from=uv-image \
		/uv \
		/uvx \
		/bin/

	RUN \
	--mount=type=bind,target=./uv.lock,source=./uv.lock \
	--mount=type=bind,target=./pyproject.toml,source=./pyproject.toml \
	--mount=type=cache,target=/root/.cache/uv \
		uv sync --locked

	# VOLUME /app
	COPY . .

	ENV PATH=/app/.venv/bin:$PATH

	COPY \
	--chmod=522 \
		./entrypoint.sh \
		/entrypoint.sh

FROM base AS build-prod
	COPY \
	--from=uv-image \
		/uv \
		/uvx \
		/bin/

	COPY uv.lock pyproject.toml ./
	# verify lock with --frozen, output requirements into logs
	RUN uv export --no-dev --frozen | tee ./requirements.txt

	ARG CACHE_ID_CCACHE
	# fetch & build 3rds party dependencies
	RUN \
	--mount=type=cache,target=/root/.cache/uv \
		uv sync \
			--locked \
			--no-dev \
			--no-install-project \
		;

	COPY ./src ./src

	# build actual app
	RUN \
	--mount=type=cache,target=/root/.cache/uv \
		uv sync \
			--locked \
			--no-dev \
			--no-editable \
		;

	# package into wheel (for later install via uv pip install)
	RUN \
	--mount=type=cache,target=/root/.cache/uv \
		uv build --wheel

FROM base AS app-prod
	ENV FLAVOUR="prod"

	ARG UID
	ARG GID
	ARG USER
	ARG GROUP
	RUN adduser \
			-DH \
			-u "${UID}" \
			-g "${GID}" \
			"${USER}" \
			"${GROUP}" \
		;

	# dependencies first
	# use pip via uv to make use of uv's magical cache
	RUN \
	--mount=type=bind,from=uv-image,target=/bin/uv,source=/uv \
	--mount=type=bind,from=uv-image,target=/bin/uvx,source=/uvx \
	--mount=type=bind,from=build-prod,target=./requirements.txt,source=/app/requirements.txt \
	--mount=type=cache,target=/root/.cache/uv \
		uv pip install \
			--strict \
			--system \
			-r requirements.txt \
		;

	# now our app
	# use pip to verify uv pip worked as it should
	# --no-index ensures nothing is fetched from net:
	# - 3rd parties should already be installed
	# - app is delivered via wheels)
	RUN \
	--mount=type=bind,from=build-prod,target=./dist,source=/app/dist \
	<<-'EndOfRun'
		pip install \
			--no-index \
			--find-links=./dist/ \
			./dist/*.whl \
		;
		rm -fr /root/.cache/
EndOfRun

	COPY \
	--chown=${UID:?}:${GID:?} \
	--chmod=522 \
		./entrypoint_prod.sh \
		/entrypoint.sh

	USER ${USER:?}

FROM app-${FLAVOUR:?} AS app-final
	# Default env variables
	ENV \
		HOST=0.0.0.0 \
		PORT=8085 \
		LOG_LEVEL='' \
		WORKERS=1

	# TODO: should be /livez
	HEALTHCHECK \
	--start-period=5s \
	--start-interval=1s \
		CMD curl --silent --fail --show-error "http://127.0.0.1:${PORT}/live"

	SHELL [ "/bin/ash", "-c" ]
	ENTRYPOINT "/entrypoint.sh"