#!/bin/bash
set -x
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export REPLPASSWORD=`cat /root/.default.password`
export APPS_DOMAIN=`ssh root@master1.example.com 'grep subdomain /etc/origin/master/master-config.yaml | cut -d \" -f 2'`
export MASTER_URL=`ssh root@master1.example.com "grep -E ^masterPublic /etc/origin/master/master-config.yaml | cut -d ' ' -f 2"`

# master
#ssh root@master1.example.com "htpasswd -b /etc/origin/openshift-passwd admin ${REPLPASSWORD}"
oc adm policy add-cluster-role-to-user cluster-admin admin1
oc adm policy add-cluster-role-to-user cluster-admin admin2
oc adm policy add-cluster-role-to-user cluster-admin karla

# infra
ssh root@infranode1.example.com "
mkdir -p /var/{gitlab/vol1,gitlab/vol2,nexus,postgres,redis}
chmod -R 777 /var/gitlab
chown -R 200:200 /var/nexus
chown -R 26:26 /var/postgres
chmod -R 777 /var/redis
chcon -R system_u:object_r:svirt_sandbox_file_t:s0 /var/{gitlab,nexus,postgres,redis}
"

# provisionerq
# make sure we're in the default project -- just in case
oc project default
oc run workshop-provisioner --restart=Never \
--env="ADMINUSER=admin" --env="ADMINPASSWORD=${REPLPASSWORD}" --env="APPS_DOMAIN=${APPS_DOMAIN}" \
--env="MASTER_URL=${MASTER_URL}" --env="NUMUSERS=5" --image=openshiftdemos/workshop-provisioner:latest
