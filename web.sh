MANAGE_WEB_POLICY_ID=$(consul acl policy create -format json -name manage-web -rules @${POLICY_DIR}/manage-web.hcl | jq -r '.ID')
MANAGE_WEB_TOKEN_SECRETS=()
MANAGE_WEB_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_WEB_POLICY_ID  | jq -r '.SecretID'))
MANAGE_WEB_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_WEB_POLICY_ID  | jq -r '.SecretID'))
MANAGE_WEB_TOKEN_SECRETS+=($(consul acl token create -format json -policy-id $MANAGE_WEB_POLICY_ID  | jq -r '.SecretID'))
consul services register -name web -port 1234 -id web:1 -token ${MANAGE_WEB_TOKEN_SECRETS[1]}
consul services register -name web -port 1234 -id web:2 -token ${MANAGE_WEB_TOKEN_SECRETS[2]}
consul services register -name web -port 1234 -id web:3 -token ${MANAGE_WEB_TOKEN_SECRETS[3]}