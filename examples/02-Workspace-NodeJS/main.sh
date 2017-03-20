#!/usr/bin/env bash.origin.script

if ! BO_if_os "osx"; then
	echo "TODO: Support other operating systems."
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

pushd "$__DIRNAME__/image" > /dev/null

		CALL_docker force_build . "org.bashorigin.docker.test.02"


		CALL_docker ensure_directory_mounted_into_docker_machine "$__DIRNAME__/source"


		# TODO: Get free port dynamically
		local port="8056"
		CALL_docker start "org.bashorigin.docker.test.02" "${port}" -v "$__DIRNAME__/source:/workspace" -w "/workspace"
		CALL_docker list


		function checkForValue {

			local rid=`uuidgen`
			CALL_request wait 10 200 \
				"http://${DOCKER_CONTAINER_HOST_IP}:${port}/?rid=${rid}" \
				"Hello World from dockerized NodeJS process! [${1}][rid:${rid}]"

			CALL_docker logs "org.bashorigin.docker.test.02"

			if [[ `CALL_docker logs "org.bashorigin.docker.test.02"` != *"$requestID"* ]]; then
				echo "ERROR: Did not find request in logs!"
				exit 1
			fi
		}

		checkForValue "1"
		echo -n "2" > "$__DIRNAME__/source/file.txt"
		checkForValue "2"
		echo -n "1" > "$__DIRNAME__/source/file.txt"
		checkForValue "1"


		CALL_docker stop "org.bashorigin.docker.test.02"

		CALL_docker list

popd > /dev/null

echo "<<<TEST_MATCH_IGNORE"

echo "OK"
