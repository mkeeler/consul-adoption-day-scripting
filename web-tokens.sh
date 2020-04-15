OLD_NSPACE=$CONSUL_NAMESPACE
if test -n "$USE_NAMESPACES"
then
   export CONSUL_NAMESPACE="ns1"
fi

# Determing our master tokens accessor
MASTER_TOKEN_ACCESSOR=$(consul acl token read -self -format json | jq -r ".AccessorID")

MANAGE_WEB_TOKEN_SECRETS=()
# there should be 3 tokens besides the bootstrap token and the anonymous token
for accessor in $(consul acl token list -format json | jq -r  ".[] | select(.AccessorID != \"00000000-0000-0000-0000-000000000002\" and .AccessorID != \"$MASTER_TOKEN_ACCESSOR\") | .AccessorID")
do
   echo "Token Accessor: $accessor"
   MANAGE_WEB_TOKEN_SECRETS+=($(consul acl token read -id ${accessor} -format json | jq -r '.SecretID'))
done
export MANAGE_WEB_TOKEN_SECRETS=($MANAGE_WEB_TOKEN_SECRETS)
export WEB_TOKEN_1=${MANAGE_WEB_TOKEN_SECRETS[1]}
export WEB_TOKEN_2=${MANAGE_WEB_TOKEN_SECRETS[2]}
export WEB_TOKEN_3=${MANAGE_WEB_TOKEN_SECRETS[3]}
export CONSUL_NAMESPACE=$OLD_NSPACE
