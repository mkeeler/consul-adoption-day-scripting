consul namespace create -name $CONSUL_DB_NAMESPACE > /dev/null
consul namespace create -name $CONSUL_API_NAMESPACE > /dev/null


OLD_NSPACE=$CONSUL_NAMESPACE
export CONSUL_NAMESPACE=$CONSUL_DB_NAMESPACE

export MANAGE_DB_POLICY_ID=$(consul acl policy create -format json -name manage-db -rules @${POLICY_DIR}/manage-db.hcl | jq -r '.ID')
export DB_ROLE=$(consul acl role create -format json -name service-db  -policy-name manage-db | jq -r '.ID')
MANAGE_DB_TOKEN_SECRETS=()
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -role-id $DB_ROLE | jq -r '.SecretID'))
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -role-id $DB_ROLE | jq -r '.SecretID'))
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -role-id $DB_ROLE | jq -r '.SecretID'))
export MANAGE_DB_TOKEN_SECRETS=($MANAGE_DB_TOKEN_SECRETS)
export DB_TOKEN_1=${MANAGE_DB_TOKEN_SECRETS[1]}
export DB_TOKEN_2=${MANAGE_DB_TOKEN_SECRETS[2]}
export DB_TOKEN_3=${MANAGE_DB_TOKEN_SECRETS[3]}
export CONSUL_NAMESPACE=$OLD_NSPACE


export CONSUL_NAMESPACE=$CONSUL_API_NAMESPACE
export MANAGE_API_POLICY_ID=$(consul acl policy create -format json -name manage-api -rules @${POLICY_DIR}/manage-api.hcl | jq -r '.ID')
export API_ROLE=$(consul acl role create -format json -name service-api -policy-name manage-api | jq -r '.ID')
MANAGE_API_TOKEN_SECRETS=()
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -role-id $API_ROLE | jq -r '.SecretID'))
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -role-id $API_ROLE | jq -r '.SecretID'))
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -role-id $API_ROLE | jq -r '.SecretID'))
export MANAGE_API_TOKEN_SECRETS=($MANAGE_API_TOKEN_SECRETS)
export API_TOKEN_1=${MANAGE_API_TOKEN_SECRETS[1]}
export API_TOKEN_2=${MANAGE_API_TOKEN_SECRETS[2]}
export API_TOKEN_3=${MANAGE_API_TOKEN_SECRETS[3]}

export CONSUL_NAMESPACE=$OLD_NSPACE