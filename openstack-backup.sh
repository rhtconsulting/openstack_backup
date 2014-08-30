#!/bin/bash 
#
# openstack-backup.sh - Backup OpenStack components and configuration
#
#
# AUTHORS:  Jose Simonelli, Cloud Architect, Red Hat
#		Richard Smith, Consultant, Red Hat
# 
# VERSION:  0.40 
# NOTES:    1) Tested on RHEL 6.5 / OSP 4.0,  RHEL 7RC, OSP 5.0 beta
#
#
#----------------------------------------------------------------------------------------
THISHOST="`hostname | cut -f 1 -d .`"

#-----------------------------------------------------------------------------------------
# Functions:  
#-----------------------------------------------------------------------------------------
help_msg() {
    echo -e "Usage: $0 [ OPTIONS ]
    -c [ ceilometer | controller | compute | neutron | heat | keystone | dashboard | glance | mysql | memcached | mongodb | nova | nagios | cinder | swift | haproxy | rabbitmq | qpid | trove | foreman ]
    -c all   # Backup all components
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
    mkdir -p $(dirname ${TARGET})
    rsync -a --exclude='**/.git' --exclude=cinder-volumes  --exclude=repos ${SOURCE} ${TARGET}
  fi
}

bak_rpm_requirements() {
    rpm -q sos >/dev/null || yum -y install sos
    rpm -q git >/dev/null || yum -y install git
}

bak_this() {
    for BAKFILE in ${FILES[@]} ; do
      rsync_cmd ${BAKFILE} ${BAKDIR}${BAKFILE}
    done
}

bak_network_conf() {
    for BAKFILE in `ls /etc/sysconfig/network-scripts/ifcfg-*` ; do
      rsync_cmd ${BAKFILE} ${BAKDIR}${BAKFILE}
    done
}

bak_defaults() {
    echo ">> Generating list of install rpms -> ${BAKDIR}/etc/installed-rpms.txt"
    rpm -qa --queryformat '%{installtime} %{name}-%{version}-%{release}.%{arch} %{installtime:date}\n' | sort -n > /etc/installed-rpms.txt
    rsync_cmd /etc/installed-rpms.txt ${BAKDIR}/etc/installed-rpms.txt
}

bak_other() {
    echo ">> Backing up OS shared folders... "
    FILES=(  /usr/local/bin/ /etc/pam.d/ /etc/security/ /etc/selinux/ /etc/sysconfig/ /etc/logrotate.d/ /etc/sudoers.d/ /var/lib/libvirt/  /var/lib/puppet/ /var/spool/cron/ /var/tmp/packstack/  /etc/{passwd,shadow,gshadow,group} /etc/sysctl.conf /var/lib/iscsi ) 
    bak_this
}

bak_ceilometer() {
    echo ">> Backing up Ceilometer configuration... "
    FILES=( /etc/ceilometer/ /var/lib/ceilometer/ )
    bak_this
}

bak_dashboard() {
    echo ">> Backing up Dashboard configuration... "
    FILES=( /etc/openstack-dashboard/ /etc/httpd/ /var/www/html/ /var/lib/openstack-dashboard/ )
    bak_this
}

bak_foreman() {
    echo ">> Backing up Foreman configuration... "
    FILES=( /etc/foreman/ /etc/cron.d/foreman /etc/sysconfig/foreman /usr/share/openstack-foreman-installer/bin/seeds.rb /usr/share/openstack-foreman-installer/bin/foreman_server.sh /etc/foreman-proxy/ /etc/sysconfig/foreman-proxy )
    bak_this
#
#   gem install seed_dump
#   rake db:seed:dump
}

bak_neutron() {
    echo ">> Backing up Neutron configuration... "
    FILES=( /etc/neutron/ /etc/openvswitch/ /etc/sysconfig/ /var/lib/neutron/ /var/lib/openvswitch/ )
    bak_this
}

bak_haproxy() {
    echo ">> Backing up Haproxy configuration... "
    FILES=( /usr/local/bin/ /etc/firewalld/ /etc/haproxy/ )
    bak_this
}

bak_heat() {
    echo ">> Backing up Heat configuration... "
    FILES=( /etc/heat/ /var/lib/heat/ )
    bak_this
}

bak_keystone() {
    echo ">> Backing up Keystone configuration... "
    FILES=( /etc/keystone/ /var/lib/keystone/ )
    bak_this
}

bak_cinder() {
    echo ">> Backing up Cinder configuration... "
    FILES=( /etc/cinder/ /etc/tgt/ )   # omit /var/lib/cinder for now
    bak_this
}

bak_glance () {
    echo ">> Backing up Glance configuration... "
    FILES=( /etc/glance/ /var/lib/glance/ )
    bak_this
}

bak_qpid() {
    echo ">> Backing up QPID configuration... "
    FILES=( /etc/qpidd.conf /etc/qpid/  /etc/sasl2/qpid* /var/lib/qpidd/ )
    bak_this
}

bak_rabbitmq() {
    echo ">> Backing up Rabbitmq configuration... "
    FILES=( /etc/rabbitmq/ /var/lib/rabbitmq/ )
    bak_this
}

bak_memcached () {
    echo ">> Backing up Memcached configuration... "
    FILES=( /etc/sysconfig/memcached/ )
    bak_this
}

bak_nagios () {
    echo ">> Backing up Nagios configuration... "
    FILES=( /etc/nagios/ /etc/httpd/conf.d/nagios.conf /usr/share/nagios/html/config.inc.php /var/spool/nagios/ )
    bak_this
}

bak_nova() {
    echo ">> Backing up Nova configuration... "
    FILES=( /etc/nova/ /etc/polkit-1/localauthority/50-local.d/50-nova.pkla /var/lib/nova/ /etc/sysconfig/openstack-nova-novncproxy)
    bak_this
}

bak_mysql() {
    echo ">> Backing up MySQL configuration... "
    FILES=( /etc/my.cnf /etc/mysql/ )
    bak_this

    rpm -q mysql >/dev/null || return
    mkdir -p ${BAKDIR}/mysql
    mysqldump --add-drop-table --all-databases > ${BAKDIR}/mysql/all-databases.sql
    mysqldump --add-drop-table --opt cinder    > ${BAKDIR}/mysql/cinder.sql
    mysqldump --add-drop-table --opt glance    > ${BAKDIR}/mysql/glance.sql
    mysqldump --add-drop-table --opt heat      > ${BAKDIR}/mysql/heat.sql
    mysqldump --add-drop-table --opt keystone  > ${BAKDIR}/mysql/keystone.sql
    mysqldump --add-drop-table --opt mysql     > ${BAKDIR}/mysql/mysql.sql
    mysqldump --add-drop-table --opt nova      > ${BAKDIR}/mysql/nova.sql
    mysqldump --add-drop-table --opt ovs_neutron > ${BAKDIR}/mysql/ovs_neutron.sql
}

bak_mongodb() {
    echo ">> Backing up Mongodb configuration... "
    FILES=( /etc/mongodb.conf /etc/sysconfig/mongod /var/lib/mongodb/ )
    bak_this

    rpm -q mongodb >/dev/null || return
    mkdir  -p ${BAKDIR}/mongodb/
    mongodump  -o ${BAKDIR}/mongodb/
}

bak_swift() {
    echo ">> Backing up Swift configuration... "
    FILES=( /etc/swift/ /var/lib/swift/ /etc/rsync.d/ )
    bak_this
}

bak_trove() {
    echo ">> Backing up Trove configuration... "
    FILES=( /etc/trove/ /var/lib/trove/ )
    bak_this
}

bak_controller() {
  bak_cinder
  bak_swift
  bak_keystone
  bak_dashboard
  bak_qpid
  bak_rabbitmq
  bak_nova
  bak_mongodb
  bak_mysql
  bak_neutron
}

bak_compute() {
  bak_nova
  bak_neutron
}

bak_all () {
  bak_ceilometer
  bak_cinder
  bak_dashboard
  bak_foreman
  bak_glance
  bak_haproxy
  bak_heat
  bak_keystone
  bak_memcached
  bak_mongodb
  bak_mysql
  bak_nagios
  bak_neutron
  bak_nova
  bak_qpid
  bak_rabbitmq
  bak_swift
  bak_trove
}

git_me() {
    rpm -q git >/dev/null || yum -y install git
    cd ${BAKDIR}
    if [ ! -d ${BAKDIR}/.git ] ; then
      echo ">> Creating GIT repository of ${BACKDIR} "
      git init
    fi
    echo ">> Updating GIT repository of ${BACKDIR} "
    git add .
    git commit -m "backup script commit `date`"
}

run_backup() {
    bak_dir
    bak_rpm_requirements
    bak_network_conf
    bak_defaults
    bak_other

    if [ "${OSP_COMPONENT}" == "all" ] ; then
      bak_all
    fi
    if [ "${OSP_COMPONENT}" == "ceilometer" ] ; then
      bak_ceilometer
    fi
    if [ "${OSP_COMPONENT}" == "cinder" ] ; then
      bak_cinder
    fi
    if [ "${OSP_COMPONENT}" == "controller" ] ; then
      bak_controller
    fi
    if [ "${OSP_COMPONENT}" == "compute" ] ; then
      bak_compute
    fi
    if [ "${OSP_COMPONENT}" == "dashboard" ] ; then
      bak_dashboard
    fi
    if [ "${OSP_COMPONENT}" == "glance" ] ; then
      bak_glance
    fi
    if [ "${OSP_COMPONENT}" == "haproxy" ] ; then
      bak_haproxy
    fi
    if [ "${OSP_COMPONENT}" == "heat" ] ; then
      bak_heat
    fi
    if [ "${OSP_COMPONENT}" == "keystone" ] ; then
      bak_keystone
    fi
    if [ "${OSP_COMPONENT}" == "memcached" ] ; then
      bak_memcached
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
    if [ "${OSP_COMPONENT}" == "nova" ] ; then
      bak_nova
    fi
    if [ "${OSP_COMPONENT}" == "qpid" ] ; then
      bak_qpid
    fi
    if [ "${OSP_COMPONENT}" == "rabbitmq" ] ; then
      bak_rabbitmq
    fi
    if [ "${OSP_COMPONENT}" == "swift" ] ; then
      bak_swift
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

#----------------------------------------------------------------------
# Main
#----------------------------------------------------------------------


while getopts ":c:e:a:" opt; do
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
