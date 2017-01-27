#!/usr/bin/env bash.origin
eval BO_SELF_BASH_SOURCE="$BO_READ_SELF_BASH_SOURCE"
BO_deriveSelfDir ___TMP___ "$BO_SELF_BASH_SOURCE"
local __BO_DIR__="$___TMP___"


if ! BO_if_os "osx"; then
		echo "TODO: Support other operating systems."
		echo ">>>SKIP_TEST<<<"
		exit 0
fi


echo "TEST_MATCH_IGNORE>>>"

BO_requireModule "../../_#_org.bashorigin_#_1.sh" as "localDocker" "localhost"

pushd "${__BO_DIR__}/image" > /dev/null

		localDocker force_build . "org.bashorigin.docker.test.02"


		localDocker ensure_directory_mounted_into_docker_machine "${__BO_DIR__}/source"


		# TODO: Get free port dynamically
		local port="8056"
		localDocker start "org.bashorigin.docker.test.02" "${port}" -v "${__BO_DIR__}/source:/workspace" -w "/workspace"
		localDocker list

		# TODO: Instead of just sleeping for 1 second, use curl to call server
		#       until we get a reponse or timeout. Use 'bash.origin.request' to
		#       make the calls.
		sleep 1
		local requestID=`uuidgen`
		local command="curl -s "http://${DOCKER_CONTAINER_HOST_IP}:${port}/?rid=$requestID""
		echo "Command: $command"
		echo -n "2" > "${__BO_DIR__}/source/file.txt"
		local response=`$command`
		echo "Response: $response"
		echo -n "1" > "${__BO_DIR__}/source/file.txt"
		local response=`$command`
		echo "Response: $response"
		if [ "${response}" != "Hello World from dockerized NodeJS process [1]!" ]; then
				echo "ERROR: Did not get expected response!"
				exit 1
		fi

		localDocker logs "org.bashorigin.docker.test.02"

		if [[ `localDocker logs "org.bashorigin.docker.test.02"` != *"$requestID"* ]]; then
				echo "ERROR: Did not find request in logs!"
				exit 1
		fi

		localDocker stop "org.bashorigin.docker.test.02"

		localDocker list

popd > /dev/null

echo "<<<TEST_MATCH_IGNORE"


echo "OK"
