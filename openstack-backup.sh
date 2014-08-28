#!/bin/sh
THISHOST="`hostname | cut -f 1 -d .`"

help_msg() {
    echo -e "Usage: $0 [ OPTIONS ]
    -c [ controller | compute | neutron | heat | keystone | dashboard | mysql | mongodb | nova | cinder | swift | haproxy | rabbitmq ]
    -e clean # THIS WILL WIPE OUT THE BACKUP DIR"
}

bak_dir() {
    BAKDIR="/tmp/${THISHOST}/backup-${OSP_COMPONENT}"
    if [ ! -d ${BAKDIR} ] ; then
      mkdir -p ${BAKDIR}
    fi
}

check_type() {
CHECK=$1
if [[ -d ${CHECK} ]]; then
    VALID=1
    mkdir -p ${BAKDIR}/${PASSED}
elif [[ -f ${CHECK} ]]; then
    VALID=1
    FILEDIR="`dirname ${CHECK}`"
    mkdir -p ${BAKDIR}/${FILEDIR}
else
    VALID=0
    echo "Skipping, ${CHECK} does not exist"
fi
}

rsync_cmd() {
  SOURCE="$1"
  TARGET="$2"
  check_type ${SOURCE}
  if [ "${VALID}" == "1" ] ; then
    rsync -rav --progress --exclude='**/.git' /${SOURCE} ${TARGET}
  fi
}

bak_rpm_requirements() {
    yum -y install sos git
}

bak_this() {
    for BAKFILE in ${FILES[@]} ; do
      rsync_cmd ${BAKFILE} ${BAKDIR}/${BAKFILE}
    done
    bak_defaults
}

bak_network_conf() {
    for BAKFILE in `ls /etc/sysconfig/network-scripts/ifcfg-*` ; do
      rsync_cmd ${BAKFILE} ${BAKDIR}/${BAKFILE}
    done
}

bak_defaults() {
    bak_network_conf
    rpm -qa --queryformat '%{installtime} %{name}-%{version}-%{release}.%{arch} %{installtime:date}\n' | sort -n > /etc/installed-rpms.txt
    rsync_cmd /etc/installed-rpms.txt ${BAKDIR}/etc/installed-rpms.txt
}

bak_other() {
    FILES=(  /usr/local/bin/ /etc/security/limits.conf /etc/sysconfig/iptables /etc/sysconfig/network )
    bak_this
}

bak_neutron() {
    FILES=( /etc/neutron/ /etc/openvswitch/ )
    bak_this
    bak_other
}

bak_haproxy() {
    FILES=( /usr/local/bin/ /etc/firewalld/ /etc/haproxy/ )
    bak_this
    bak_other
}

bak_keystone() {
    FILES=( /etc/keystone/ )
    bak_this
    bak_other
}

bak_cinder() {
    FILES=( /etc/cinder/ )
    bak_this
    bak_other
}

bak_trove() {
    FILES=( /etc/trove/ )
    bak_this
    bak_other
}

bak_rabbitmq() {
    FILES=( /etc/rabbitmq/ )
    bak_this
    bak_other
}

bak_nova() {
    FILES=( /etc/nova/ )
    bak_this
    bak_other
}

bak_mysql() {
    FILES=( /etc/my.cnf /etc/my.cnf.d/ )
    bak_this
    bak_other
}

bak_mongodb() {
    FILES=( /etc/mongodb.conf )
    bak_this
    bak_other
}

bak_swift() {
    FILES=( /etc/swift/ )
    bak_this
    bak_other
}

bak_dashboard() {
    FILES=( /etc/openstack-dashboard/ /etc/httpd/ )
    bak_this
    bak_other
}

bak_controller() {
  bak_cinder
  bak_swift
  bak_keystone
  bak_dashboard
  bak_rabbitmq
  bak_nova
  bak_mongodb
  bak_mysql
  bak_neutron
  bak_trove
}

bak_compute() {
  bak_nova
  bak_neutron
}

git_me() {
    cd ${BAKDIR}
    if [ ! -d ${BAKDIR}/.git ] ; then
      git init
    fi
    git add .
    git commit -m "backup script commit `date`"
}

run_backup() {
    bak_dir
    bak_rpm_requirements
    bak_network_conf
    bak_defaults
    if [ "${OSP_COMPONENT}" == "controller" ] ; then
      bak_controller
    fi
    if [ "${OSP_COMPONENT}" == "compute" ] ; then
      bak_compute
    fi
    if [ "${OSP_COMPONENT}" == "haproxy" ] ; then
      bak_haproxy
    fi
    if [ "${OSP_COMPONENT}" == "cinder" ] ; then
      bak_cinder
    fi
    if [ "${OSP_COMPONENT}" == "swift" ] ; then
      bak_swift
    fi
    if [ "${OSP_COMPONENT}" == "nova" ] ; then
      bak_nova
    fi
    if [ "${OSP_COMPONENT}" == "keystone" ] ; then
      bak_keystone
    fi
    if [ "${OSP_COMPONENT}" == "dashboard" ] ; then
      bak_dashboard
    fi
    if [ "${OSP_COMPONENT}" == "rabbitmq" ] ; then
      bak_rabbitmq
    fi
    if [ "${OSP_COMPONENT}" == "mongodb" ] ; then
      bak_mongodb
    fi
    if [ "${OSP_COMPONENT}" == "mysql" ] ; then
      bak_mysql
    fi
    if [ "${OSP_COMPONENT}" == "neutron" ] ; then
      bak_neutron
    fi
    if [ "${OSP_COMPONENT}" == "trove" ] ; then
      bak_trove
    fi
    git_me
}

clean_up() {
    if [ -d /tmp/${THISHOST} ] ; then
        rm -fR /tmp/${THISHOST}
    fi
}

run() {
  if [ "$1" == "clean" ] ; then
    clean_up
  fi
  if [ "$1" == "backup" ] ; then
    if [ -z "${OSP_COMPONENT}" ] ; then
       help_msg
       exit
    fi

    if [ "x${OSP_COMPONENT}" == "x" ] ; then
        help_msg
        exit 1
    else
        run_backup ${OSP_COMPONENT}
    fi
  fi
}

#########

while getopts ":c:e:" opt; do
  case $opt in
    c)
      OSP_COMPONENT=$OPTARG
      ;;
    e)
      RUNCMD=$OPTARG
      echo "Running: ${RUNCMD}"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ "x${RUNCMD}" != "x" ] ; then
    run ${RUNCMD}
else
    run backup
fi
