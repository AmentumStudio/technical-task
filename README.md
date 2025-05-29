# FastAPI Kubernetes Interview Task

This repository contains a small FastAPI application intended for a technical interview task.

## Technical Task

Imagine this is a production application that needs to be deployed to a Kubernetes cluster.

Your task is to:

- Fork this repository.
- Understand the application code.
- Create a **Dockerfile** to containerise the application.
- Write a **Kubernetes Deployment YAML** file that deploys the application correctly.
- **Implement automated testing** using a CI tool of your choice (e.g., GitHub Actions, GitLab CI, Jenkins), running the tests in the provided `tests.py` script.
- **Build and deploy** the application locally using your preferred Kubernetes environment (e.g., Minikube, Kind).

---

## Resource Requirements

Please assume the following **resource needs** for the container:

| Resource | Recommended Value |
|:---------|:-------------------|
| CPU Request | `100m` |
| CPU Limit | `250m` |
| Memory Request | `128Mi` |
| Memory Limit | `512Mi` |

You are expected to define these in your Deployment YAML.

## Implementation Details

### infrastructure

Instead of single-container repository, I decided to approach this as a very small (but with room to grow!) monorepo.
As such, for building, instead of single `docker` / `moby` / `buildah` / `buildkit` invocations,
I decided to opt in for [`dockerbuildx bake`](https://docs.docker.com/reference/cli/docker/buildx/bake/)(see [`docker-bake.hcl`](./docker-bake.hcl)).
For k8s definitions, instead of writing them directly, I opted in for [`helm` charts](https://helm.sh/)
and [`helmfile`](https://github.com/helmfile/helmfile) (latter being a little bit overkill - but hey, room to grow).
For CI, as parent repo is already on GitHub, I've decided to use GitHub Actions.
As such, relevant workflows can be found at [`.github/workflows/`](./.github/workflows/).

I am currently using [NixOS](https://nixos.org/), and as such have access to [`devenv`](https://devenv.sh/).
Contents of [`flake.nix`](./flake.nix), [`flake.lock`](./flake.lock) and [`.envrc`](./.envrc) are not directly involved
in task at hand, but allow one to conveniently automagically setup correct python (and several other packages)
upon `cd`-ing into this repository.

I am currently using `vscodium`, and as such I have provided some settings and extension suggestions in
[`.vscode`](./.vscode).

I have access in my homelab to "bare-metal" [`k3s`](https://k3s.io/) cluster for my kubernetes needs.
However, as part of the task is local dev deployment, I've setup and tested [`k3d`](https://k3d.io/).

**Note:** I spent some time dealing with issues stemming from me trying to run `containerd` / `docker` rootlessly -
apparently `k3d` requires many additional steps (`cgroups2` `cpuset`, special `iptables` setup, socker permissions, etc.).
As such, I have opted to go rootfull way, and assume anyone running this repo will have rootfull as well.

**Note:** For non-`k3d` deployment, I assume [`traefik`](https://doc.traefik.io/traefik/providers/kubernetes-ingress/)
deployed as `IngressController`. Final application is reachable
either as `NodePort` ([port number configurable here](./charts/values.yaml#L10)),
or as `IngressRoute` ([configurable here](./charts/values.yaml#L6)).

Through the codebase I am making use of `TODO:` and `FIXME:` comments, for both myself and those comming after me.

### justfile

To organise common workflow actions, I have decided to use [`just`](https://github.com/casey/just) instead of `Makefile`
or shell scripts.

Quick overview of `just` targets (run `just ${target}`, where `${target}` is the name of target from the table):

| Target | Effect |
|:----------|:-------------------|
| `container-build` | Builds all container images in monorepo. |
| `k3s-local-helm` | Assuming some cluster is operable via `kubectl`, apply (always from scratch) main chart. NOTE: I have used `k3s` cluster, but this should work with other `k8s` as well. |
| `k3d` | Assuming [`k3d`](https://github.com/k3d-io) is in `${PATH}` and `docker.socket` is operable, create (always from scratch) single worker `k3d` cluster. "Greeter" will be available at `http://localhost:40007/`. Note: charts deployed are reachable as `NodePort`; was not able to elegantly make `Ingress` work with `rewrite-target` and `IngressRoute` is unavailable out-of-the-box. |
| `clean` | Delete any leftovers from running `pytest` and `pytest-cov`. |
| `ci-all` | Running via local `docker` (outside of `k3s` / `k3d`), build then test then delete images of all containers in monorepo. |
| `gha-local` | Assuming [`act`](https://github.com/nektos/act) is in `${PATH}`, will run given GitHub Actions workflow locally in docker. To run some `./github/workflows/foo.yml`, use `just gha-local foo`. NOTE: I am using the largest image and have not tested those smaller ones. They probably work, but YMMV. |

### python aplication

For application itself, I've chosen a name for it (`greeter`) just so to have something unique and recognisable,
instead of "app" or "fastapi" everywhere.
It now resides in [`./containers/greeter/`](./containers/greeter/).
For package management, I've chosen [`uv`](https://github.com/astral-sh/uv), for linting/formatting
[`ruff`](https://github.com/astral-sh/ruff), and for testing plain old `pytest`.

I've pinned down requirements, removed deprecated
[`on_event`](https://fastapi.tiangolo.com/advanced/events/#alternative-events-deprecated)
(replaced with [`lifespan`](https://fastapi.tiangolo.com/advanced/events/#lifespan)), split `uvicorn` and `FastAPI`
logic (into [`__main__.py`](./containers/greeter/buildcontext/src/greeter/__main__.py) intended for use in production,
and [`api.py`](./containers/greeter/buildcontext/src/greeter/api.py), which can be used either via `__main__.py`, or
via `uv fastapi run` or `uv fastapi dev`). As such, I also needed to split logic responsible for environment variables.

For tests, I've added code coverage with modest requirement of 80%, then added sample api tests in
[`test_api.py`](./containers/greeter/buildcontext/tests/greeter/test_api.py) for readiness / liveliness probes,
and some others.

[Dockerfile](./containers/greeter/Dockerfile) for "greeter" contains two "flavours":

1. `prod` is a minimal, `alpine` based image without development/testing packages
1. `dev` is complete development / testing environment; one can remote into it and work on the application

(This might look like an overkill, but my experience, especially with compiled languages, tells me it is worth it)

I decided not to modify the app any further, so that it remains somewhat recognisable.
As such, it could use some more extensive typing, code sharing, tests etc. .

I've also left in place all "traps" set for the unwary, such as lack of `ENV` crashing application, `sleep` making `k8s` kill
pod due to inactivity to probes, etc. .

## Post Mortem

Setting up `k3d`-based cluster actually took longer than setting up "bare-metal" single-node `k3s` cluster.
Rootless vs Rootfull is a mess.

Should've went with `docker buildx bake` instead of `docker compose build` from the get-go.

See [TODOS.md](./TODOS.md) for a (very terse) list of things that could probably be still improved upon.
