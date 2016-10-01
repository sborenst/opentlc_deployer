## open-init.sh script, started by cloud-init
## Variables are passed by CloudForms and are defined by the CF Instance

export USER=$1
#export USER="shacharb-redhat.com"
export COURSE=$2;
#export COURSE="ocp_demo3.3"
export GITREPO='https://github.com/sborenst/opentlc_deployer'
export REPOTARGET='/root/.opentlc_deployer'
export FUTURE_ARGV3=$3
export FUTURE_ARGV4=$4
export FUTURE_ARGV5=$5
export FUTURE_ARGV6=$6

echo "open-init.sh started with the following argvs: $*" > /root/.open-init.log
git clone ${GITREPO} ${REPOTARGET} 2>&1

chmod +x /root/.opentlc_deployer/${COURSE}/init.sh 2>&1
echo ${REPOTARGET}/${COURSE}/init.sh ${USER} ${COURSE} ${FUTURE_ARGV3} ${FUTURE_ARGV4} ${FUTURE_ARGV5} ${FUTURE_ARGV6} 2>&1
${REPOTARGET}/${COURSE}/init.sh ${USER} ${COURSE} ${FUTURE_ARGV3} ${FUTURE_ARGV4} ${FUTURE_ARGV5} ${FUTURE_ARGV6} 2>&1
