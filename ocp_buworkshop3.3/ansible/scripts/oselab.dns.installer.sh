#!/bin/bash
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export REPLPASSWORD=`cat /root/.default.password`
export DOMAINSUFFIX="workshops.openshift.com"
export DOMAINPREFIX="apps"


yum -y install bind bind-utils
systemctl enable named
systemctl stop named

### firewalld was being a bit problematic
### Since we turn it off later anyway, I've skipped this step.
#firewall-cmd --permanent --zone=public --add-service=dns
#firewall-cmd --reload
#sleep 100;

infraIP1=`host infranode1-$GUID.${DOMAINSUFFIX} ipa.opentlc.com  | grep $GUID | awk '{ print $4 }'`

echo infraIP 1  is $infraIP1 | tee -a /root/.dns.installer.txt
echo infraIP 2  is $infraIP2 | tee -a /root/.dns.installer.txt
echo GUID  is $GUID | tee -a /root/.dns.installer.txt

export domain="${DOMAINPREFIX}-"${GUID}".${DOMAINSUFFIX}"
echo "domain is $domain"


rm -rf /var/named/zones
mkdir -p /var/named/zones

echo "\$ORIGIN  .
\$TTL 1  ;  1 seconds (for testing only)
${domain} IN SOA master.${domain}.  root.${domain}.  (
  2011112904  ;  serial
  60  ;  refresh (1 minute)
  15  ;  retry (15 seconds)
  1800  ;  expire (30 minutes)
  10  ; minimum (10 seconds)
)
  NS master.${domain}.
\$ORIGIN ${domain}.
test A ${infraIP1}
* A ${infraIP1}"  >  /var/named/zones/${domain}.db

chgrp named -R /var/named
chown named -R /var/named/zones
restorecon -R /var/named

echo "// named.conf
options {
  listen-on port 53 { any; };
  directory \"/var/named\";
  dump-file \"/var/named/data/cache_dump.db\";
  statistics-file \"/var/named/data/named_stats.txt\";
  memstatistics-file \"/var/named/data/named_mem_stats.txt\";
  allow-query { any; };
  recursion yes;
  /* Path to ISC DLV key */
  bindkeys-file \"/etc/named.iscdlv.key\";
};
logging {
  channel default_debug {
    file \"data/named.run\";
    severity dynamic;
  };
};
zone \"${domain}\" IN {
  type master;
  file \"zones/${domain}.db\";
  allow-update { key ${domain} ; } ;
};" > /etc/named.conf

chown root:named /etc/named.conf
restorecon /etc/named.conf

systemctl start named

dig @127.0.0.1 test.apps-$GUID.${DOMAINSUFFIX}

if [ $? = 0 ]
then
  echo "DNS Setup was successful!"
else
  echo "DNS Setup failed"
fi

echo Fully Finished the $0 script  | tee -a /root/.dns.installer.txt

yum install iptables-services -y
#systemctl stop firewalld
#systemctl disable firewalld
systemctl enable iptables
systemctl start iptables

iptables -I INPUT -p tcp --dport 53 -j ACCEPT
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables-save > /etc/sysconfig/iptables
