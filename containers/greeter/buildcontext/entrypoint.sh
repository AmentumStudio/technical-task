#!/bin/sh
set -eux

cd /app
case "${FLAVOUR}" in
	"dev")
		export LOG_LEVEL="${LOG_LEVEL:-debug}"
		uv run fastapi \
			dev \
			--host="${HOST}" \
			--port="${PORT}" \
			--reload \
			./src/greeter/api.py \
			;
		;;
	"prod")
		python -m greeter
		;;
	*)
		echo "Invalid FLAVOUR=${FLAVOUR}"
		exit 1
		;;
esac
