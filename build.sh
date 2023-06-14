#!/bin/bash
# Generic Build Script for Jenkins
# v1.0 Mar 2023 by Cronocide

#  ___  ___ ___ _    ___ ___ ___ _      _ _____ ___
# | _ )/ _ \_ _| |  | __| _ \ _ \ |    /_\_   _| __|
# | _ \ (_) | || |__| _||   /  _/ |__ / _ \| | | _|
# |___/\___/___|____|___|_|_\_| |____/_/ \_\_| |___|

# Get the OS type. Most specific distributions first.
export OS="$(uname -a)"
[[ "$OS" == *"iPhone"* || "$OS" == *"iPad"* ]] && export OS="iOS"
[[ "$OS" == *"ndroid"* ]] && export OS="Android"
[[ "$OS" == *"indows"* ]] && export OS="Windows"
[[ "$OS" == *"arwin"* ]] && export OS="macOS"
[[ "$OS" == *"BSD"* ]] && export OS="BSD"
[[ "$OS" == *"inux"* ]] && export OS="Linux"

# Verify a list of software or operating systems. Inverted returns for ease-of-use.
__missing_os() {
	for i in $(echo "$@"); do
		! __no_os "$i" && return 1
	done
	echo "This function is not available on $OS." && return 0
}

__no_os() {
	[[ "$OS" == "$1" ]] && return 1
	return 0
}

# Verify we have dependencies needed to execute successfully
__missing_reqs() {
	for i in "$@"; do
		[[ "$0" != "$i" ]] && __no_req "$i" && echo "$i is required to perform this function." && return 0
	done
	return 1
}

__no_req() {
	[[ "$(type $1 2>/dev/null)" == '' ]] && return 0
	return 1
}

# An abstraction for curl/wget. Accepts url and <optional output path>
__http_get() {
	OUTPUT="$2"; [ -z "$OUTPUT" ] && export OUTPUT="-"
	if [[ "$(type curl 2>/dev/null)" != '' ]]; then
		curl -s "$1" -o "$OUTPUT"
		[ "$OUTPUT" != "-" ] && (! [ -f "$OUTPUT" ] || [[ $(cat "$OUTPUT" | tr -d '\0' 2>/dev/null) == '' ]]) && return 1
		return 0
	else
		if ! [[ "$(type wget 2>/dev/null)" != '' ]]; then
			wget "$1" -O "$2"
			[ "$OUTPUT" != "-" ] && (! [ -f "$2" ] || [[ $(cat "$2" | tr -d '\0' 2>/dev/null) == '' ]]) && return 1
			return 0
		fi
	fi
	echo "curl or wget is required to perform this function." && return 1
}

__missing_sed() {
    __no_req "sed" && __no_req "gsed" && echo "sed or gsed is required to perform this function." && return 0
}

sed_i() {
    __missing_sed && return 1;
    if [[ "$OS" == "macOS" ]]; then
        if [[ $(type gsed 2>/dev/null) != '' ]]; then
            gsed -i "$@";
        else
            sed -i '' "$@";
        fi;
    else
        sed -i "$@";
    fi
}

# Echo errors to stderr
error() {
	echo "$@" 1>&2
}

#  ___ _   _ _  _  ___ _____ ___ ___  _  _ ___
# | __| | | | \| |/ __|_   _|_ _/ _ \| \| / __|
# | _|| |_| | .` | (__  | |  | | (_) | .` \__ \
# |_|  \___/|_|\_|\___| |_| |___\___/|_|\_|___/


cicd_prepare() {
	# Prepare the build environment.
	echo "Preparing for Build"
	# TODO
	echo "Completed Preparing for Build"
}

cicd_inspect() {
	# Information about the build environment.
	echo "Inspecting Build Environment"
	env
	echo "Completed Inspecting Build Environment"
}

cicd_build() {
	# Build a new software artifact.
	__missing_reqs "docker" && exit 1
	echo "Building Software"
	docker build --pull=true \
             --label "org.opencontainers.image.vendor=cronocide.net" \
             --label "org.opencontainers.image.title=${PROJECT_NAME}" \
             --label "org.opencontainers.image.url=https://${GIT_REPO_NAME}" \
             --label "org.opencontainers.image.source=https://${IMAGE_NAME}" \
             --label "net.cronocide.build-info.git-repo=${GIT_URL}" \
             --label "net.cronocide.build-info.git-branch=${GIT_BRANCH}" \
             --label "net.cronocide.build-info.git-commit=${GIT_COMMIT}" \
             --label "net.cronocide.build-info.build-time=$(date -u)" \
             --tag="$COMMIT_TAG" \
	     --tag="$LATEST_TAG" \
             .
	echo "Completed Building Software"
}

cicd_test() {
	# Run tests on the built software artifact.
	echo "Testing Software"
	# TODO
	echo "Completed Testing Software"
}

cicd_publish() {
	# Publish the software to artifact repositories.
	__missing_reqs "docker" && exit 1
	echo "Publishing Software"
	# TODO: Improve the logic of this Docker login flow.
	LOGIN_CREDS="DOCKER_USERNAME DOCKER_PASSWORD"
	for CRED in $(echo "$LOGIN_CREDS"); do
	        [ -z "${!CRED}" ] && echo "Missing $CRED, skipping docker login." && export SKIP_DOCKER_LOGIN=1
	done
	[[ "$SKIP_DOCKER_LOGIN" != "1" ]] && docker login "$GIT_REPO_NAME" -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD"
	docker push ${COMMIT_TAG}
	docker push ${LATEST_TAG}
	echo "Completed Publishing Software"
}

cicd_deploy() {
	echo "Deploying Software"
	# TODO: Check for a nomad folder
	if ! [ -f "$PROJECT_NAME".hcl ]; then
		__http_get "https://setup.cronocide.com/nomad/base.hcl" "$PROJECT_NAME".hcl
		__http_get "https://setup.cronocide.com/nomad/base.volume" "$PROJECT_NAME".volume
		sed_i "s#base#$PROJECT_NAME#g" "$PROJECT_NAME".hcl
		sed_i "s#image:latest#$PROJECT_NAME:latest#g" "$PROJECT_NAME".hcl
		sed_i "s#base#$PROJECT_NAME#g" "$PROJECT_NAME".volume
		nomad volume create "$PROJECT_NAME".volume
	else
		nomad job run "$PROJECT_NAME".hcl
	fi
	echo "Completed Deploying Software"
}

#  __  __   _   ___ _  _
# |  \/  | /_\ |_ _| \| |
# | |\/| |/ _ \ | || .` |
# |_|  |_/_/ \_\___|_|\_|

__missing_reqs "git sed" && exit 1

# Verify that an ACTION is supplied in the environment.
BUILD_PREFIX="cicd"
[ -z "$ACTION" ] && error "No ACTION supplied, no action taken." && exit 1
[[ "$ACTION" != "$BUILD_PREFIX"* ]] && error "Action $ACTION is not recognized as a valid action."
__no_req "$ACTION" && error "Action $ACTION is not recognized as a valid action." && exit 1

# Define needed build strings
DIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
PROJECT_NAME="$(git config --local remote.origin.url|sed -n 's#.*/\([^.]*\)\.git#\1#p')"
IMAGE_NAME="$GIT_REPO_NAME/$USERN/$PROJECT_NAME"
GIT_COMMIT=$(git rev-parse HEAD)
GIT_URL=$(git config --get remote.origin.url)
GIT_BRANCH=$(git branch | grep \* | cut -d ' ' -f2)
COMMIT_TAG="${IMAGE_NAME}:${GIT_COMMIT}"
LATEST_TAG="${IMAGE_NAME}:latest"

# Run specified build task
"$ACTION"
