variable "RELEASE_TAG" {
    # TODO: type works locally, but not in GHA, why?
    #type    = string
    default = "latest"
}

variable "BUILD_TIME" {
    #type    = string
    default = timestamp()
}

variable "SOURCE_DATE_EPOCH" {
    #type    = number
}

group "dev" {
    targets = [
        "greeter-dev",
    ]
}

group "prod" {
    targets = [
        "greeter-prod",
    ]
}

group "all" {
    targets = [
        "dev",
        "prod",
    ]
}

# TODO: merge from other groups
group "default" {
    targets = [
        "all",
    ]
}

# TODO: common code to function
target "greeter-dev" {
    dockerfile = "../Dockerfile"
    context = "./containers/greeter/buildcontext"
    tags = ["ghcr.io/amentumstudio/chahanchart-greeter:${RELEASE_TAG}-dev"]
    args = {
        "FLAVOUR" = "dev"
    }
}

target "greeter-prod" {
    dockerfile = "../Dockerfile"
    context = "./containers/greeter/buildcontext"
    tags = [
        "ghcr.io/amentumstudio/chahanchart-greeter:${RELEASE_TAG}",
        "ghcr.io/amentumstudio/chahanchart-greeter:latest"
    ]
    args = {
        "FLAVOUR" = "prod"
    }
}