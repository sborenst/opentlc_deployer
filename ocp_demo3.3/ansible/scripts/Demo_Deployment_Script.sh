#!/bin/bash
set -x
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export REPLPASSWORD=`cat /root/.default.password`
export APPS_DOMAIN=`ssh root@master1.example.com 'grep subdomain /etc/origin/master/master-config.yaml | cut -d \" -f 2'`
export MASTER_URL=`ssh root@master1.example.com "grep -E ^masterPublic /etc/origin/master/master-config.yaml | cut -d ' ' -f 2"`

# add missing exports
for vol in 4 5 6
do
  grep -q vol$vol /etc/exports
  if [ $? != 0 ]
  then
    echo "/srv/nfs/vol$vol *(rw,root_squash,no_wdelay,sync)" >> /etc/exports
  fi
done

# reload nfs config
systemctl reload nfs

for pv in 1 2 3 4 5 6
do 
  oc delete pv vol$pv
  rm -rf /srv/nfs/vol$pv
  mkdir -p /srv/nfs/vol$pv
  chown -R nfsnobody:nfsnobody /srv/nfs/vol$pv
  chmod -R 777 /srv/nfs/vol$pv
  sleep 5
  oc create -f - <<API
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: "vol$pv"
  spec:
    capacity:
      storage: 10Gi
    accessModes:
      - ReadWriteOnce
    nfs:
      path: "/srv/nfs/vol$pv"
      server: "oselab.example.com"
      readOnly: false
API
done

# master
#ssh root@master1.example.com "htpasswd -b /etc/origin/openshift-passwd admin ${REPLPASSWORD}"
oc adm policy add-cluster-role-to-user cluster-admin admin1
oc adm policy add-cluster-role-to-user cluster-admin admin2
oc adm policy add-cluster-role-to-user cluster-admin karla

# provisionerq
# make sure we're in the default project -- just in case
oc project default
oc run workshop-provisioner-`date +%m%d%y%H%M%S` --restart=Never \
--env="ADMINUSER=admin1" --env="ADMINPASSWORD=${REPLPASSWORD}" --env="APPS_DOMAIN=${APPS_DOMAIN}" \
--env="MASTER_URL=${MASTER_URL}" --env="NUMUSERS=5" \
--env="NEXUS=TRUE" \
--env="BUILD=TRUE" \
--env="GITLAB=TRUE" \
--env="LAB=TRUE" \
--image=openshiftdemos/workshop-provisioner:0.27
