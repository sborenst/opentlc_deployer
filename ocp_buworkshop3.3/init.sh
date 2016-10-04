#!/bin/bash
################################################################################
################################################################################
# This Script will be used to deploy the OSE_FastAdv and OSE_Demo blueprints
# This is a temporary method until we do this properly with Ansible playbooks.
# Steps in the scripts are:
## Step 0 - Define variables for deployment.
## Step 1 - Prepare environment and test that all hosts are up
## Step 2 - Install OpenShift
## Step 3 - Post-Configure OpenShift (Metrics, Logging)
## Step 4 - Demo content deployment
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
#export COURSE="ocp_demo3.3"
export METRICS="TRUE"
export LOGGING="TRUE"
export DEMO="TRUE"
export DATE=`date`
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export DOMAIN="workshops.openshift.com"
################################################################################
## Step 1 - Prepare environemnt and test that all hosts are up
################################################################################
echo "---- Step 1 - Prepare environemnt and test that all hosts are up"  2>&1 | tee -a $LOGFILE


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


##### WORKAROUNDS FOR TIMEOUTS ON RAVELLO
### Checking all hosts are up
# Test that all the nodes are up, we are testing that the docker service is Active
yum install ansible -y  2>&1 | tee -a $LOGFILE

  export RESULT=1
  until [ $RESULT -eq 0 ]; do
    echo "Checking hosts are up"  2>&1 | tee -a $LOGFILE
    ansible all -i /root/.opentlc_deployer/${COURSE}/ansible/files/opentlc.hosts -m ping
    export RESULT=$?
  done

sed -i '/#timeout = 10/s/.*/timeout = 59/' /etc/ansible/ansible.cfg
echo "ansible-playbook -i /root/.opentlc_deployer/${COURSE}/ansible/files/opentlc.hosts /root/.opentlc_deployer/${COURSE}/ansible/main.yml"   2>&1 | tee -a $LOGFILE
export HOME="/root"
ansible-playbook -i /root/.opentlc_deployer/${COURSE}/ansible/files/opentlc.hosts /root/.opentlc_deployer/${COURSE}/ansible/main.yml   2>&1 | tee -a $LOGFILE

## WORKAROUND
#sed -i '/registry/s/^/#/' /etc/exports


################################################################################
## Step 2 - install openshift
################################################################################
echo "---- Step 2 - install openshift"  2>&1 | tee -a $LOGFILE
export HOME="/root"
echo "ansible-playbook -i /etc/ansible/hosts /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml"  2>&1 | tee -a $LOGFILE
ansible-playbook -i /etc/ansible/hosts /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml   2>&1 | tee -a $LOGFILE

################################################################################
## Step 3 - Post-Configure OpenShift (Metrics, Logging)
################################################################################
## This will get a done with playbooks later
echo "---- Step 3 - Post-Configure OpenShift (Metrics, Logging)"  2>&1 | tee -a $LOGFILE
echo "-- Get the openshift_toolkit repo to deploy METRICS and LOGGING"  2>&1 | tee -a $LOGFILE

  scp -r master1.example.com:/root/.kube /root/.kube  2>&1 | tee -a $LOGFILE

  if [ $METRICS == "TRUE" ]
    then
      echo "Running Ansible playbook for Metrics, logs to ${LOGFILE}.metrics"  2>&1 | tee -a $LOGFILE
      oc project openshift-infra   2>&1 | tee -a $LOGFILE
      oc create -f - <<API
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: metrics-deployer
      secrets:
      - name: metrics-deployer
API
    oadm policy add-role-to-user edit system:serviceaccount:openshift-infra:metrics-deployer   2>&1 | tee -a $LOGFILE
    oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:openshift-infra:heapster   2>&1 | tee -a $LOGFILE
    oc secrets new metrics-deployer nothing=/dev/null
    oc new-app openshift/metrics-deployer-template -p CASSANDRA_PV_SIZE=9Gi -p HAWKULAR_METRICS_HOSTNAME=metrics.apps-${GUID}.${DOMAIN} -p USE_PERSISTENT_STORAGE=true -p IMAGE_VERSION=3.3.0 -p IMAGE_PREFIX=registry.access.redhat.com/openshift3/   2>&1 | tee -a $LOGFILE
    ansible masters -m shell -a "sed -i '/publicURL:/a \ \ metricsPublicURL: https://metrics.apps-'${GUID}'.${DOMAIN}/hawkular/metrics'  /etc/origin/master/master-config.yaml"   2>&1 | tee -a $LOGFILE
    ssh master1.example.com "systemctl restart atomic-openshift-master"

    oc project default   2>&1 | tee -a $LOGFILE

  fi

  echo "-- Check pods in the openshift-infra project"  2>&1 | tee -a $LOGFILE
  oc get pods -n openshift-infra  -o wide  2>&1 | tee -a $LOGFILE

  echo "-- set the current context to the default project"  2>&1 | tee -a $LOGFILE
  oc project default  2>&1 | tee -a $LOGFILE

if [ $LOGGING == "TRUE" ]
   then
     ssh master1.example.com "oc apply -n openshift -f     /usr/share/openshift/examples/infrastructure-templates/enterprise/logging-deployer.yaml"   2>&1 | tee -a $LOGFILE
     oc create -f - <<API
     apiVersion: v1
     kind: PersistentVolume
     metadata:
       name: "es-storage"
     spec:
       capacity:
         storage: 10Gi
       accessModes:
         - ReadWriteOnce
         - ReadWriteMany
       nfs:
         path: "/srv/nfs/es-storage"
         server: "oselab.example.com"
         readOnly: false
API

     oadm new-project logging --node-selector=""   2>&1 | tee -a $LOGFILE
     oc project logging   2>&1 | tee -a $LOGFILE
     oc new-app logging-deployer-account-template -n logging   2>&1 | tee -a $LOGFILE
     oadm policy add-cluster-role-to-user oauth-editor        system:serviceaccount:logging:logging-deployer
  #   oadm policy add-cluster-role-to-user cluster-admin       system:serviceaccount:logging:logging-deployer   2>&1 | tee -a $LOGFILE

     oadm policy add-scc-to-user privileged system:serviceaccount:logging:aggregated-logging-fluentd   2>&1 | tee -a $LOGFILE
     oadm policy add-cluster-role-to-user cluster-reader     system:serviceaccount:logging:aggregated-logging-fluentd   2>&1 | tee -a $LOGFILE
     oc new-app logging-deployer-template --param ES_PVC_SIZE=9Gi --param PUBLIC_MASTER_URL=https://master1-${GUID}.${DOMAIN}:8443 --param KIBANA_HOSTNAME=kibana.apps-${GUID}.${DOMAIN} --param IMAGE_VERSION=3.3.0 --param IMAGE_PREFIX=registry.access.redhat.com/openshift3/        --param KIBANA_NODESELECTOR='region=infra' --param ES_NODESELECTOR='region=infra' --param MODE=install -n logging   2>&1 | tee -a $LOGFILE

     oc label nodes --all logging-infra-fluentd=true   2>&1 | tee -a $LOGFILE
     oc label node master1.example.com --overwrite logging-infra-fluentd=false   2>&1 | tee -a $LOGFILE



 fi

   oc project default

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
## Step4 - Demo content deployment
################################################################################
echo "---- Step 4 - Demo content deployment"  2>&1 | tee -a $LOGFILE

if [ $DEMO == "TRUE" ]
  then
echo "-- Running /root/.opentlc.installer/Demo_Deployment_Script.sh"  2>&1 | tee -a $LOGFILE
chmod +x /root/.opentlc_deployer/${COURSE}/ansible/scripts/Demo_Deployment_Script.sh
/root/.opentlc_deployer/${COURSE}/ansible/scripts/Demo_Deployment_Script.sh 2>&1 | tee -a /root/.Demo.Deployment.log
echo "-- Finished running /root/.opentlc_deployer/${COURSE}/ansible/files/Demo_Deployment_Script.sh"  2>&1 | tee -a $LOGFILE
fi


cat << EOF >> /etc/motd
###############################################################################
Demo Materials Deployment Completed : `date`
###############################################################################
EOF

sleep 60
cat << EOF >> /etc/motd
###############################################################################
OpenShift Cluster Quick Status: `date`
###############################################################################
oc get pods --all-namespaces -o wide;
`oc get pods --all-namespaces -o wide`
###############################################################################
oc get routes --all-namespaces
###############################################################################
`oc get routes --all-namespaces -o wide`
###############################################################################
oc get nodes --show-labels
###############################################################################
`oc get nodes --show-labels`
###############################################################################
EOF

echo "-- Update /etc/motd on all nodes"  2>&1 | tee -a $LOGFILE
ansible all -l masters,nodes,etcd  -m copy -a "src=/etc/motd dest=/etc/motd"
ansible 'nodes:!masters' -a "docker pull registry.access.redhat.com/jboss-eap-6/eap64-openshift:1.1" 2>&1 | tee -a $LOGFILE
