#!/usr/bin/env bash.origin
eval BO_SELF_BASH_SOURCE="$BO_READ_SELF_BASH_SOURCE"
BO_deriveSelfDir ___TMP___ "$BO_SELF_BASH_SOURCE"
local __BO_DIR__="$___TMP___"


if ! BO_if_os "osx"; then

		echo "TODO: Support other operating systems."

		echo "which docker: $(which docker)"
		if BO_has docker; then
				echo "docker --version: $(docker --version)"
		fi

		echo ">>>SKIP_TEST<<<"
		exit 0
fi


echo "TEST_MATCH_IGNORE>>>"

BO_requireModule "../../docker.sh" as "localDocker" "localhost"

localDocker list -a

localDocker force_build . "org.bashorigin.docker.test.01"

# TODO: Get free port dynamically
local port="8055"
localDocker start "org.bashorigin.docker.test.01" "${port}"
localDocker list

# TODO: Instead of just sleeping for 1 second, use curl to call server
#       until we get a reponse or timeout. Use 'bash.origin.request' to
#       make the calls.
sleep 1
local requestID=`uuidgen`
local command="curl -s "http://${DOCKER_CONTAINER_HOST_IP}:${port}/?rid=$requestID""
echo "Command: $command"
local response=`$command`
echo "Response: $response"
if [ "${response}" != "Hello World from dockerized NodeJS process!" ]; then
		echo "ERROR: Did not get expected response!"
		exit 1
fi

localDocker logs "org.bashorigin.docker.test.01"

if [[ `localDocker logs "org.bashorigin.docker.test.01"` != *"$requestID"* ]]; then
		echo "ERROR: Did not find request in logs!"
		exit 1
fi

localDocker stop "org.bashorigin.docker.test.01"

localDocker list

echo "<<<TEST_MATCH_IGNORE"


echo "OK"
