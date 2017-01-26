#!/usr/bin/env bash.origin
eval BO_SELF_BASH_SOURCE="$BO_READ_SELF_BASH_SOURCE"
BO_deriveSelfDir ___TMP___ "$BO_SELF_BASH_SOURCE"
local __BO_DIR__="$___TMP___"


echo "TEST_MATCH_IGNORE>>>"

BO_requireModule "../../docker.sh" as "localDocker" "localhost"

localDocker list -a

localDocker build "${__BO_DIR__}" "bach.origin.docker.example"

# TODO: Get free port dynamically
local port="8055"
localDocker start "bach.origin.docker.example" "${port}"
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

localDocker logs "bach.origin.docker.example"

if [[ `localDocker logs "bach.origin.docker.example"` != *"$requestID"* ]]; then
		echo "ERROR: Did not find request in logs!"
		exit 1
fi

localDocker stop "bach.origin.docker.example"

localDocker list

echo "<<<TEST_MATCH_IGNORE"


echo "OK"