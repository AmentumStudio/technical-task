set shell := ["/bin/sh", "-eu", "-c"]

export SOURCE_DATE_EPOCH := `git log --max-count=1 --pretty=format:%ct || echo 0`

# this allows for easy setting RELEASE_TAG for all targets
default_tag := x'${RELEASE_TAG:-latest}'

container-build flavour="all" release-tag=default_tag:
    #!/bin/sh -eu
    export RELEASE_TAG='{{release-tag}}'
    docker buildx bake \
        '{{flavour}}' \
    ;

container-images flavour="all" release-tag=default_tag:
    #!/bin/sh -eu
    export RELEASE_TAG='{{release-tag}}'
    docker buildx bake \
        {{flavour}} \
        --print \
    | jq --raw-output '.target[].tags[]' \
    ;

# TODO: deal with rootless containerd ...
k3s-local-import-from-docker flavour="all" release-tag=default_tag:
    #!/bin/sh -eu
    which nerdctl 1>/dev/null
    for image in $(just container-images '{{flavour}}' '{{release-tag}}'); do
        docker image save "${image}" \
        | sudo nerdctl \
            -n k8s.io \
            -a /run/k3s/containerd/containerd.sock \
            image load \
        ;
    done;

k3s-local-container flavour="all" release-tag=default_tag:
    just container-build '{{flavour}}' '{{release-tag}}'
    just k3s-local-import-from-docker '{{flavour}}' '{{release-tag}}'

k3s-local-helm-destroy:
    helmfile destroy || true

k3s-local-helm-apply release-tag=default_tag:
    helmfile apply \
        --set=greeter.image.tag='{{release-tag}}' \
    ;

k3s-local-helm flavour="prod" release-tag=default_tag:
    just k3s-local-container '{{flavour}}' '{{release-tag}}'
    just k3s-local-helm-destroy
    just k3s-local-helm-apply '{{release-tag}}'
    helm list

k3d-cluster-default-name := 'greeter-cluster'
k3d-cluster-default-port := '7550'
k3d-cluster-host-port := '40007'
k3d-cluster-node-port := '30007'
k3d-cluster-kubeconfig := './.kubeconfig.yaml'

k3d-cluster-create name=k3d-cluster-default-name port=k3d-cluster-default-port:
    which k3d 1>/dev/null
    k3d cluster create \
        '{{name}}' \
        --agents 1 \
        --api-port '0.0.0.0:{{port}}' \
        --port '0.0.0.0:{{k3d-cluster-host-port}}:{{k3d-cluster-node-port}}@agent:0' \
        --verbose \
    ;
    k3d kubeconfig get '{{name}}' > '{{k3d-cluster-kubeconfig}}'

k3d-cluster-delete name=k3d-cluster-default-name:
    which k3d 1>/dev/null
    k3d cluster delete \
        '{{name}}' \
    ;
    rm '{{k3d-cluster-kubeconfig}}'

k3d-import-from-docker name=k3d-cluster-default-name flavour='all' release-tag=default_tag:
    #!/bin/sh -eu
    which k3d 1>/dev/null
    for image in $(just container-images '{{flavour}}' '{{release-tag}}'); do
        k3d image load  \
            --cluster='{{name}}' \
            "${image}" \
        ;
    done;

k3d-helm-destroy name=k3d-cluster-default-name:
    KUBECONFIG='{{k3d-cluster-kubeconfig}}' helmfile destroy || true

k3d-helm-apply name=k3d-cluster-default-name release-tag=default_tag:
    KUBECONFIG='{{k3d-cluster-kubeconfig}}' helmfile apply \
        --set=greeter.image.tag='{{release-tag}}' \
        --set=greeter.ingress.enabled=true \
        --set=greeter.ingress.type=nginx \
        --set=greeter.ingress.path='/' \
    ;

k3d-helm name=k3d-cluster-default-name release-tag=default_tag:
    just k3d-helm-destroy '{{name}}'
    just k3d-helm-apply '{{name}}' '{{release-tag}}'
    KUBECONFIG='{{k3d-cluster-kubeconfig}}' helm list
    KUBECONFIG='{{k3d-cluster-kubeconfig}}' kubectl get svc

# This will take some time, so don't abuse
k3d name=k3d-cluster-default-name port=k3d-cluster-default-port release-tag=default_tag:
    just k3d-cluster-delete '{{name}}' || true
    just k3d-cluster-create '{{name}}' '{{port}}'
    just container-build 'prod' '{{release-tag}}'
    just k3d-import-from-docker '{{name}}' 'prod' '{{release-tag}}'
    just k3d-helm '{{name}}'

clean:
    find . \
        \(  -name '.coverage' \
        -or -name '.pytest_cache' \
        -or -name '__pycache__' \
        \) \
        -print0 \
    | xargs \
        -rI {} \
        --null \
        rm -r '{}' \
    ;

# TODO: consider moving to per container justfile
ci-test release-tag=default_tag:
    #!/bin/sh -eu
    export IMAGE="ghcr.io/amentumstudio/chahanchart-greeter:{{release-tag}}-dev"
    docker run \
        --rm \
        --entrypoint=uv \
        --name=greeter-test \
        "${IMAGE}" \
        run pytest \
    ;

ci-test-cleanup release-tag=default_tag:
    #!/bin/sh -eu
    export IMAGE="ghcr.io/amentumstudio/chahanchart-greeter:{{release-tag}}-dev"
    docker image rm "${IMAGE}"

ci-all release-tag=default_tag:
    #!/bin/sh -eu
    export IMAGE="ghcr.io/amentumstudio/chahanchart-greeter:{{release-tag}}-dev"
    just container-build 'dev' '{{release-tag}}'
    just ci-test '{{release-tag}}'
    just ci-test-cleanup '{{release-tag}}'

gha-local workflow='ci-pull-request':
    #!/bin/sh -eu
    which act 1>/dev/null
    act \
        --workflows ".github/workflows/{{workflow}}.yml" \
        --secret-file "" \
        --var-file "" \
        --input-file "" \
        --eventpath "" \
    ;