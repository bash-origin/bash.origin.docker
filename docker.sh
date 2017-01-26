#!/usr/bin/env bash.origin.script

# TODO: Support optionally passing a config file path for the second argument.

local $CONTAINER_HOST_LOGIN

CONTAINER_HOST_LOGIN="${__ARG1__}"


if ! BO_has docker; then
		echo >&2 "ERROR: 'docker' command not found!"
		exit 1
fi
if ! BO_has docker-machine; then
		echo >&2 "ERROR: 'docker' command not found!"
		exit 1
fi


function EXPORTS_login_to_container_host {
	login="${CONTAINER_HOST_LOGIN}"

	if [ "${CONTAINER_HOST_LOGIN}" == "localhost" ]; then
		BO_log "$VERBOSE" "Use host container login: localhost"
	else
		BO_log "$VERBOSE" "Use host container login: ${CONTAINER_HOST_LOGIN}"

		# TODO: Establish a tmux session we can keep going back to between
		#       commands so we do not have to relogin for every command.
echo "TODO"
exit 1
	fi
}

function EXPORTS_ensure_docker_host {

	ip="${_CONTAINER_HOST_IP}"

	if [ "${ip}" != "" ]; then
		BO_log "$VERBOSE" "We already have a value for CONTAINER_HOST_IP: ${_CONTAINER_HOST_IP}"
		return
	fi
	# @see https://docs.docker.com/machine/get-started/
	if [ -z "${DOCKER_HOST}" ]; then

		if [ "$(docker-machine ls --filter name=default | grep default)" == "" ]; then

			BO_log "$VERBOSE" "Create new default docker-machine"

			# TODO Support other drivers
			docker-machine create --driver virtualbox default
			docker-machine start default
		else
			if [ "$(docker-machine ls --filter name=default --filter state=running | grep default)" == "" ]; then

				BO_log "$VERBOSE" "Start default docker-machine"

		    	docker-machine start default
			fi
		fi
		BO_log "$VERBOSE" "Load default docker-machine env"
    	function stopAndStart {
    	    # The machine may enter a timeout state and not be reachable.
    	    docker-machine stop default
        	docker-machine start default
    	}
    	docker-machine env default > /dev/null || stopAndStart
    	eval "$(docker-machine env default)"
    fi
    export _CONTAINER_HOST="${DOCKER_HOST}"
    export _CONTAINER_HOST_IP=`node --eval '
        const URL = require("url");
        process.stdout.write(URL.parse(process.env.DOCKER_HOST).hostname);
    '`
}

function EXPORTS_activate {
	EXPORTS_login_to_container_host
	EXPORTS_ensure_docker_host
}


function EXPORTS_list {
	EXPORTS_activate
	docker ps $@
}

function EXPORTS_restart {
	EXPORTS_stop "$@"
	EXPORTS_start "$@"
}

function EXPORTS_stop {
	EXPORTS_activate

	image="${1}"

	# TODO: Determine if 'image' is a container ID or image name+tag

	BO_log "$VERBOSE" "Stop containers for image '${image}'"

	# TODO: Support stopping multiple containers.

      existingContainers=`docker ps --filter ancestor="${image}" --format="{{.ID}}"`
      if [ "${existingContainers}" != "" ]; then
          echo "Stopping existing docker container: ${existingContainers}"
  		docker stop "${existingContainers}"
  	fi

  	EXPORTS_remove_old_containers
}

function EXPORTS_remove_old_containers {
      # Remove exited containers older than one hour
      oldContainers=`docker ps -a | grep -e 'Exited .* \(hour\|hours\|day\|days\) ago' | cut -d ' ' -f 1 | xargs echo`
      if [ "${oldContainers}" != "" ]; then
          BO_log "$VERBOSE" "Removing old containers: ${oldContainers}"
  		docker rm ${oldContainers} || true
  	fi
}

function EXPORTS_remove_old_images {
	# First we remove old containers as images may only be
	# removed if there are no containers based on them.
  	EXPORTS_remove_old_containers

      # Remove old (dangling) image builds
      # TODO: Keep a few old versioned image builds around
      # TODO: Only remove old images with our name
      oldImages=`docker images -qa -f "dangling=true" | xargs echo`
      if [ "${oldImages}" != "" ]; then
          BO_log "$VERBOSE" "Removing old images: ${oldImages}"
  		docker rmi ${oldImages} || true
  	fi
}

function EXPORTS_build {

	EXPORTS_activate

	path="${1}"
	image="${2}"
	# TODO: Support optionally passing a config file or looking for a config file
	#       in the provided path.

      # NOTE: We must stop containers with our image name or the
      #       tagged image name will disappear from 'docker ps' because
      #       a new image with the same tag will be generated on 'docker build'.
      # TODO: Don't require existing containers to be stopped by tagging
      #       images with version instead of assuming 'latest'.
      #       To do that we must export all assets to be dockerized first and
      #       generate a '.sm.snapshot' file to hold the hash of the files.
      #       If the hash changes we generate a new build number.
	EXPORTS_stop ${image}

	BO_log "$VERBOSE" "Build image '${image}' from path '${path}'"

	pushd "${path}" > /dev/null

			docker build -t "${image}" .
# TODO: Use args passed along
#				docker build -t "${image}" --no-cache .

	popd > /dev/null

	EXPORTS_remove_old_images
}

function EXPORTS_start {
	EXPORTS_activate

	image="${1}"
	hostPort="${2}"
	# TODO: Support optionally passing a config file.

	host="${_CONTAINER_HOST}"

	BO_log "$VERBOSE" "Run image '${image}' on host '${host}'"

  docker run -d -e DOCKER_HOST="${host}" -p "${hostPort}:8080" "${image}" ${*:3}
}

function EXPORTS_logs {
	EXPORTS_activate

	image="${1}"

	container=`docker ps -a --filter ancestor="${image}" --format="{{.ID}}" | head -1`

	if [ "${container}" == "" ]; then
		echo "WARNING: No container found for image '${image}'";
		return 1;
	fi

	BO_log "$VERBOSE" "Get latest container '${container}' logs for image '${image}'"

	if [ ! -z "$VERBOSE" ]; then
		echo "----- logs for container '${container}' based on image '${image}' -----"
	fi
      docker logs --tail=all -t "${container}"
	if [ ! -z "$VERBOSE" ]; then
		echo "----- end logs -----"
	fi
}
