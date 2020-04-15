# deregister the services

consul services deregister -id web:web1 > /dev/null
consul services deregister -id web:web2 > /dev/null
consul services deregister -id web:web3 > /dev/null

consul services deregister -id api:api1 > /dev/null
consul services deregister -id api:api2 > /dev/null
consul services deregister -id api:api3 > /dev/null

consul services deregister -id db:db1 > /dev/null
consul services deregister -id db:db2 > /dev/null
consul services deregister -id db:db3 > /dev/null

function delete_token_secret {
   accessor=$(consul acl token read -self -token ${1} -format json | jq -r '.AccessorID')
   consul acl token delete -id ${accessor} > /dev/null
}

# delete all the tokens we created
delete_token_secret $WEB_TOKEN_1
delete_token_secret $WEB_TOKEN_2
delete_token_secret $WEB_TOKEN_3

delete_token_secret $API_TOKEN_1
delete_token_secret $API_TOKEN_2
delete_token_secret $API_TOKEN_3

delete_token_secret $DB_TOKEN_1
delete_token_secret $DB_TOKEN_2
delete_token_secret $DB_TOKEN_3

# delete the roles we created

consul acl role delete -name service-web > /dev/null
consul acl role delete -name service-api > /dev/null
consul acl role delete -name service-db > /dev/null

# delete all the policies we created
consul acl policy delete -name manage-web > /dev/null
consul acl policy delete -name manage-api > /dev/null
consul acl policy delete -name manage-db > /dev/null
consul acl policy delete -name discover-api > /dev/null
consul acl policy delete -name discover-db > /dev/null
consul acl policy delete -name discover-nodes > /dev/null

export WEB_TOKEN_1=
export WEB_TOKEN_2=
export WEB_TOKEN_3=
export DB_TOKEN_1=
export DB_TOKEN_2=
export DB_TOKEN_3=
export API_TOKEN_1=
export API_TOKEN_2=
export API_TOKEN_3=
export MOCK_USE_KV=false
export CONSUL_NAMESPACE=
export CONSUL_WEB_NAMESPACE=ns1
export CONSUL_DB_NAMESPACE=ns3
export CONSUL_API_NAMESPACE=ns2
export MOCK_RAW_ERRORS=false
export USE_NAMESPACES=true

alias init-other="source ../other-namespace-tokens.sh"
