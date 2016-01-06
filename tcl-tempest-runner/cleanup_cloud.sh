#!/bin/bash -x

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/helpers/init_env_variables.sh

#CONTROLLER_HOST="node-$(fuel node "$@" | grep controller | awk '{print $1}' | head -1)"
#ADMIN_TOKEN="$(ssh ${CONTROLLER_HOST} egrep "^admin_token.*" /etc/keystone/keystone.conf 2>/dev/null | cut -d'=' -f2)"
#OS_PUBLIC_AUTH_URL="$(ssh ${CONTROLLER_HOST} ". openrc; keystone catalog --service identity 2>/dev/null | grep publicURL | awk '{print \$4}'")"
#OS_PUBLIC_IP="$(ssh ${CONTROLLER_HOST} "grep -w public_vip /etc/hiera/globals.yaml | awk '{print \$2}' | sed 's/\"//g'")"

init_variables() {
local  env_id="$( ssh $1 "fuel env | grep $2  | awk '{print \$1}'")"
message "${env_id}"

local controller_ip="$(ssh $1 "fuel --env-id $env_id  node list | grep controller | awk '{print \$10}'")"
message "$controller_ip" 
#local controller_host_id="$(fuel node "$@" | grep controller | awk '{print $1}' | head -1)"
CONTROLLER_HOST=${controller_ip}
message "Controller host is '${CONTROLLER_HOST}'"
#local compute_ip="$(ssh $1 "fuel --env-id $env_id  node list | grep compute

   # FUEL_RELEASE="$(ssh 'fuel --fuel-version 2>&1 | grep -e ^release:' | awk '{print $2}' | sed "s/'//g")"
   # message "Fuel release is ${FUEL_RELEASE}"

   OS_PUBLIC_AUTH_URL="$(ssh $1 "ssh ${controller_ip} '. openrc; keystone catalog --service identity 2>/dev/null | grep publicURL'" | awk '{print $4}')"
   OS_PUBLIC_IP="$(ssh $1 "ssh ${controller_ip} 'grep -w public_vip /etc/hiera/globals.yaml'" | awk '{print $2}' | sed 's/\"//g')"
   ADMIN_TOKEN="$(ssh $1 "ssh ${controller_ip} 'egrep ^admin_token.* /etc/keystone/keystone.conf |cut -d'=' -f2' ")"
   message "admin token is ${ADMIN_TOKEN}"

}






keystone_adm() {
    remote_cli keystone --os-token ${ADMIN_TOKEN} --os-endpoint ${OS_PUBLIC_AUTH_URL/5000/35357} $@
}

restore_service_catalog() {
    init_variables "$@"
    message "Revert Keystone endpoints"
   # local identity_service_id="$(keystone_adm service-list | grep identity | awk '{print $2}')"
   # local old_endpoint="$(keystone_adm endpoint-list | grep ${identity_service_id}|awk '{print $2}')"
   # local internal_url="$(ssh ${CONTROLLER_HOST} ". openrc; keystone catalog --service identity 2>/dev/null | grep internalURL | awk '{print \$4}'")"
    local identity_service_id="$(ssh $1 "ssh ${CONTROLLER_HOST} '. openrc ;keystone --os-token ${ADMIN_TOKEN} --os-endpoint ${OS_PUBLIC_AUTH_URL} service-list  2>/dev/null | grep identity'" | awk '{print $2}')"
    local old_endpoint="$(ssh $1 "ssh ${CONTROLLER_HOST} '.openrc ; keystone --os-token ${ADMIN_TOKEN} --os-endpoint ${OS_PUBLIC_AUTH_URL} endpoint-list 2>/dev/null |grep ${identity_service_id}" | awk '{print $2}')"

    local internal_url="$(ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone --os-token ${ADMIN_TOKEN} --os-endpoint ${OS_PUBLIC_AUTH_URL} catalog --service identity 2>/dev/null | grep internalURL'" | awk '{print $4}')"
   # local admin_url="$(ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone endpoint-list  2>/dev/null | grep ${identity_service_id}'" | awk '{print $10}')"

   ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone --os-token ${ADMIN_TOKEN} --os-endpoint ${OS_PUBLIC_AUTH_URL} endpoint--create --region RegionOne --service ${identity_service_id} --publicurl ${OS_PUBLIC_AUTH_URL} --adminurl ${OS_PUBLIC_AUTH_URL/5000/35357} --internalurl ${internal_url}  2>/dev/null' "

   # keystone_adm endpoint-create --region RegionOne --service ${identity_service_id} --publicurl ${OS_PUBLIC_AUTH_URL} --adminurl ${internal_url/5000/35357} --internalurl ${internal_url} 2>/dev/null
    if [ ! -z ${old_endpoint} ]; then
        ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone --os-token ${ADMIN_TOKEN} --os-endpoint ${OS_PUBLIC_AUTH_URL} endpoint-delete ${old_endpoint} 2>/dev/null' "
        #keystone_adm endpoint-delete ${old_endpoint} 2>/dev/null
    fi
}

restore_keystone_haproxy_conf() {
    message "Restore keystone haproxy conf"
    #local controller_node_ids=$(fuel node "$@" | grep controller | awk '{print $1}')
    #for controller_node_id in ${controller_node_ids}; do
    #    ssh node-${controller_node_id} "sed -i '/^bind.*${OS_PUBLIC_IP}:35357.*$/d' ${KEYSTONE_HAPROXY_CONFIG_PATH}"    
        ssh $1 "ssh ${CONTROLLER_HOST} 'sed -i '/^bind.*${OS_PUBLIC_IP}:35357.*$/d' ${KEYSTONE_HAPROXY_CONFIG_PATH}' "
    #done
    message "Restart haproxy"
        ssh $1 "ssh ${CONTROLLER_HOST} 'pcs resource disable p_haproxy --wait' "
        ssh $1 "ssh ${CONTROLLER_HOST} 'pcs resource enable p_haproxy --wait' "

}

cleanup_cloud() {

    restore_service_catalog "$@"

    message "Delete the created user, tenant and roles"
   # keystone_adm user-role-remove --role SwiftOperator --user demo --tenant demo 2>/dev/null || true
   # keystone_adm user-role-remove --role anotherrole --user demo --tenant demo 2>/dev/null || true
   # keystone_adm user-role-remove --role admin --user admin --tenant demo 2>/dev/null || true

   # keystone_adm role-delete SwiftOperator 2>/dev/null || true
   # keystone_adm role-delete anotherrole 2>/dev/null || true
   # keystone_adm role-delete heat_stack_user 2>/dev/null || true
   # keystone_adm role-delete heat_stack_owner 2>/dev/null || true
   # keystone_adm role-delete ResellerAdmin 2>/dev/null || true

   # keystone_adm user-delete demo 2>/dev/null || true
   # keystone_adm tenant-delete demo 2>/dev/null || true

   # message "Delete the created flavors"
   # remote_cli nova flavor-delete m1.tempest-nano || true
   # remote_cli nova flavor-delete m1.tempest-micro || true

   # message "Delete the uploaded CirrOS image"
   # remote_cli glance image-delete cirros-${CIRROS_VERSION}-x86_64 || true

    restore_keystone_haproxy_conf "$@"

    message "Cleanup is done!"
}

cleanup_cloud "$@"
