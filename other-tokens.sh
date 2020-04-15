export MANAGE_DB_POLICY_ID=$(consul acl policy create -format json -name manage-db -rules @${POLICY_DIR}/manage-db.hcl | jq -r '.ID')
echo "manage-db policy created with ID: $MANAGE_DB_POLICY_ID"
MANAGE_DB_TOKEN_SECRETS=()
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_DB_POLICY_ID | jq -r '.SecretID'))
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_DB_POLICY_ID | jq -r '.SecretID'))
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_DB_POLICY_ID | jq -r '.SecretID'))
export MANAGE_DB_TOKEN_SECRETS=($MANAGE_DB_TOKEN_SECRETS)
export DB_TOKEN_1=${MANAGE_DB_TOKEN_SECRETS[1]}
export DB_TOKEN_2=${MANAGE_DB_TOKEN_SECRETS[2]}
export DB_TOKEN_3=${MANAGE_DB_TOKEN_SECRETS[3]}
echo "3 tokens created and linked with the manage-db policy"


export MANAGE_API_POLICY_ID=$(consul acl policy create -format json -name manage-api -rules @${POLICY_DIR}/manage-api.hcl | jq -r '.ID')
echo "manage-api policy created with ID: $MANAGE_API_POLICY_ID"
MANAGE_API_TOKEN_SECRETS=()
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_API_POLICY_ID | jq -r '.SecretID'))
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_API_POLICY_ID | jq -r '.SecretID'))
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_API_POLICY_ID | jq -r '.SecretID'))
export MANAGE_API_TOKEN_SECRETS=($MANAGE_API_TOKEN_SECRETS)
export API_TOKEN_1=${MANAGE_API_TOKEN_SECRETS[1]}
export API_TOKEN_2=${MANAGE_API_TOKEN_SECRETS[2]}
export API_TOKEN_3=${MANAGE_API_TOKEN_SECRETS[3]}
echo "3 tokens created and linked with the manage-api policy"
