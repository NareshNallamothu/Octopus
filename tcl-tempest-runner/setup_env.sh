#!/bin/bash -xe

TOP_DIR=$(cd $(dirname "$0") && pwd)
USER_NAME=$1
source ${TOP_DIR}/helpers/init_env_variables.sh

install_system_requirements() {
   # message "Enable default CentOS repo"
   # yum -y reinstall centos-release

    message "Installing system requirements"
  apt-get -y install git
  apt-get -y install gcc
  apt-get -y install zlib1g-dev
    apt-get -y install libreadline-dev
    apt-get -y install libbz2-dev
    apt-get -y install libgcrypt11-dev
    apt-get -y install libssl-dev
    apt-get -y install libffi-dev
    apt-get -y install libxml2-dev
    apt-get -y install libxslt-dev
    apt-get -y install python-dev
}

install_python27_pip_virtualenv() {
    message "Installing Python 2.7"
    if command -v python2.7 &>/dev/null; then
        message "Python 2.7 already installed!"
    else
        local temp_dir="$(mktemp -d)"
        cd ${temp_dir}
        wget ${PYTHON_LOCATION}
        tar xzf Python-${PYTHON_VERSION}.tgz
        cd Python-${PYTHON_VERSION}
        ./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"
        make -j5 altinstall
    fi

    message "Installing Pip 2.7"
    if command -v pip2.7 &>/dev/null; then
        message "Pip 2.7 already installed!"
    else
        message "Installing pip for Python 2.7"
        local get_pip_file="$(mktemp)"
        wget -O ${get_pip_file} ${PIP_LOCATION}
        python2.7 ${get_pip_file}
        pip2.7 install -U tox
    fi

    message "Installing virtualenv"
    if command -v virtualenv &>/dev/null; then
        message "virtualenv already installed!"
    else
        message "Installing virtualenv for Python 2.7"
        pip2.7 install virtualenv
    fi
}

init_cluster_variables() {
    message "Initialize cluster variables"
   local  env_id="$( ssh $1 "fuel env | grep $2  | awk '{print \$1}'")"

   message "${env_id}"

  local controller_ip="$(ssh $1 "fuel --env-id $env_id  node list | grep controller | awk '{print \$10}' | head -1")"

  message "$controller_ip"

 
  #  local controller_host_id="$(fuel node "$@" | grep controller | awk '{print $1}' | head -1)"
    CONTROLLER_HOST=${controller_ip}
    message "Controller host is '${CONTROLLER_HOST}'"
local compute_ip="$(ssh $1 "fuel --env-id $env_id  node list | grep compute | awk '{print \$10}'")"

   # local compute_host_id="$(fuel node "$@" | grep compute | awk '{print $1}' | head -1)"
    COMPUTE_HOST=${compute_ip}
    message "Compute host is '${COMPUTE_HOST}'"

    FUEL_RELEASE="$(ssh $1 'fuel --fuel-version 2>&1 | grep -e ^release:' | awk '{print $2}' | sed "s/'//g")"
    message "Fuel release is ${FUEL_RELEASE}"

   OS_PUBLIC_AUTH_URL="$(ssh $1 "ssh ${controller_ip} '. openrc; keystone catalog --service identity 2>/dev/null | grep publicURL'" | awk '{print $4}')"
   OS_PUBLIC_IP="$(ssh $1 "ssh ${controller_ip} 'grep -w public_vip /etc/hiera/globals.yaml'" | awk '{print $2}' | sed 's/\"//g')"
  

   # OS_PUBLIC_AUTH_URL="$(ssh ${CONTROLLER_HOST} ". openrc; keystone catalog --service identity 2>/dev/null | grep publicURL | awk '{print \$4}'")"
   # OS_PUBLIC_IP="$(ssh ${CONTROLLER_HOST} "grep -w public_vip /etc/hiera/globals.yaml | awk '{print \$2}' | sed 's/\"//g'")"
    message "OS_PUBLIC_AUTH_URL = ${OS_PUBLIC_AUTH_URL}"
    message "OS_PUBLIC_IP = ${OS_PUBLIC_IP}"

    local htts_public_endpoint="$(ssh $1 "ssh ${controller_ip} '. openrc; keystone catalog --service identity 2>/dev/null | grep https'")"
    if [ "${htts_public_endpoint}" ]; then
        TLS_ENABLED="yes"
        message "TLS_ENABLED = yes"
    else
        TLS_ENABLED="no"
        message "TLS_ENABLED = no"
    fi
}

configure_env() {
    message "Create and configure environment"
   USER_NAME=$1
#sh $1 "ssh ${controller_ip} 'grep -w public_vip /etc/hiera/globals.yaml'" | awk '{print $1}' | sed 's/\"//g')"
    id -u ${USER_NAME} &>/dev/null || sudo adduser ${USER_NAME} sudo 
    grep nofile /etc/security/limits.conf || echo '* soft nofile 50000' >> /etc/security/limits.conf ; echo '* hard nofile 50000' >> /etc/security/limits.conf

    mkdir -p ${DEST}

    # SSH
    cp -r /root/.ssh ${USER_HOME_DIR}
    echo "User root" >> ${USER_HOME_DIR}/.ssh/config

    # bashrc
    cat > ${USER_HOME_DIR}/.bashrc <<EOF
test "\${PS1}" || return
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
alias ls=ls\ --color=auto
alias ll=ls\ --color=auto\ -lhap
echo \${PATH} | grep ":\${HOME}/bin" >/dev/null || export PATH="\${PATH}:\${HOME}/bin"
if [ \$(id -u) -eq 0 ]; then
    export PS1='\[\033[01;41m\]\u@\h:\[\033[01;44m\] \W \[\033[01;41m\] #\[\033[0m\] '
else
    export PS1='\[\033[01;33m\]\u@\h\[\033[01;0m\]:\[\033[01;34m\]\W\[\033[01;0m\]$ '
fi
cd ${DEST}
source ${VIRTUALENV_DIR}/bin/activate
source ${USER_HOME_DIR}/openrc-$2
EOF

    # vimrc
    cat > ${USER_HOME_DIR}/.vimrc <<EOF
filetype plugin indent off
syntax on

set nowrap
set nocompatible
set expandtab
set tabstop=4
set shiftwidth=4
set smarttab
set et
set wrap
set showmatch
set hlsearch
set incsearch
set ignorecase
set lz
set listchars=tab:··
set list
set ffs=unix,dos,mac
set fencs=utf-8,cp1251,koi8-r,ucs-2,cp866
EOF

    # openrc
#    scp ${CONTROLLER_HOST}:/root/openrc ${USER_HOME_DIR}/openrc
    ssh $1 "scp ${CONTROLLER_HOST}:/root/openrc /tmp/openrc-$2"
    scp $1:/tmp/openrc-$2 ${USER_HOME_DIR}/openrc-$2
    sed -i "/LC_ALL.*/d" ${USER_HOME_DIR}/openrc-$2
    sed -i "/OS_AUTH_URL.*/d" ${USER_HOME_DIR}/openrc-$2
    sed -i "s/internalURL/publicURL/g" ${USER_HOME_DIR}/openrc-$2
    echo "export FUEL_RELEASE='${FUEL_RELEASE}'" >> ${USER_HOME_DIR}/openrc-$2
    echo "export CONTROLLER_HOST='${CONTROLLER_HOST}'" >> ${USER_HOME_DIR}/openrc-$2
    echo "export COMPUTE_HOST='${COMPUTE_HOST}'" >> ${USER_HOME_DIR}/openrc-$2
    echo "export OS_AUTH_URL='${OS_PUBLIC_AUTH_URL}'" >> ${USER_HOME_DIR}/openrc-$2
    echo "export OS_PUBLIC_IP='${OS_PUBLIC_IP}'" >> ${USER_HOME_DIR}/openrc-$2
    echo "export USER_NAME='${USER_NAME}'" >> ${USER_HOME_DIR}/openrc-$2
    if [ "${TLS_ENABLED}" = "yes" ]; then
        ssh $1 "scp ${CONTROLLER_HOST}:${REMOTE_CA_CERT} /tmp/${LOCAL_CA_CERT}"
        scp $1:/tmp/${LOCAL_CA_CERT} ${USER_HOME_DIR}/${LOCAL_CA_CERT}
        
        echo "export OS_CACERT='${USER_HOME_DIR}/${LOCAL_CA_CERT}'" >> ${USER_HOME_DIR}/openrc-$2
    fi

    chown -R ${USER_NAME} ${USER_HOME_DIR}
}

setup_virtualenv() {
    message "Setup virtualenv in ${VIRTUALENV_DIR}"
    virtualenv -p python2.7 ${VIRTUALENV_DIR}
}

install_tempest() {
    message "Installing Tempest into ${DEST}"

    cd ${DEST}
    local tempest_dir="${DEST}/tempest"
#    rm -rf ${tempest_dir}
   if [ ! -d ${tempest_dir}];then
       git clone git://git.openstack.org/openstack/tempest.git
   fi
    cd ${tempest_dir}
    if [ "${TEMPEST_COMMIT_ID}" != "master" ]; then
        git checkout ${TEMPEST_COMMIT_ID}
    fi

    ${VIRTUALENV_DIR}/bin/pip install -U -r ${tempest_dir}/requirements.txt
    message "Tempest has been installed into ${tempest_dir}"
    ${VIRTUALENV_DIR}/bin/pip install  ${tempest_dir}/

    cp ${TOP_DIR}/tempest/configure_tempest.sh ${VIRTUALENV_DIR}/bin/configure_tempest
    cp ${TOP_DIR}/tempest/configure_shouldfail_file.sh ${VIRTUALENV_DIR}/bin/configure_shouldfail_file
    cp ${TOP_DIR}/tempest/run_tests.sh ${VIRTUALENV_DIR}/bin/run_tests
    cp -r ${TOP_DIR}/shouldfail ${DEST}
    cd ${DEST}
    mkdir -p  env-$2
    cd env-$2
    #mkdir -p ${TEMPEST_REPORTS_DIR}

    message "Downloading necessary resources for Tempest"
    local tempest_files="${VIRTUALENV_DIR}/files"
    #rm -rf ${tempest_files}
    if [ ! -d ${tempest_files} ];then
        mkdir ${tempest_files}  
    fi
    #mkdir ${tempest_files}
    wget -O ${tempest_files}/cirros-${CIRROS_VERSION}-x86_64-uec.tar.gz ${CIRROS_UEC_IMAGE_URL}
    wget -O ${tempest_files}/cirros-${CIRROS_VERSION}-x86_64-disk.img ${CIRROS_DISK_IMAGE_URL}
    cd ${tempest_files}
    tar xzf cirros-${CIRROS_VERSION}-x86_64-uec.tar.gz

    chown -R ${USER_NAME} ${DEST}
}

install_helpers() {
    message "Installing helpers"
    cp ${TOP_DIR}/helpers/init_env_variables.sh ${VIRTUALENV_DIR}/bin/
    cp ${TOP_DIR}/helpers/subunit_shouldfail_filter.py ${VIRTUALENV_DIR}/bin/subunit-shouldfail-filter
    cp ${TOP_DIR}/helpers/subunit_html.py ${VIRTUALENV_DIR}/bin/subunit-html
    cp ${TOP_DIR}/helpers/colorizer.py ${VIRTUALENV_DIR}/bin/colorizer
    ${VIRTUALENV_DIR}/bin/pip install -U -r ${TOP_DIR}/requirements.txt
}

add_public_bind_to_keystone_haproxy_conf_for_admin_port() {
    # Keystone operations require admin endpoint which is internal and not
    # accessible from the Fuel master node. So we need to make Keystone admin
    # endpoint accessible from the Fuel master node. Before we do it, we need
    # to make haproxy listen to Keystone admin port 35357 on interface with public IP
    message "Add public bind to Keystone haproxy config for admin port on all controllers"
    if [ ! "$(ssh $1 "ssh ${CONTROLLER_HOST} 'grep ${OS_PUBLIC_IP}:35357 ${KEYSTONE_HAPROXY_CONFIG_PATH}')")" ]; then
        local  env_id="$( ssh $1 "fuel env | grep $2  | awk '{print \$1}'")"
        local controller_node_ids="$(ssh $1 "fuel --env-id $env_id  node list | grep controller | awk '{print \$10}' | head -1")"
       # local controller_node_ids=$(ssh $1 "(fuel node | grep controller | awk '{print \$1}')")
        local bind_string="  bind ${OS_PUBLIC_IP}:35357"
        if [ "${TLS_ENABLED}" = "yes" ]; then
            bind_string="  bind ${OS_PUBLIC_IP}:35357 ssl crt ${REMOTE_CA_CERT}"
        fi
      #  for controller_node_id in ${controller_node_ids}; do
            ssh $1 "ssh ${controller_node_ids} 'echo ${bind_string} >> ${KEYSTONE_HAPROXY_CONFIG_PATH}' "
       # done
            
        message "Restart haproxy"
        ssh $1 "ssh ${CONTROLLER_HOST} 'pcs resource disable p_haproxy --wait' "
        ssh $1 "ssh ${CONTROLLER_HOST} 'pcs resource enable p_haproxy --wait' "
    else
        message "Public bind already exists!"
    fi
}

add_dns_entry_for_tls () {
    message "Adding DNS entry for TLS"
    if [ "${TLS_ENABLED}" = "yes" ]; then
        local os_tls_hostname="$(echo ${OS_PUBLIC_AUTH_URL} | sed 's/https:\/\///;s|:.*||')"
        local dns_entry=$(ssh $1 "grep '${OS_PUBLIC_IP} ${os_tls_hostname}' /etc/hosts)")
        if [ ! "${dns_entry}" ]; then
            echo "${OS_PUBLIC_IP} ${os_tls_hostname}" >> /etc/hosts
        else
            message "DNS entry for TLS is already added!"
        fi
    else
        message "TLS is not enabled. Nothing to do"
    fi
}

prepare_cloud() {
    # Keystone operations require admin endpoint which is internal and not
    # accessible from the Fuel master node. So we need to make all Keystone
    # endpoints accessible from the Fuel master node
    message "Make Keystone endpoints public"
   # local identity_service_id="$(remote_cli "keystone service-list 2>/dev/null | grep identity | awk '{print \$2}'")"
   # local controller_ip="$(ssh $1 "fuel --env-id $env_id  node list | grep controller | awk '{print \$10}'")"
    local identity_service_id="$(ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone service-list  2>/dev/null | grep identity'" | awk '{print $2}')"
    local internal_url="$(ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone endpoint-list  2>/dev/null | grep ${identity_service_id}'" | awk '{print $8}')"
   local admin_url="$(ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone endpoint-list  2>/dev/null | grep ${identity_service_id}'" | awk '{print $10}')"

   # local internal_url="$(remote_cli "keystone endpoint-list 2>/dev/null | grep ${identity_service_id} | awk '{print \$8}'")"
   # local admin_url="$(remote_cli "keystone endpoint-list 2>/dev/null | grep ${identity_service_id} | awk '{print \$10}'")"
    if [ "${admin_url}" = "${OS_PUBLIC_AUTH_URL/5000/35357}" ]; then
        message "Keystone endpoints already public!"
    else
       local old_endpoint="$(ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone endpoint-list  2>/dev/null | grep ${identity_service_id}'" | awk '{print $2}')"
       ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone endpoint-create --region RegionOne --service ${identity_service_id} --publicurl ${OS_PUBLIC_AUTH_URL} --adminurl ${OS_PUBLIC_AUTH_URL/5000/35357} --internalurl ${internal_url}  2>/dev/null' "
      ssh $1 "ssh ${CONTROLLER_HOST} '. openrc; keystone endpoint-delete ${old_endpoint} 2>/dev/null' "
    fi

    message "Create needed tenant and roles for Tempest tests"
   # remote_cli "keystone tenant-create --name demo 2>/dev/null || true"
   # remote_cli "keystone user-create --tenant demo --name demo --pass demo 2>/dev/null || true"

   # remote_cli "keystone role-create --name SwiftOperator 2>/dev/null || true"
   # remote_cli "keystone role-create --name anotherrole 2>/dev/null || true"
   # remote_cli "keystone role-create --name heat_stack_user 2>/dev/null || true"
   # remote_cli "keystone role-create --name heat_stack_owner 2>/dev/null || true"
   # remote_cli "keystone role-create --name ResellerAdmin 2>/dev/null || true"

   # remote_cli "keystone user-role-add --role SwiftOperator --user demo --tenant demo 2>/dev/null || true"
   # remote_cli "keystone user-role-add --role anotherrole --user demo --tenant demo 2>/dev/null || true"
   # remote_cli "keystone user-role-add --role admin --user admin --tenant demo 2>/dev/null || true"

    message "Create flavor 'm1.tempest-nano' for Tempest tests"
    #remote_cli "nova flavor-create m1.tempest-nano 0 64 0 1 2>/dev/null || true"
    message "Create flavor 'm1.tempest-micro' for Tempest tests"
    #remote_cli "nova flavor-create m1.tempest-micro 42 128 0 1 2>/dev/null || true"

    message "Upload CirrOS image for Tempest tests"
    #local cirros_image="$(remote_cli "glance image-list 2>/dev/null | grep cirros-${CIRROS_VERSION}-x86_64")"
   # if [ ! "${cirros_image}" ]; then
    #    scp ${VIRTUALENV_DIR}/files/cirros-${CIRROS_VERSION}-x86_64-disk.img ${CONTROLLER_HOST}:/tmp/
    #    if [ $(echo $FUEL_RELEASE | awk -F'.' '{print $1}') -ge "8" ]; then
    #        remote_cli "glance image-create --name cirros-${CIRROS_VERSION}-x86_64 --file /tmp/cirros-${CIRROS_VERSION}-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility public --progress 2>/dev/null || true"
    #    else
    #        remote_cli "glance image-create --name cirros-${CIRROS_VERSION}-x86_64 --file /tmp/cirros-${CIRROS_VERSION}-x86_64-disk.img --disk-format qcow2 --container-format bare --is-public=true --progress 2>/dev/null || true"
    #    fi
   # else
    #    message "CirrOS image for Tempest tests already uploaded!"
   # fi
}

main() {
    install_system_requirements
    install_python27_pip_virtualenv
    init_cluster_variables "$@"
    configure_env "$@"
    setup_virtualenv
    install_tempest "$@"
    install_helpers
    add_public_bind_to_keystone_haproxy_conf_for_admin_port "$@"
    add_dns_entry_for_tls
    prepare_cloud "$@"
}

main "$@"
