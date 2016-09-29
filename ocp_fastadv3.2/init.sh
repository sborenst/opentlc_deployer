#!/bin/bash
################################################################################
################################################################################
# This Script will be used to deploy the OSE_FastAdv and OSE_Demo blueprints
# This is a temporary method until we do this properly with Ansible playbooks.
# Steps in the scripts are:
## Step 0 - Define variables for deployment.
## Step 1 - Prepare environment and test that all hosts are up
## Step 2 - Install OpenShift
## Step 3 - Configure OpenShift (Namespaces, router and registry)
## Step 4 - Post-Configure OpenShift (Metrics, Logging)
## Step 5 - Demo content deployment
################################################################################
################################################################################


################################################################################
## Step 0 - Define variables for deployment.
################################################################################
#OPENTLC VARS
export LOGFILE="/root/.oselab.log"
export USER=$1
#export USER="shacharb-redhat.com"
export COURSE=$2;
#export COURSE="ocp_fastadv3.3"
export NFS="TRUE"
export DNS="TRUE"
export IDM="TRUE"
export LOGGING="TRUE"
export METRICS="TRUE"

#Common SCRIPT VARS
export DATE=`date`;
export REPOVERSION="3.3"
export VERSION="3.3"
export SCRIPTVERSION='1.1';
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export guid=`hostname|cut -f2 -d-|cut -f1 -d.`

export REPLPASSWORD=`cat /root/.default.password`
echo "REPLPASSWORD IS: "${REPLPASSWORD}  | tee -a $LOGFILE
#ENVIRONMENT VARS, these can be overwritten in the next step, for demos or labs.
#export ALLNODES="node1.example.com node2.example.com node3.example.com infranode1.example.com"
#export ALLMASTERS="master1.example.com"
#export ALLHOSTS="${ALLNODES} ${ALLMASTERS}"
#export FIRSTMASTER=`echo $ALLMASTERS | awk '{print $1}'`

echo "---- Starting Log ${DATE}"  2>&1 | tee -a $LOGFILE
echo "---- Step 0 - Define variables for deployment."  2>&1 | tee -a $LOGFILE
echo "---- Logging variables"  2>&1 | tee -a $LOGFILE
echo "-- GUID is $GUID and guid is $guid" 2>&1 | tee -a $LOGFILE
echo "-- Script VERSION ${SCRIPTVERSION}" | tee -a $LOGFILE
echo "-- Hostname is `cat /etc/hostname`"  2>&1 | tee -a $LOGFILE
echo "-- Course name is $COURSE"  2>&1 | tee -a $LOGFILE


# The Demo environment and the Lab environment only differ slightly, we are using
# this simple test to check if the course_id contains the word "demo" and set
# the deployment variables accordingly.



echo "-- install atomic-openshift-utils" 2>&1 | tee -a $LOGFILE
yum -y install atomic-openshift-utils  2>&1 | tee -a $LOGFILE

export OPENSHIFT_RELEASE=`yum info atomic-openshift.x86_64 | grep Version | awk -F': ' '{print $2}'`
echo "-- Writing /etc/ansible/hosts file" 2>&1 | tee -a $LOGFILE
cat << EOF > /etc/ansible/hosts
# Create an OSEv3 group that contains the master, nodes, etcd, and lb groups.
# The lb group lets Ansible configure HAProxy as the load balancing solution.
# Comment lb out if your load balancer is pre-configured.
timeout=60
[OSEv3:children]
masters
etcd
nodes
nfs

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
timeout=60
openshift_image_tag=v=${OPENSHIFT_RELEASE}
openshift_release=${OPENSHIFT_RELEASE}
openshift_install_examples=true


docker_version="1.10.3"
ansible_ssh_user=root
deployment_type=openshift-enterprise
#openshift_deployment_type=openshift-enterprise
# Enable cockpit
osm_use_cockpit=true
osm_cockpit_plugins=['cockpit-kubernetes']

use_cluster_metrics=true
containerized=false
openshift_master_api_port=8443
openshift_master_console_port=8443
#openshift_master_cluster_method=native

osm_cluster_network_cidr=10.1.0.0/16
openshift_portal_net=172.30.0.0/16

#openshift_master_portal_net=172.30.0.0/16

#os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'

# Native high availability cluster method with optional load balancer.
# If no lb group is defined, the installer assumes that a load balancer has
# been preconfigured. For installation the value of
# openshift_master_cluster_hostname must resolve to the load balancer
# or to one or all of the masters defined in the inventory if no load
# balancer is present.
#openshift_master_cluster_method=native
openshift_master_cluster_hostname=master1.example.com
openshift_master_cluster_public_hostname=master1-${GUID}.oslab.opentlc.com
openshift_master_default_subdomain=cloudapps-${GUID}.oslab.opentlc.com
openshift_master_overwrite_named_certificates=true

# Configure metricsPublicURL in the master config for cluster metrics
# See: https://docs.openshift.com/enterprise/latest/install_config/cluster_metrics.html
openshift_master_metrics_public_url=https://metrics.cloudapps-${GUID}.oslab.opentlc.com/hawkular/metrics

# Configure loggingPublicURL in the master config for aggregate logging
# See: https://docs.openshift.com/enterprise/latest/install_config/aggregate_logging.html
openshift_master_logging_public_url=https://kibana.cloudapps-${GUID}.oslab.opentlc.com
# Enable cluster metrics

#openshift_master_identity_providers=[{'name': 'idm', 'challenge': 'true', 'login': 'true', 'kind': 'LDAPPasswordIdentityProvider', 'attributes': {'id': ['dn'], 'email': ['mail'], 'name': ['cn'], 'preferredUsername': ['uid']}, 'bindDN': 'uid=admin,cn=users,cn=accounts,dc=example,dc=com', 'bindPassword': 'REPLPASSWORD', 'ca': '/etc/origin/master/ipa-ca.crt', 'insecure': 'false', 'url': 'ldap://idm.example.com/cn=users,cn=accounts,dc=example,dc=com?uid?sub?(memberOf=cn=ose-users,cn=groups,cn=accounts,dc=example,dc=com)'}]
#openshift_master_ldap_ca_file=/root/ca.crt

#openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/openshift-passwd'}]


# Configure additional projects
#openshift_additional_projects={'my-project': {'default_node_selector': 'label=value'}}


# default project node selector
osm_default_node_selector='region=primary'


openshift_hosted_router_selector='region=infra'
openshift_hosted_router_replicas=1
#openshift_hosted_router_certificate={"certfile": "/path/to/router.crt", "keyfile": "/path/to/router.key", "cafile": "/path/to/router-ca.crt"}
openshift_hosted_registry_selector='region=infra'
openshift_hosted_registry_replicas=1

openshift_hosted_registry_storage_kind=nfs
openshift_hosted_registry_storage_access_modes=['ReadWriteMany']
openshift_hosted_registry_storage_host=oselab.example.com
openshift_hosted_registry_storage_nfs_directory=/srv/nfs
openshift_hosted_registry_storage_nfs_options='*(rw,root_squash)'
openshift_hosted_registry_storage_volume_name=registry
openshift_hosted_registry_storage_volume_size=10Gi


openshift_hosted_metrics_storage_kind=nfs
openshift_hosted_metrics_storage_access_modes=['ReadWriteOnce']
# Not sure if metrics_storage_host exists
openshift_hosted_metrics_storage_host=oselab.example.com
openshift_hosted_metrics_storage_nfs_directory=/srv/nfs
openshift_hosted_metrics_storage_nfs_options='*(rw,root_squash)'
openshift_hosted_metrics_storage_volume_name=metrics
openshift_hosted_metrics_storage_volume_size=10Gi


[nfs]
oselab.example.com
# host group for masters
[masters]
master1.example.com

# host group for etcd
[etcd]
master1.example.com

# host group for nodes, includes region info
[nodes]
master1.example.com openshift_public_hostname="master1-${GUID}.oslab.opentlc.com" openshift_hostname="master1.example.com"
infranode1.example.com openshift_hostname="infranode1.example.com" openshift_node_labels="{'region': 'infra', 'zone': 'default', 'env': 'infra'}"
node1.example.com openshift_hostname="node1.example.com" openshift_node_labels="{'region': 'primary', 'zone': 'one', 'env': 'dev'}"
node2.example.com openshift_hostname="node2.example.com" openshift_node_labels="{'region': 'primary', 'zone': 'two', 'env': 'dev'}"
node3.example.com openshift_hostname="node3.example.com" openshift_node_labels="{'region': 'primary', 'zone': 'three', 'env': 'prod'}"
EOF

#REPLPASSWORD replaced
echo "running REPLPASSWORD replace on /etc/ansible/hosts with: ${REPLPASSWORD} " 2>&1 | tee -a $LOGFILE
sed -i "s/REPLPASSWORD/${REPLPASSWORD}/g" /etc/ansible/hosts
grep '${REPLPASSWORD}' /etc/ansible/hosts
echo "Effected lines: grep "${REPLPASSWORD}" /etc/ansible/hosts" 2>&1 | tee -a $LOGFILE
grep "${REPLPASSWORD}" /etc/ansible/hosts 2>&1 | tee -a $LOGFILE
################################################################################
## Step 1 - Prepare environemnt and test that all hosts are up
################################################################################
echo "---- Step 1 - Prepare environemnt and test that all hosts are up"  2>&1 | tee -a $LOGFILE

echo "-- Setting StrictHostKeyChecking to no on provisioning host"  2>&1 | tee -a $LOGFILE
echo StrictHostKeyChecking no >> /etc/ssh/ssh_config

echo "-- Updating /etc/motd"  2>&1 | tee -a $LOGFILE

cat << EOF > /etc/motd
###############################################################################
###############################################################################
###############################################################################
Environment Deployment In Progress : ${DATE}
DO NOT USE THIS ENVIRONMENT AT THIS POINT
DISCONNECT AND TRY AGAIN 35 MINUTES FROM THE DATE ABOVE
###############################################################################
###############################################################################
If you want, you can check out the status of the installer by using:
sudo tail -f ${LOGFILE}
###############################################################################

EOF


echo "---- Checking all hosts are up by testing that the docker service is Active"  2>&1 | tee -a $LOGFILE

### Checking all hosts are up
# Test that all the nodes are up, we are testing that the docker service is Active
  export RESULT=1
  until [ $RESULT -eq 0 ]; do
    echo "Checking hosts are up"  2>&1 | tee -a $LOGFILE
    ansible all -l masters,nodes,etcd -a "systemctl status docker" >> $LOGFILE 2>> $LOGFILE
    export RESULT=$?
  done

echo "-- Hosts are up and running the Docker Daemon"  2>&1 | tee -a $LOGFILE



echo "---- Add the Red Hat OpenShift Enterprise $REPOVERSION Repo" 2>&1 | tee -a $LOGFILE
echo "-- Adding OSE3 Repository to  /etc/yum.repos.d/open.repo" 2>&1 | tee -a $LOGFILE
# added the Repo to enable the Ravello Fix packages.
cat << EOF > /etc/yum.repos.d/open.repo
# Created by deployment script
[rhel-7-server-rpms]
name=Red Hat Enterprise Linux 7
baseurl=http://oselab.example.com/repos/${VERSION}/rhel-7-server-rpms http://www.opentlc.com/repos/ose/${VERSION}/rhel-7-server-rpms
enabled=1
gpgcheck=0

[rhel-7-server-rh-common-rpms]
name=Red Hat Enterprise Linux 7 Common
baseurl=http://oselab.example.com/repos/${VERSION}/rhel-7-server-rh-common-rpms http://www.opentlc.com/repos/ose/${VERSION}/rhel-7-server-rh-common-rpms
enabled=1
gpgcheck=0

[rhel-7-server-extras-rpms]
name=Red Hat Enterprise Linux 7 Extras
baseurl=http://oselab.example.com/repos/${VERSION}/rhel-7-server-extras-rpms http://www.opentlc.com/repos/ose/${VERSION}/rhel-7-server-extras-rpms
enabled=1
gpgcheck=0

[rhel-7-server-optional-rpms]
name=Red Hat Enterprise Linux 7 Optional
baseurl=http://oselab.example.com/repos/${VERSION}/rhel-7-server-optional-rpms http://www.opentlc.com/repos/ose/${VERSION}/rhel-7-server-optional-rpms
enabled=1
gpgcheck=0

[rhel-7-server-ose-${VERSION}-rpms]
name=Red Hat Enterprise Linux 7 OSE $VERSION
baseurl=http://oselab.example.com/repos/${VERSION}/rhel-7-server-ose-${VERSION}-rpms http://www.opentlc.com/repos/ose/${REPOVERSION}/rhel-7-server-ose-${VERSION}-rpms
enabled=1
gpgcheck=0


EOF


echo "-- Running yum clean all and yum repolist" 2>&1 | tee -a $LOGFILE

yum clean all 2>&1 | tee -a $LOGFILE
yum repolist 2>&1 | tee -a $LOGFILE

ansible all -l masters,nodes,etcd  -m copy -a "src=/etc/yum.repos.d/open.repo dest=/etc/yum.repos.d/open.repo" 2>&1 | tee -a $LOGFILE
ansible all -l masters,nodes,etcd  -a "yum clean all"
ansible all -l masters,nodes,etcd  -a "yum repolist"
echo "---- Downloading DNS Installer, NFS Installer and Demo Deployment Script"  2>&1 | tee -a $LOGFILE
mkdir -p /root/.opentlc.installer/
curl -o /root/.opentlc.installer/oselab.dns.installer.sh http://www.opentlc.com/download/${COURSE}/${SCRIPTVERSION}/oselab.dns.installer.sh 2>&1 | tee -a $LOGFILE
curl -o /root/.opentlc.installer/Demo_Deployment_Script.sh http://www.opentlc.com/download/${COURSE}/${SCRIPTVERSION}/Demo_Deployment_Script.sh 2>&1 | tee -a $LOGFILE
curl -o /root/.opentlc.installer/oselab.nfs.installer.sh http://www.opentlc.com/download/${COURSE}/${SCRIPTVERSION}/oselab.nfs.installer.sh 2>&1 | tee -a $LOGFILE
chmod +x /root/.opentlc.installer/oselab.dns.installer.sh /root/.opentlc.installer/Demo_Deployment_Script.sh /root/.opentlc.installer/oselab.nfs.installer.sh
curl -o /root/all_repos.txt http://www.opentlc.com/download/ose_common/1.1/all_repos.txt  2>&1 | tee -a $LOGFILE


if [ $NFS == "TRUE" ]
  then
echo "-- NFS set to ${NFS}, running /root/oselab.nfs.installer.sh"  2>&1 | tee -a ${LOGFILE}
nohup /root/.opentlc.installer/oselab.nfs.installer.sh 2>&1 | tee -a ${LOGFILE}
fi

if [ $DNS == "TRUE" ]
  then
echo "-- DNS set to ${DNS}, running /root/oselab.dns.installer.sh"  2>&1 | tee -a ${LOGFILE}
nohup /root/.opentlc.installer/oselab.dns.installer.sh  2>&1 | tee -a ${LOGFILE}

fi

## WORKAROUND
ansible all -m shell -a "yum -y install python; yum -y remove docker-common-1.10.3-44.el7.x86_64 docker-1.10.3-44.el7.x86_64 docker-forward-journald-1.10.3-44.el7.x86_64 docker-rhel-push-plugin-1.10.3-44.el7.x86_64 docker-selinux-1.10.3-44.el7.x86_64"
sed -i '/registry/s/^/#/' /etc/exports

################################################################################
## Step 2 - Install OpenShift
################################################################################

echo "-- Commenting out nodes according to the REMOVENODES varialbe, value is : ${REMOVENODES} - ok if blank"  2>&1 | tee -a ${LOGFILE}

echo "---- IDM set to ${IDM}, Configuring ansible file accordingly"  2>&1 | tee -a ${LOGFILE}

if [ $IDM == "TRUE" ] ; then
    echo "-- IDM is $IDM, Commenting out htpasswd_auth and Uncommenting idm auth"  2>&1 | tee -a $LOGFILE
    sed -i '/htpasswd_auth/s/^/#/' /etc/ansible/hosts
    sed -i '/idm/s/^#//' /etc/ansible/hosts
    sed -i '/openshift_master_ldap_ca_file/s/^#//' /etc/ansible/hosts
    echo "-- get ipa-ca.crt file" 2>&1 | tee -a $LOGFILE

    wget http://idm.example.com/ipa/config/ca.crt -O /root/ca.crt   2>&1 | tee -a $LOGFILE
    #ansible masters -a "mkdir -p /etc/origin/master/"   2>&1 | tee -a $LOGFILE
    #ansible masters -m copy -a "src=/root/ca.crt dest=/etc/origin/master/ipa-ca.crt" 2>&1 | tee -a $LOGFILE
    #ansible masters -a "cat  /etc/origin/master/ipa-ca.crt"   2>&1 | tee -a $LOGFILE

  else
    echo "-- IDM is $IDM, Commenting out idm and Uncommenting htpasswd_auth auth"  2>&1 | tee -a $LOGFILE
    sed -i '/idm/s/^/#/' /etc/ansible/hosts
    sed -i '/htpasswd_auth/s/^#//' /etc/ansible/hosts

    echo "--installing httpd-tools on master " 2>&1 | tee -a $LOGFILE

    yum -y install httpd-tools  2>&1 | tee -a $LOGFILE
    ansible masters -a "yum -y install httpd-tools"
    touch /tmp/openshift-passwd
    for user in ${USERS}
        do \
          echo "---- creating users: $USERS" 2>&1 | tee -a $LOGFILE
         echo htpasswd -b /tmp/openshift-passwd $user '${REPLPASSWORD} '  2>&1 | tee -a $LOGFILE
         htpasswd -b /tmp/openshift-passwd $user '${REPLPASSWORD} '  2>&1 | tee -a $LOGFILE
        done
      ansible masters -a "mkdir -p /etc/origin/master/"   2>&1 | tee -a $LOGFILE
      ansible masters -m copy -a "src=/tmp/openshift-passwd dest=/etc/origin/openshift-passwd" 2>&1 | tee -a $LOGFILE

fi

echo "-- Identity providers modified to:"  2>&1 | tee -a $LOGFILE
grep -i identity /etc/ansible/hosts   2>&1 | tee -a $LOGFILE

#### WORK AROUND

#echo '[ssh_connection]
#control_path = %(directory)s/%%h-%%r' | sudo tee -a  /etc/ansible/ansible.cfg

cd /root
export HOME="/root"
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml  2>&1 | tee -a $LOGFILE

echo "---- Ansible playbook completed running, returning $?" 2>&1 | tee -a $LOGFILE
echo "Getting system:admin /root/.kube/config file"  2>&1 | tee -a $LOGFILE
scp -r master1.example.com:/root/.kube /root/.kube  2>&1 | tee -a $LOGFILE
yum install -y atomic-openshift-clients  2>&1 | tee -a $LOGFILE

################################################################################
## Step 3 - Configure OpenShift
################################################################################
echo "---- Step 3 - Configure OpenShift"  2>&1 | tee -a $LOGFILE


echo "-- setting default namespace to use the infra region" 2>&1 | tee -a $LOGFILE
oc annotate namespace default openshift.io/node-selector='region=infra' --overwrite  2>&1 | tee -a $LOGFILE

yum install atomic-openshift -y  2>&1 | tee -a $LOGFILE
#echo "-- OPENSHIFT_RELEASE is ${OPENSHIFT_RELEASE}"  2>&1 | tee -a $LOGFILE
#oadm registry --create --service-account='registry' --images="registry.access.redhat.com/openshift3/ose-docker-registry:v${OPENSHIFT_RELEASE}"   2>&1 | tee -a $LOGFILE
#oc volume deploymentconfigs/docker-registry --add --name=registry-storage -t pvc --claim-name=registry-claim --overwrite  2>&1 | tee -a $LOGFILE

################################################################################
## Step 4 - Post-Configure OpenShift (Metrics, Logging)
################################################################################

echo "---- Step 4 - Post-Configure OpenShift (Metrics, Logging)"  2>&1 | tee -a $LOGFILE
echo "-- Get the openshift_toolkit repo to deploy METRICS and LOGGING"  2>&1 | tee -a $LOGFILE


    if [ $METRICS == "TRUE" ]
      then
        echo "Running Ansible playbook for Metrics, logs to ${LOGFILE}.metrics" | tee -a $LOGFILE
        oc project openshift-infra
        oc create -f - <<API
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: metrics-deployer
        secrets:
        - name: metrics-deployer
API

        oadm policy add-role-to-user edit system:serviceaccount:openshift-infra:metrics-deployer
        oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:openshift-infra:heapster
        oc secrets new metrics-deployer nothing=/dev/null
        oc new-app openshift/metrics-deployer-template -p HAWKULAR_METRICS_HOSTNAME=metrics.cloudapps-${GUID}.oslab.opentlc.com -p USE_PERSISTENT_STORAGE=false -p IMAGE_VERSION=3.3.0 -p IMAGE_PREFIX=registry.access.redhat.com/openshift3/

        oc project default

    fi

    echo "-- Check pods in the openshift-infra project"  2>&1 | tee -a $LOGFILE
    oc get pods -n openshift-infra  -o wide  2>&1 | tee -a $LOGFILE

    echo "-- set the current context to the default project"  2>&1 | tee -a $LOGFILE
    oc project default  2>&1 | tee -a $LOGFILE

    if [ $LOGGING == "TRUE" ]
     then
       ssh master1.example.com "oc apply -n openshift -f     /usr/share/openshift/examples/infrastructure-templates/enterprise/logging-deployer.yaml"

       oadm new-project logging --node-selector=""
       oc project logging
       oc new-app logging-deployer-account-template
       oadm policy add-cluster-role-to-user oauth-editor        system:serviceaccount:logging:logging-deployer
       oadm policy add-scc-to-user privileged      system:serviceaccount:logging:aggregated-logging-fluentd
       oadm policy add-cluster-role-to-user cluster-reader     system:serviceaccount:logging:aggregated-logging-fluentd
       oc new-app logging-deployer-template --param PUBLIC_MASTER_URL=https://master1-${GUID}.oslab.opentlc.com:8443 --param KIBANA_HOSTNAME=kibana.cloudapps-${GUID}.oslab.opentlc.com --param IMAGE_VERSION=3.3.0 --param IMAGE_PREFIX=registry.access.redhat.com/openshift3/        --param KIBANA_NODESELECTOR='region=infra' --param ES_NODESELECTOR='region=infra' --param MODE=install
       oc label nodes --all logging-infra-fluentd=true
       oc label node master1.example.com --overwrite logging-infra-fluentd=false
       oc project default

     fi




echo "-- Update /etc/motd"  2>&1 | tee -a $LOGFILE

cat << EOF > /etc/motd
###############################################################################
Environment Deployment Started      : ${DATE}
###############################################################################
###############################################################################
Environment Deployment Is Completed : `date`
###############################################################################
###############################################################################

EOF



################################################################################
## Step 5 - Demo content deployment
################################################################################
echo "---- Step 5 - Demo content deployment"  2>&1 | tee -a $LOGFILE


if [ 1 == 2 ]  ; then


    if [ $DEMO == "TRUE" ]
      then
    echo "-- Running /root/.opentlc.installer/Demo_Deployment_Script.sh"  2>&1 | tee -a $LOGFILE
    /root/.opentlc.installer/Demo_Deployment_Script.sh 2>&1 | tee -a /root/.Demo.Deployment.log
    echo "-- Finished running /root/.opentlc.installer/Demo_Deployment_Script.sh"  2>&1 | tee -a $LOGFILE
    fi

fi
echo "-- Update /etc/motd"  2>&1 | tee -a $LOGFILE

cat << EOF >> /etc/motd
###############################################################################
Demo Materials Deployment Completed : `date`
###############################################################################
EOF

echo "-- Update /etc/motd on all nodes"  2>&1 | tee -a $LOGFILE
ansible all -l masters,nodes,etcd  -m copy -a "src=/etc/motd dest=/etc/motd"


# Steps that are done after the install and should be done in the image build stage
#ansible nodes -a "docker pull registry.access.redhat.com/jboss-eap-6/eap64-openshift"
#ansible nodes -a "docker pull registry.access.redhat.com/jboss-eap-7/eap70-openshift"
