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
#export COURSE="ocp_implementation3.3"
export METRICS="TRUE"
export LOGGING="TRUE"
export DOMAIN="oslab.opentlc.com"


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
yum install ansible -y

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


cat << EOF >> /etc/motd
###############################################################################
Demo Materials Deployment Completed : `date`
###############################################################################
EOF

echo "-- Update /etc/motd on all nodes"  2>&1 | tee -a $LOGFILE
ansible all -l masters,nodes,etcd  -m copy -a "src=/etc/motd dest=/etc/motd"
