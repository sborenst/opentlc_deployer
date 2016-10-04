################################################################################
## Step 0 - Define variables for deployment.
################################################################################
#OPENTLC VARS
export LOGFILE="/root/.oselab.log"
export USER=$1
#export USER="shacharb-redhat.com"
export COURSE=$2;
#export COURSE="demo_mwinit1.0"
export DEMO="TRUE"
export DATE=`date`
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export DOMAIN="oslab.opentlc.com"
