masters="master1.example.com"
export METHOD="QUICK"
export PORTALAPP="FALSE"
export PAYMENTSAPP="FALSE"

for host in ${masters}
do
  ssh $host "wget http://idm.example.com/ipa/config/ca.crt -O /etc/origin/master/ipa-ca.crt"
done

#NOTE: If you were to configure multiple masters, you could add the other master hostnames in the for loop above

if [ $METHOD == "CORRECT" ]
  then

scp oselab.example.com:/etc/ansible/hosts /tmp/hosts
sed -i "s/^openshift_master_identity_providers/#openshift_master_identity_providers/g" /tmp/hosts
sed -i "/OSEv3:vars/ a openshift_master_identity_providers=[{'name': 'idm', 'challenge': 'true', 'login': 'true', 'kind': 'LDAPPasswordIdentityProvider', 'attributes': {'id': ['dn'], 'email': ['mail'], 'name': ['cn'], 'preferredUsername': ['uid']}, 'bindDN': 'uid=admin,cn=users,cn=accounts,dc=example,dc=com', 'bindPassword': 'r3dh4t1\!', 'ca': '/etc/origin/master/ipa-ca.crt', 'insecure': 'false', 'url': 'ldap://idm.example.com/cn=users,cn=accounts,dc=example,dc=com?uid?sub?(memberOf=cn=ose-users,cn=groups,cn=accounts,dc=example,dc=com)'}]" /tmp/hosts
scp /tmp/hosts oselab.example.com:/etc/ansible/hosts
ssh oselab.example.com "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml"

fi

if [ $METHOD == "QUICK" ]
  then
cp  /etc/origin/master/master-config.yaml  /etc/origin/master/master-config.yaml.original
sed -i -e '/oauthConfig:/,+22d' /etc/origin/master/master-config.yaml
sed -i -e '/^\s*$/d' /etc/origin/master/master-config.yaml
cat << EOF >> /etc/origin/master/master-config.yaml
oauthConfig:
  assetPublicURL: https://master1-${GUID}.oslab.opentlc.com:8443/console/
  grantConfig:
    method: auto
  identityProviders:
  - name: 'ipa_ldap'
    challenge: True
    login: True
    provider:
      apiVersion: v1
      kind: LDAPPasswordIdentityProvider
      insecure: false
      ca: /etc/origin/master/ipa-ca.crt
      url: 'ldap://idm.example.com/cn=users,cn=accounts,dc=example,dc=com?uid?sub?(memberOf=cn=ose-users,cn=groups,cn=accounts,dc=example,dc=com)'
      bindDN: 'uid=admin,cn=users,cn=accounts,dc=example,dc=com'
      bindPassword: 'r3dh4t1!'
      attributes:
        id:
        - dn
        email:
        - mail
        name:
        - cn
        preferredUsername:
        - uid
  masterCA: ca.crt
  masterPublicURL: https://master1-${GUID}.oslab.opentlc.com:8443
  masterURL: https://master1-${GUID}.oslab.opentlc.com:8443
  sessionConfig:
    sessionMaxAgeSeconds: 3600
    sessionName: ssn
    sessionSecretsFile: /etc/origin/master/session-secrets.yaml
  tokenConfig:
    accessTokenMaxAgeSeconds: 86400
    authorizeTokenMaxAgeSeconds: 500
EOF

systemctl restart  atomic-openshift-master.service
systemctl status  atomic-openshift-master.service

fi

cat << EOF > /etc/origin/master/groupsync.yaml
kind: LDAPSyncConfig
apiVersion: v1
url: "ldap://idm.example.com"
insecure: false
ca: "/etc/origin/master/ipa-ca.crt"
bindDN: 'uid=admin,cn=users,cn=accounts,dc=example,dc=com'
bindPassword: 'r3dh4t1!
rfc2307:
    groupsQuery:
        baseDN: "cn=groups,cn=accounts,dc=example,dc=com"
        scope: sub
        derefAliases: never
        filter: (&(!(objectClass=mepManagedEntry))(!(cn=trust admins))(!(cn=groups))(!(cn=admins))(!(cn=ipausers))(!(cn=editors))(!(cn=ose-users))(!(cn=evmgroup*))(!(cn=ipac*)))
    groupUIDAttribute: dn
    groupNameAttributes: [ cn ]
    groupMembershipAttributes: [ member ]
    usersQuery:
        baseDN: "cn=users,cn=accounts,dc=example,dc=com"
        scope: sub
        derefAliases: never
        filter: (memberOf=cn=ose-users,cn=groups,cn=accounts,dc=example,dc=com)
    userUIDAttribute: dn
    userNameAttributes: [ uid ]

EOF

openshift ex sync-groups --sync-config=/etc/origin/master/groupsync.yaml
openshift ex sync-groups --sync-config=/etc/origin/master/groupsync.yaml --confirm

oc get groups


if [ $PORTALAPP == "TRUE" ]
  then

export APPNAME=portalapp
export APPGROUP=PortalApp
export PRODGROUP=ProdAdmins
export APPTEXT="Portal App"
export ENVS="dev test prod"

oadm new-project ${APPNAME}-dev --display-name="${APPTEXT} Development"
oadm new-project ${APPNAME}-test --display-name="${APPTEXT} Testing"
oadm new-project ${APPNAME}-prod --display-name="${APPTEXT} Production"

oadm policy add-role-to-group admin ${APPGROUP} -n ${APPNAME}-dev
oadm policy add-role-to-group admin ${APPGROUP} -n ${APPNAME}-test
oc policy add-role-to-group view ${APPGROUP} -n ${APPNAME}-prod

oadm policy add-role-to-group admin ${PRODGROUP} -n ${APPNAME}-prod

oc policy add-role-to-group system:image-puller system:serviceaccounts:${APPNAME}-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:${APPNAME}-prod -n ${APPNAME}-test

oc policy add-role-to-group system:image-puller system:serviceaccounts:${APPNAME}-test
oc policy add-role-to-group system:image-puller system:serviceaccounts:${APPNAME}-test -n ${APPNAME}-dev


#oc policy add-role-to-group view system:serviceaccounts:${APPNAME}-dev -n ${APPNAME}-prod
#oc policy add-role-to-group view system:serviceaccounts:${APPNAME}-dev -n ${APPNAME}-test

fi



if [ $PAYMENTSAPP == "TRUE" ]
  then

export APPNAME=paymentsapp
export APPGROUP=PaymentsApp
export PRODGROUP=ProdAdmins
export APPTEXT="Payments App"
export ENVS="dev test prod"

oadm new-project ${APPNAME}-dev --display-name="${APPTEXT} Development"
oadm new-project ${APPNAME}-test --display-name="${APPTEXT} Testing"
oadm new-project ${APPNAME}-prod --display-name="${APPTEXT} Production"

oadm policy add-role-to-group admin ${APPGROUP} -n ${APPNAME}-dev
oadm policy add-role-to-group admin ${APPGROUP} -n ${APPNAME}-test
oc policy add-role-to-group view ${APPGROUP} -n ${APPNAME}-prod

oadm policy add-role-to-group admin ${PRODGROUP} -n ${APPNAME}-prod

oc policy add-role-to-group system:image-puller system:serviceaccounts:${APPNAME}-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:${APPNAME}-prod -n ${APPNAME}-test

oc policy add-role-to-group system:image-puller system:serviceaccounts:${APPNAME}-test
oc policy add-role-to-group system:image-puller system:serviceaccounts:${APPNAME}-test -n ${APPNAME}-dev


#oc policy add-role-to-group view system:serviceaccounts:${APPNAME}-dev -n ${APPNAME}-prod
#oc policy add-role-to-group view system:serviceaccounts:${APPNAME}-dev -n ${APPNAME}-test

fi
