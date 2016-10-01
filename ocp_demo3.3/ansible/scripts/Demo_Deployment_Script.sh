#!/bin/bash
set -x
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export REPLPASSWORD=`cat /root/.default.password`
export DOMAIN="workshops.openshift.com"

# master
#ssh root@master1.example.com "htpasswd -b /etc/origin/openshift-passwd admin ${REPLPASSWORD}"
oc adm policy add-cluster-role-to-user cluster-admin admin
oc adm policy add-cluster-role-to-user cluster-admin karla
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:default:default
# infra
ssh root@infranode1.example.com "
mkdir -p /var/{gitlab/vol1,gitlab/vol2,nexus}
chmod -R 777 /var/gitlab
chown -R 200:200 /var/nexus
chcon -R system_u:object_r:svirt_sandbox_file_t:s0 /var/nexus
chcon -R system_u:object_r:svirt_sandbox_file_t:s0 /var/gitlab
"


# provisionerq
# make sure we're in the default project -- just in case
oc project default
oc run workshop-provisioner --restart=Never \
--env="ADMINUSER=admin" --env="ADMINPASSWORD=${REPLPASSWORD}" --env="BASEDOMAIN=$GUID.${DOMAIN}" \
--env="MASTERPORT=8443" --env="NUMUSERS=5" --image=openshiftdemos/workshop-provisioner:0.14
set +x
