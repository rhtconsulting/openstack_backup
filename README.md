openstack_backup
================

Just a simple openstack backup script to gather all of the config files from a given system

Usage: openstack-backup.sh [ OPTIONS ]
    -c [ controller | compute | neutron | heat | keystone | dashboard | mysql | mongodb | nova | cinder | swift | haproxy | rabbitmq ]
    -e clean # THIS WILL WIPE OUT THE BACKUP DIR


Example:

Back up neutron components: 
sh openstack-backup.sh -c neutron

