#!/usr/bin/env bash.origin.script

if ! BO_has docker; then
	echo "ERROR: 'docker' not found!"
	echo ">>>SKIP_TEST<<<"
	exit 0
fi

echo "TEST_MATCH_IGNORE>>>"

depend {
    "docker": {
		"@../..#s1": "localhost"
	},
	"request": "@com.github/bash-origin/bash.origin.request#s1"
}

CALL_docker list -a

CALL_docker force_build . "org.bashorigin.docker.test.01"

# TODO: Get free port dynamically
local port="8055"
CALL_docker start "org.bashorigin.docker.test.01" "${port}"
CALL_docker list


local rid=`uuidgen`
CALL_request wait 10 200 \
	"http://${DOCKER_CONTAINER_HOST_IP}:${port}/?rid=$rid" \
	"Hello World from dockerized NodeJS process! [rid:$rid]"


CALL_docker logs "org.bashorigin.docker.test.01"

if [[ `CALL_docker logs "org.bashorigin.docker.test.01"` != *"$rid"* ]]; then
	echo "ERROR: Did not find request in logs!"
	exit 1
fi

CALL_docker stop "org.bashorigin.docker.test.01"

CALL_docker list

echo "<<<TEST_MATCH_IGNORE"


echo "OK"
