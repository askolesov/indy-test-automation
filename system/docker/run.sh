#!/bin/bash

DEF_TEST_TARGET="system/indy-node-tests"
DEF_PYTEST_ARGS="-l -v"
DEF_TEST_NETWORK_NAME="indy-test-automation-network"
DEF_TEST_NETWORK_SUBNET="10.0.0.0/24"

function usage {
  echo "\
Usage: $0 [test-target] [pytest-args] [test-network-name] [test-network-subnet]
defaults:
    - test-target: '${DEF_TEST_TARGET}'
    - pytest-args: '${DEF_PYTEST_ARGS}'
    - test-network-name: '${DEF_TEST_NETWORK_NAME}'
    - test-network-subnet: '${DEF_TEST_NETWORK_SUBNET}'\
"
}

if [ "$1" = "--help" ] ; then
    usage
    exit 0
fi

set -ex

test_target="${1:-$DEF_TEST_TARGET}"
pytest_args="${2:-$DEF_PYTEST_ARGS}"
test_network_name="${3:-$DEF_TEST_NETWORK_NAME}"
# TODO limit default subnet range to reduce risk of overlapping with system resources
test_network_subnet="${4:-$DEF_TEST_NETWORK_SUBNET}"

repo_path=$(git rev-parse --show-toplevel)
user_id=$(id -u)
docker_socket_path="/var/run/docker.sock"
workdir_path="/tmp/indy-test-automation"
client_image_name="system-tests-client"
client_container_name="$client_image_name"

docker_routine_path=""

# 1. prepare env
$repo_path/system/docker/prepare.sh "$test_network_name" "$test_network_subnet"

# 2. run client
docker run -it --rm --name "$client_container_name" \
    --network "${test_network_name}" \
    --ip "10.0.0.99" \
    --group-add $(stat -c '%g' "$docker_socket_path") \
    -v "$docker_socket_path:"$docker_socket_path \
    -v "$repo_path:$workdir_path" \
    -u "$user_id" \
    -w "$workdir_path" \
    -e "INDY_SYSTEM_TESTS_NETWORK=$test_network_name" \
    "$client_image_name" /bin/bash -c "
        set -ex
        pipenv --three
        pipenv run pip install -r system/requirements.txt
        pipenv run python -m pytest $pytest_args $test_target"
    "
