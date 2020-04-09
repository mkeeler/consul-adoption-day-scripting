# Determing our master tokens accessor
MASTER_TOKEN_ACCESSOR=$(consul acl token read -self -format json | jq -r ".AccessorID")

MANAGE_WEB_TOKEN_SECRETS=()
# there should be 3 tokens besides the bootstrap token and the anonymous token
for accessor in $(consul acl token list -format json | jq -r  ".[] | select(.AccessorID != \"00000000-0000-0000-0000-000000000002\" and .AccessorID != \"$MASTER_TOKEN_ACCESSOR\") | .AccessorID")
do
   MANAGE_WEB_TOKEN_SECRETS+=($(consul acl token read -id ${accessor} -format json | jq -r '.SecretID'))
done
export MANAGE_WEB_TOKEN_SECRETS=($MANAGE_WEB_TOKEN_SECRETS)


export MANAGE_DB_POLICY_ID=$(consul acl policy create -format json -name manage-db -rules 'service "db" { policy = "write" }' | jq -r '.ID')
MANAGE_DB_TOKEN_SECRETS=()
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -description "DB Service Token" -policy-id $MANAGE_DB_POLICY_ID | jq -r '.SecretID'))
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -description "DB Service Token" -policy-id $MANAGE_DB_POLICY_ID | jq -r '.SecretID'))
MANAGE_DB_TOKEN_SECRETS+=($(consul acl token create -format json -description "DB Service Token" -policy-id $MANAGE_DB_POLICY_ID | jq -r '.SecretID'))
export MANAGE_DB_TOKEN_SECRETS=($MANAGE_DB_TOKEN_SECRETS)
consul services register -name db -port 2345 -id db:1 -token ${MANAGE_DB_TOKEN_SECRETS[1]}
consul services register -name db -port 2345 -id db:2 -token ${MANAGE_DB_TOKEN_SECRETS[2]}
consul services register -name db -port 2345 -id db:3 -token ${MANAGE_DB_TOKEN_SECRETS[3]}

export MANAGE_API_POLICY_ID=$(consul acl policy create -format json -name manage-api -rules 'service "api" { policy = "write" }' | jq -r '.ID')
MANAGE_API_TOKEN_SECRETS=()
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -description "API Service Token" -policy-id $MANAGE_API_POLICY_ID | jq -r '.SecretID'))
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -description "API Service Token" -policy-id $MANAGE_API_POLICY_ID | jq -r '.SecretID'))
MANAGE_API_TOKEN_SECRETS+=($(consul acl token create -format json -description "API Service Token" -policy-id $MANAGE_API_POLICY_ID | jq -r '.SecretID'))
export MANAGE_API_TOKEN_SECRETS=($MANAGE_API_TOKEN_SECRETS)
consul services register -name api -port 3456 -id api:1 -token ${MANAGE_API_TOKEN_SECRETS[1]}
consul services register -name api -port 3456 -id api:2 -token ${MANAGE_API_TOKEN_SECRETS[2]}
consul services register -name api -port 3456 -id api:3 -token ${MANAGE_API_TOKEN_SECRETS[3]}