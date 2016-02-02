#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/init_env_variables.sh

check_service_availability() {
    local service_count="$(keystone service-list 2>/dev/null | grep $1 | wc -l)"
    
    if [ "${service_count}" -eq "0" ]; then
        echo "false"
    else
        echo "true"
    fi
}
resource_create(){


message "Create needed tenant and roles for Tempest tests"
    keystone tenant-create --name demo 2>/dev/null || true
    keystone user-create --tenant demo --name demo --pass demo 2>/dev/null || true

    keystone role-create --name SwiftOperator 2>/dev/null || true
    keystone role-create --name anotherrole 2>/dev/null || true
    keystone role-create --name heat_stack_user 2>/dev/null || true
    keystone role-create --name heat_stack_owner 2>/dev/null || true
    keystone role-create --name ResellerAdmin 2>/dev/null || true

    keystone user-role-add --role SwiftOperator --user demo --tenant demo 2>/dev/null || true
    keystone user-role-add --role anotherrole --user demo --tenant demo 2>/dev/null || true
    keystone user-role-add --role admin --user admin --tenant demo 2>/dev/null || true

    message "Create flavor 'm1.tempest-nano' for Tempest tests"
    nova flavor-create m1.tempest-nano 0 64 0 1 2>/dev/null || true
    message "Create flavor 'm1.tempest-micro' for Tempest tests"
    nova flavor-create m1.tempest-micro 42 128 0 1 2>/dev/null || true

   local cirros_image="$(glance image-list 2>/dev/null | grep cirros-${CIRROS_VERSION}-x86_64)"
     if [ ! "${cirros_image}" ]; then
       # scp ${VIRTUALENV_DIR}/files/cirros-${CIRROS_VERSION}-x86_64-disk.img ${USER_NAME}:/tmp/cirros-${CIRROS_VERSION}-x86_64-disk.img
       # ssh ${USER_NAME} "scp /tmp/cirros-${CIRROS_VERSION}-x86_64-disk.img ${CONTROLLER_HOST}:/tmp/"
         if [ $(echo $FUEL_RELEASE | awk -F'.' '{print $1}') -ge "8" ]; then
             glance image-create --name cirros-${CIRROS_VERSION}-x86_64 --file ${VIRTUALENV_DIR}/files/cirros-${CIRROS_VERSION}-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility public --progress 2>/dev/null || true
         else
             glance image-create --name cirros-${CIRROS_VERSION}-x86_64 --file ${VIRTUALENV_DIR}/files/cirros-${CIRROS_VERSION}-x86_64-disk.img --disk-format qcow2 --container-format bare --is-public=true --progress 2>/dev/null || true
         fi
     else
         message "CirrOS image for Tempest tests already uploaded!"
     fi

}
init_some_config_options() {

    IS_NEUTRON_AVAILABLE=$(check_service_availability "neutron")
    if [ "${IS_NEUTRON_AVAILABLE}" = "true" ]; then
        PUBLIC_NETWORK_ID="$(neutron net-list --router:external=true -f csv -c id --quote none 2>/dev/null | tail -1)"
        PUBLIC_ROUTER_ID="$(neutron router-list --external_gateway_info:network_id=${PUBLIC_NETWORK_ID} -F id -f csv --quote none 2>/dev/null | tail -1)"
         message "tests"
    fi

    IMAGE_REF="$(glance image-list 2>/dev/null | grep cirros-${CIRROS_VERSION}-x86_64 | awk '{print $2}')"
    IMAGE_REF_ALT="$(glance image-list 2>/dev/null | grep TestVM | awk '{print $2}')"
    ADMIN_TENANT_ID="$(keystone tenant-list 2>/dev/null | grep admin | awk '{print $2}')"

   # OS_EC2_URL="$(keystone catalog --service ec2 2>/dev/null | grep publicURL | awk '{print $4}')"
   # OS_S3_URL="$(keystone catalog --service s3 2>/dev/null | grep publicURL | awk '{print $4}')"
    message "${IMAGE_REF}"
    
    ATTACH_ENCRYPTED_VOLUME="true"
    VOLUMES_STORAGE_PROTOCOL="iSCSI"
    VOLUMES_BACKUP="false"

   # local volume_driver="$(ssh ${CONTROLLER_HOST} "cat /etc/cinder/cinder.conf | grep volume_driver" 2>/dev/null)"
   # if [ "$(echo ${volume_driver} | grep -o RBDDriver)" ]; then
   #     ATTACH_ENCRYPTED_VOLUME="false"
   #     VOLUMES_STORAGE_PROTOCOL="ceph"
        # In MOS 7.0 volumes backup works only if the volumes storage protocol is Ceph
   #     VOLUMES_BACKUP="true"
   # fi


}

create_config_file() {
    local tempest_conf="${DEST}/$1/etc/tempest.conf"
    resource_create
    if [ -f ${tempest_conf} ]; then
        message "Tempest config file already exists!"
    else
        message "Configuring Tempest"
        init_some_config_options
        cat > ${tempest_conf} <<EOF
[DEFAULT]
debug = True
log_file = tempest.log
use_stderr = False
lock_path = /tmp

[compute]
fixed_network_name = private
ssh_connect_method = fixed
flavor_ref_alt = 2
flavor_ref = 1
image_alt_ssh_user = cirros
image_ref_alt = ${IMAGE_REF}
image_ssh_user = cirros
image_ref = ${IMAGE_REF}
ssh_timeout = 196
ip_version_for_ssh = 4
network_for_ssh = private
ssh_user = cirros
allow_tenant_isolation = True
build_timeout = 196

[volume]
build_timeout = 196

[boto]
http_socket_timeout = 5
build_timeout = 196

[identity]
auth_version = v2
admin_domain_name = Default
admin_tenant_id = ${ADMIN_TENANT_ID}
admin_tenant_name = admin
admin_password = admin
admin_username = admin
alt_tenant_name = demo
alt_password = demo
alt_username = demo
tenant_name = demo
password = demo
username = demo
uri_v3 = http://10.0.2.15:5000/v3/
uri =${OS_AUTH_URL}

[identity-feature-enabled]
xml_api = True

[auth]
tempest_roles = anotherrole

[compute-feature-enabled]
ec2_api = False
xml_api_v2 = True
api_extensions = NMN, OS-DCF, OS-EXT-AZ, OS-EXT-IMG-SIZE, OS-EXT-IPS, OS-EXT-IPS-MAC, OS-EXT-SRV-ATTR, OS-EXT-STS, OS-EXT-VIF-NET, OS-FLV-DISABLED, OS-FLV-EXT-DATA, OS-SCH-HNT, OS-SRV-USG, os-admin-actions, os-agents, os-aggregates, os-assisted-volume-snapshots, os-attach-interfaces, os-availability-zone, os-baremetal-ext-status, os-baremetal-nodes, os-block-device-mapping-v2-boot, os-cell-capacities, os-cells, os-certificates, os-cloudpipe, os-cloudpipe-update, os-config-drive, os-console-auth-tokens, os-console-output, os-consoles, os-create-server-ext, os-deferred-delete, os-evacuate, os-extended-evacuate-find-host, os-extended-floating-ips, os-extended-hypervisors, os-extended-networks, os-extended-quotas, os-extended-rescue-with-image, os-extended-services, os-extended-services-delete, os-extended-volumes, os-fixed-ips, os-flavor-access, os-flavor-extra-specs, os-flavor-manage, os-flavor-rxtx, os-flavor-swap, os-floating-ip-dns, os-floating-ip-pools, os-floating-ips, os-floating-ips-bulk, os-fping, os-hide-server-addresses, os-hosts, os-hypervisor-status, os-hypervisors, os-instance-actions, os-instance_usage_audit_log, os-keypairs, os-migrations, os-multiple-create, os-networks, os-networks-associate, os-preserve-ephemeral-rebuild, os-quota-class-sets, os-quota-sets, os-rescue, os-security-group-default-rules, os-security-groups, os-server-diagnostics, os-server-external-events, os-server-group-quotas, os-server-groups, os-server-list-multi-status, os-server-password, os-server-start-stop, os-services, os-shelve, os-simple-tenant-usage, os-tenant-networks, os-used-limits, os-used-limits-for-admin, os-user-data, os-user-quotas, os-virtual-interfaces, os-volume-attachment-update, os-volumes
block_migration_for_live_migration = False
change_password = False
live_migration = False
resize = True

[compute-feature-disabled]
api_extensions =

[compute-admin]
tenant_name = admin
password = admin
username = admin

[network]
default_network = 10.0.0.0/24
public_router_id =
public_network_id = ${PUBLIC_NETWORK_ID}
tenant_networks_reachable = false
api_version = 2.0


[network-feature-enabled]
xml_api = True
api_extensions = agent, allowed-address-pairs, binding, dhcp_agent_scheduler, dvr, ext-gw-mode, external-net, extra_dhcp_opt, extraroute, fwaas, l3-ha, l3_agent_scheduler, lbaas, lbaas_agent_scheduler, metering, multi-provider, provider, quotas, router, security-group, service-type, vpnaas
ipv6_subnet_attributes = True
ipv6 = True

[network-feature-disabled]
api_extensions =

[orchestration]
build_timeout = 900
instance_type = m1.heat
image_ref = Fedora-x86_64-20-20140618-sda

[scenario]
large_ops_number = 1
aki_img_file = cirros-0.3.2-x86_64-vmlinuz
ari_img_file = cirros-0.3.2-x86_64-initrd
ami_img_file = cirros-0.3.2-x86_64-blank.img
img_dir =/home/${USER_NAME}/tcl-tempest-runner/.venv/files/

[input-scenario]
flavor-regex = ^m1.tempest-nano$

[telemetry]
too_slow_to_test = False

[object-storage-feature-enabled]
discoverable_apis = account_quotas, bulk_delete, bulk_upload, container_quotas, container_sync, crossdomain, formpost, keystoneauth, ratelimit, slo, staticweb, tempauth, tempurl

[object-storage-feature-disabled]
discoverable_apis =

[volume-feature-enabled]
backup = False
api_extensions = OS-SCH-HNT, backups, cgsnapshots, consistencygroups, encryption, os-admin-actions, os-availability-zone, os-extended-services, os-extended-snapshot-attributes, os-hosts, os-image-create, os-quota-class-sets, os-quota-sets, os-services, os-snapshot-actions, os-types-extra-specs, os-types-manage, os-used-limits, os-vol-host-attr, os-vol-image-meta, os-vol-mig-status-attr, os-vol-tenant-attr, os-volume-actions, os-volume-encryption-metadata, os-volume-manage, os-volume-replication, os-volume-transfer, os-volume-unmanage, qos-specs, scheduler-stats

[volume-feature-disabled]
api_extensions =

[dashboard]
login_url = http://10.21.2.3/auth/login/
dashboard_url =http://${OS_PUBLIC_IP}

[cli]
cli_dir = /usr/local/bin

[service_available]
neutron = ${IS_NEUTRON_AVAILABLE}
heat = $(check_service_availability "heat")
ceilometer = $(check_service_availability "ceilometer")
swift = $(check_service_availability "swift")
cinder = $(check_service_availability "cinder")
nova = $(check_service_availability "nova")
glance = $(check_service_availability "glance")
horizon = $(check_service_availability "horizon")

EOF
    fi

    export TEMPEST_CONFIG_DIR="$(dirname "${tempest_conf}")"
    export TEMPEST_CONFIG="$(basename "${tempest_conf}")"

    message "Tempest config file:"
    cat ${tempest_conf}
    message "You can override the config options in ${tempest_conf}"
}

create_config_file "$@"
