#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/init_env_variables.sh

SERIAL="${SERIAL:-false}"

display_help() {
    echo "This script runs Tempest tests"
    echo "Usage: ${0##*/} [-h] [<testr-arguments>]"
    echo -e "\nOptions:"
    echo "      -h                   Display help"
    echo -e "\nArguments:"
    echo "      <testr-arguments>    Arguments that are passed to testr"
    echo -e "\nExamples:"
    echo "      run_tests"
    echo "      run_tests tempest.api.identity"
    echo "      run_tests tempest.api.identity.admin.test_users.UsersTestJSON"
    echo "      run_tests tempest.api.identity.admin.test_tokens.TokensTestJSON.test_create_get_delete_token"
}

parse_arguments() {
    while getopts ":h" opt; do
        case ${opt} in
            h)
                display_help
                exit 0
                ;;
            *)
                error "An invalid option has been detected"
                display_help
                exit 1
        esac
    done
    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift
    TESTARGS="$@"
}

run_tests() {
    if [ ! -d .testrepository ]; then
        testr init
    fi

    find . -type f -name "*.pyc" -delete
    export OS_TEST_PATH=./tempest/test_discover

    SUBUNIT_STREAM=$(cat .testrepository/next-stream)

    local testr_params=""
    if [ "${SERIAL}" = "true" ]; then
        testr_params=""
    fi
    cp ${DEST}/$1/etc/tempest.conf ./etc/
    SHOULDFAIL_FILE="${DEST}/shouldfail/shouldfail.yaml"
    testr run ${testr_params} --subunit ${TESTARGS} | subunit-1to2 | ${TOP_DIR}/subunit-shouldfail-filter --shouldfail-file=${SHOULDFAIL_FILE} | subunit-2to1 | ${TOP_DIR}/colorizer
}

collect_results() {
    if [ -f .testrepository/${SUBUNIT_STREAM} ] ; then
        local subunit="$(mktemp)"
        local now=$(date +"%Y%m%d-%H:%M:%S")
        subunit-1to2 < .testrepository/${SUBUNIT_STREAM} | ${TOP_DIR}/subunit-shouldfail-filter --shouldfail-file=${SHOULDFAIL_FILE} > ${subunit}
        ${TOP_DIR}/subunit-html < ${subunit} > ${DEST}/$1/logs/tempest-report.html
        subunit2junitxml < ${subunit} > ${DEST}/$1/tempest-${USER_NAME}-$1-${now}-report.xml
        cp ${DEST}/tempest/etc/tempest.conf ${DEST}/$1/
        sudo cp ${DEST}/$1/tempest-${USER_NAME}-$1-${now}-report.xml /home/tempest/
        cat ${SHOULDFAIL_FILE} > ${DEST}/$1/shouldfail.yaml
    else
        error "Subunit stream ${SUBUNIT_STREAM} is not found"
    fi
}

resource_clean(){

    keystone user-role-remove --role SwiftOperator --user demo --tenant demo 2>/dev/null || true
    keystone  user-role-remove --role anotherrole --user demo --tenant demo 2>/dev/null || true
    keystone_adm user-role-remove --role admin --user admin --tenant demo 2>/dev/null || true

    keystone role-delete SwiftOperator 2>/dev/null || true
    keystone role-delete anotherrole 2>/dev/null || true
    keystone role-delete heat_stack_user 2>/dev/null || true
    keystone role-delete heat_stack_owner 2>/dev/null || true
    keystoneadm role-delete ResellerAdmin 2>/dev/null || true

    keystone user-delete demo 2>/dev/null || true
    keystone tenant-delete demo 2>/dev/null || true

    message "Delete the created flavors"
     nova flavor-delete m1.tempest-nano || true
     nova flavor-delete m1.tempest-micro || true

    message "Delete the uploaded CirrOS image"
     glance image-delete cirros-${CIRROS_VERSION}-x86_64 || true
}

run() {
    message "Running Tempest tests"

    cd ${DEST}/tempest
    message "Tempest commit ID is $(git log -n 1 | awk '/commit/ {print $2}')"

    configure_tempest "$@"
    configure_shouldfail_file

    run_tests "$@"
    collect_results "$@" 

   # resource_clean "$@"

    cd ${TOP_DIR}
}

return_exit_code() {
    local failures_count="$(cat ${DEST}/$1/tempest-report.xml | grep "failures" | awk -F '"' '{print $4}')"
    if [ "${failures_count}" -eq "0" ]; then
        exit 0
    else
        exit 1
    fi
}

main() {
    parse_arguments "$@"
    run "$@"
    return_exit_code "$@"
}

main "$@"
