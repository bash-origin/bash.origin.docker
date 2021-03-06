#!/usr/bin/env bash.origin.script

# TODO: Support optionally passing a config file path for the second argument.

local $CONTAINER_HOST_LOGIN=""

CONTAINER_HOST_LOGIN="${__ARG1__}"


if ! BO_has docker; then
	echo >&2 "[bash.origin.docker] ERROR: 'docker' command not found! (PATH: $PATH)"
	echo >&2 "[bash.origin.docker] Download from: https://hub.docker.com/editions/community/docker-ce-desktop-mac"
	exit 1
fi

USE_DOCKER_MACHINE=0

if BO_if_os "osx"; then
	if ! docker ps > /dev/null; then
		echo >&2 "[bash.origin.docker] ERROR: The 'docker' command is failing because docker is not started. If you have 'docker for mac' installed, start docker now via the status bar icon. If you want to use 'docker-machine' set an environment variable 'FORCE_USE_DOCKER_MACHINE' (PATH: $PATH)"

		if [ ! -z "$FORCE_USE_DOCKER_MACHINE" ]; then
			if ! BO_has docker-machine; then
				echo >&2 "[bash.origin.docker] ERROR: 'docker-machine' command not found! (PATH: $PATH)"
				exit 1
			fi
			if ! BO_has vboxmanage; then
				echo >&2 "[bash.origin.docker] ERROR: 'vboxmanage' command not found! Install VirtualBox. (PATH: $PATH)"
				exit 1
			fi
			USE_DOCKER_MACHINE=1
		fi
	fi
fi

function EXPORTS_login_to_container_host {

	BO_log "$VERBOSE" "[bash.origin.docker] login_to_container_host() args: $@"

	login="${CONTAINER_HOST_LOGIN}"

	if [ "${CONTAINER_HOST_LOGIN}" == "localhost" ]; then
		BO_log "$VERBOSE" "[bash.origin.docker] Use host container login: localhost"
	else
		BO_log "$VERBOSE" "[bash.origin.docker] Use host container login: ${CONTAINER_HOST_LOGIN}"

		# TODO: Establish a tmux session we can keep going back to between
		#       commands so we do not have to relogin for every command.
echo "TODO: bash.origin.docker - login_to_container_host"
exit 1
	fi
}

# Use this when you get 'Error response from daemon: client is newer than server' and re-run.
# TODO: Run 'docker ps' when this modules initializes and if we get 'Error response from daemon: client is newer than server'
#       run this method (only when running with --autofix)
function EXPORTS_reprovision_docker_host {

	if [[ $USE_DOCKER_MACHINE != 1 ]]; then
		echo >&2 "[bash.origin.docker] ERROR: 'reprovision_docker_host' command not enabled due to 'USE_DOCKER_MACHINE = 0'"
		return;
	fi

	BO_log "$VERBOSE" "[bash.origin.docker] reprovision_docker_host() args: $@"

	EXPORTS_ensure_docker_host

	if BO_has docker-machine; then

		docker-machine stop default
		docker-machine rm -f default
		docker-machine create --driver virtualbox default
	fi
}

function EXPORTS_echo_CONTAINER_HOST_IP {

	if [[ $USE_DOCKER_MACHINE != 1 ]]; then
		# @see https://stackoverflow.com/a/41475171
		echo "127.0.0.1"
		return;
	fi

	EXPORTS_ensure_docker_host
	echo "$_CONTAINER_HOST_IP"
}

function EXPORTS_ensure_docker_host {

	if [[ $USE_DOCKER_MACHINE != 1 ]]; then
		echo >&2 "[bash.origin.docker] ERROR: 'ensure_docker_host' command not enabled due to 'USE_DOCKER_MACHINE = 0'"
		return;
	fi

	BO_log "$VERBOSE" "[bash.origin.docker] ensure_docker_host() args: $@"

	if ! BO_has docker-machine; then
		export _CONTAINER_HOST="tcp://127.0.0.1:2375"
		export _CONTAINER_HOST_IP="127.0.0.1"
		return
	fi

	ip="${_CONTAINER_HOST_IP}"

	if [ "${ip}" != "" ]; then
		BO_log "$VERBOSE" "[bash.origin.docker] We already have a value for CONTAINER_HOST_IP: ${_CONTAINER_HOST_IP}"
		return
	fi
	# @see https://docs.docker.com/machine/get-started/
	if [ -z "${DOCKER_HOST}" ]; then

		if [ "$(docker-machine ls --filter name=default | grep default)" == "" ]; then

			BO_log "$VERBOSE" "[bash.origin.docker] Create new default docker-machine"

			# TODO Support other drivers
			docker-machine create --driver virtualbox default
			docker-machine start default
		else
			if [ "$(docker-machine ls --filter name=default --filter state=running | grep default)" == "" ]; then

				BO_log "$VERBOSE" "[bash.origin.docker] Start default docker-machine"

		    	docker-machine start default
			fi
		fi
		BO_log "$VERBOSE" "[bash.origin.docker] Load default docker-machine env"
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

	BO_log "$VERBOSE" "[bash.origin.docker] activate() args: $@"

	if [[ $USE_DOCKER_MACHINE == 1 ]]; then
		EXPORTS_ensure_docker_host
	fi
}

function EXPORTS_list {

	BO_log "$VERBOSE" "[bash.origin.docker] list() args: $@"

	EXPORTS_activate
	docker ps $@
}

function EXPORTS_restart {

	BO_log "$VERBOSE" "[bash.origin.docker] restart() args: $@"

	EXPORTS_stop "$@"
	EXPORTS_start "$@"
}

function EXPORTS_stop {
	EXPORTS_activate

	BO_log "$VERBOSE" "[bash.origin.docker] stop() args: $@"

	image="${1}"

	# TODO: Determine if 'image' is a container ID or image name+tag

	BO_log "$VERBOSE" "[bash.origin.docker] Stop containers for image '${image}'"

	# TODO: Support stopping multiple containers.

	existingContainers=`docker ps --filter ancestor="${image}" --format="{{.ID}}"`
	if [ "${existingContainers}" != "" ]; then
	  	BO_log "$VERBOSE" "[bash.origin.docker] Stopping existing docker container: ${existingContainers}"
		docker stop "${existingContainers}"
	fi

  	EXPORTS_remove_old_containers
}

function EXPORTS_remove_old_containers {

	BO_log "$VERBOSE" "[bash.origin.docker] remove_old_containers() args: $@"

	# Remove exited containers older than one hour
	oldContainers=`docker ps -a | grep -e 'Exited .* \(hour\|hours\|day\|days\|week\|weeks\) ago' | cut -d ' ' -f 1 | xargs echo`
	if [ "${oldContainers}" != "" ]; then
			BO_log "$VERBOSE" "[bash.origin.docker] Removing old containers: ${oldContainers}"
  		docker rm ${oldContainers} || true
	fi
}

function EXPORTS_remove_old_images {
		# First we remove old containers as images may only be
		# removed if there are no containers based on them.
  	EXPORTS_remove_old_containers

		BO_log "$VERBOSE" "[bash.origin.docker] remove_old_images() args: $@"

		# Remove old (dangling) image builds
		# TODO: Keep a few old versioned image builds around
		# TODO: Only remove old images with our name
		oldImages=`docker images -qa -f "dangling=true" | xargs echo`
		if [ "${oldImages}" != "" ]; then
				BO_log "$VERBOSE" "[bash.origin.docker] Removing old images: ${oldImages}"
				docker rmi ${oldImages} || true
		fi
}


function EXPORTS_force_build {

	BO_log "$VERBOSE" "[bash.origin.docker] force_build() args: $@"

	EXPORTS_build "$@" --no-cache=true
}

function EXPORTS_build {

	EXPORTS_activate

	BO_log "$VERBOSE" "[bash.origin.docker] build() args: $@"

	path="${1}"
	if [ "$path" == "." ]; then
			path="$(pwd)"
	fi
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

	BO_log "$VERBOSE" "[bash.origin.docker] Build image '${image}' from path '${path}'"

	pushd "${path}" > /dev/null

		BO_log "$VERBOSE" "[bash.origin.docker] Running: docker build --build-arg BO_VERBOSE=${BO_VERBOSE} --build-arg VERBOSE=${VERBOSE} ${*:3} -t ${image} ."

		# TODO: Only include build-args if found in docker file.
		docker build --build-arg BO_VERBOSE=${BO_VERBOSE} --build-arg VERBOSE=${VERBOSE} ${*:3} -t "${image}" .

	popd > /dev/null

	# Don't exit on error.
	set +e
	EXPORTS_remove_old_images
	set -e
}

function EXPORTS_start {
	EXPORTS_activate

	BO_log "$VERBOSE" "[bash.origin.docker] start() args: $@"

	image="${1}"
	hostPort="${2}"
	# TODO: Support optionally passing a config file.

	host="${_CONTAINER_HOST}"

	BO_log "$VERBOSE" "[bash.origin.docker] Run image '${image}' on host '${host}'"


	# TODO: Determine internal port based on image schema
	BO_log "$VERBOSE" "[bash.origin.docker] Running: docker run -d -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -p ${hostPort}:80 ${*:3} ${image}"

  docker run -d -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -p "${hostPort}:80" ${*:3} "${image}"

	# TODO: Optionally set 'AUTHORIZED_KEYS'
	#BO_log "$VERBOSE" "[bash.origin.docker] Running: docker run -d -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -e AUTHORIZED_KEYS="`cat ~/.ssh/id_rsa.pub`" -p ${hostPort}:80 ${*:3} ${image}"
  #docker run -d -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -e AUTHORIZED_KEYS="`cat ~/.ssh/id_rsa.pub`" -p "${hostPort}:80" ${*:3} "${image}"
}

function EXPORTS_run {
	EXPORTS_activate

	BO_log "$VERBOSE" "[bash.origin.docker] run() args: $@"

	image="${1}"
	# TODO: Support optionally passing a config file.

	host="${_CONTAINER_HOST}"
	hostPort="${2}"

	BO_log "$VERBOSE" "[bash.origin.docker] Run image '${image}' on host '${host}'"


	# TODO: Determine internal port based on image schema
	BO_log "$VERBOSE" "[bash.origin.docker] Running: docker run -d -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -p "${hostPort}:80" ${*:3} ${image}"

  docker run -ti --rm -m 1g -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -p "${hostPort}:80" ${*:3} "${image}"

	# TODO: Optionally set 'AUTHORIZED_KEYS'
	#BO_log "$VERBOSE" "[bash.origin.docker] Running: docker run -d -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -e AUTHORIZED_KEYS="`cat ~/.ssh/id_rsa.pub`" ${*:2} ${image}"
  #docker run -ti --rm -m 1g -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -e AUTHORIZED_KEYS="`cat ~/.ssh/id_rsa.pub`" ${*:2} "${image}"
}

function EXPORTS_run_no_tty {
	EXPORTS_activate

	BO_log "$VERBOSE" "[bash.origin.docker] run() args: $@"

	image="${1}"
	# TODO: Support optionally passing a config file.

	host="${_CONTAINER_HOST}"
	hostPort="${2}"

	BO_log "$VERBOSE" "[bash.origin.docker] Run image '${image}' on host '${host}'"


	# TODO: Determine internal port based on image schema
	BO_log "$VERBOSE" "[bash.origin.docker] Running: docker run -d -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -p "${hostPort}:80" ${*:3} ${image}"

  docker run --rm -m 1g -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -p "${hostPort}:80" ${*:3} "${image}"

	# TODO: Optionally set 'AUTHORIZED_KEYS'
	#BO_log "$VERBOSE" "[bash.origin.docker] Running: docker run -d -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -e AUTHORIZED_KEYS="`cat ~/.ssh/id_rsa.pub`" ${*:2} ${image}"
  #docker run -ti --rm -m 1g -e BO_VERBOSE=${BO_VERBOSE} -e VERBOSE=${VERBOSE} -e DOCKER_HOST=${host} -e AUTHORIZED_KEYS="`cat ~/.ssh/id_rsa.pub`" ${*:2} "${image}"
}

function EXPORTS_logs {
	EXPORTS_activate

	BO_log "$VERBOSE" "[bash.origin.docker] logs() args: $@"

	image="${1}"

	container=`docker ps -a --filter ancestor="${image}" --format="{{.ID}}" | head -1`

	if [ "${container}" == "" ]; then
		echo "[bash.origin.docker] WARNING: No container found for image '${image}'";
		return 1;
	fi

	BO_log "$VERBOSE" "[bash.origin.docker] Get latest container '${container}' logs for image '${image}'"

	if [ ! -z "$VERBOSE" ]; then
		echo "[bash.origin.docker] ----- logs for container '${container}' based on image '${image}' -----"
	fi
      docker logs ${*:2} -t "${container}"
	if [ ! -z "$VERBOSE" ]; then
		echo "[bash.origin.docker] ----- end logs -----"
	fi
}


function EXPORTS_ensure_directory_mounted_into_docker_machine {

	if [[ $USE_DOCKER_MACHINE != 1 ]]; then
		echo >&2 "[bash.origin.docker] ERROR: 'ensure_directory_mounted_into_docker_machine' command not enabled due to 'USE_DOCKER_MACHINE = 0'"
		echo >&2 "[bash.origin.docker] ERROR: If you are using 'docker for mac' you need to enable sharing via 'configure shared paths from Docker -> Preferences... -> File Sharing' via docker status bar icon."
		return;
	fi

	# @see http://stackoverflow.com/a/33404132/330439

	BO_log "$VERBOSE" "[bash.origin.docker] ensure_directory_mounted_into_docker_machine() args: $@"

		if ! BO_has docker-machine; then
			echo >&2 "[bash.origin.docker] ERROR: 'docker-machine' command not found! (PATH: $PATH)"
			exit 1
		fi

		if ! BO_has openssl; then
				echo "[bash.origin.docker] ERROR: 'openssl' command required!"
				exit 1
		fi

		MACHINE_NAME="default"
		WORK_DIR="$1"
		# NOTE: We mount our working directory to the same spot in the VM for
		#       simplicity, consistency and to avoid conflicts.
		HOST_DIR="$WORK_DIR"
	    VOL_NAME="vol_$(echo -n "$HOST_DIR" | openssl sha1)"

		BO_log "$VERBOSE" "[bash.origin.docker] Creating directory '$HOST_DIR' on docker-machine '$MACHINE_NAME'"
		BO_log "$VERBOSE" "[bash.origin.docker] Running: docker-machine ssh \"$MACHINE_NAME\" \"sudo mkdir -p \"$HOST_DIR\"\""
		docker-machine ssh "$MACHINE_NAME" "sudo mkdir -p \"$HOST_DIR\""

		BO_log "$VERBOSE" "[bash.origin.docker] Sharing work directory '$WORK_DIR' to docker-machine '$MACHINE_NAME' into directory '$HOST_DIR' using volume name '$VOL_NAME'"
		BO_log "$VERBOSE" "[bash.origin.docker] Running: vboxmanage sharedfolder add $MACHINE_NAME --name $VOL_NAME --hostpath $HOST_DIR --transient"
		if [ -z "$VERBOSE" ]; then
				vboxmanage sharedfolder add "$MACHINE_NAME" --name "$VOL_NAME" --hostpath "$HOST_DIR" --transient > /dev/null 2>&1
		else
				vboxmanage sharedfolder add "$MACHINE_NAME" --name "$VOL_NAME" --hostpath "$HOST_DIR" --transient
		fi

		BO_log "$VERBOSE" "[bash.origin.docker] Running: docker-machine ssh $MACHINE_NAME \"sudo mount -t vboxsf -o uid=100,gid=100 \\"$VOL_NAME\\" \\"$HOST_DIR\\"\""
		docker-machine ssh $MACHINE_NAME "sudo mount -t vboxsf -o uid=100,gid=100 \"$VOL_NAME\" \"$HOST_DIR\""
}
