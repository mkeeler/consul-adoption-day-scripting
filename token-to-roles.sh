export DB_ROLE=$(consul acl role create -format json -name service-db -policy-name manage-db | jq -r '.ID')
for token in ${MANAGE_DB_TOKEN_SECRETS}
do
   accessor=$(consul acl token read -self -token ${token} -format json | jq -r '.AccessorID')
   consul acl token update -id ${accessor} -role-id ${DB_ROLE} > /dev/null
done

export API_ROLE=$(consul acl role create -format json -name service-api -policy-name manage-api -policy-name discover-nodes -policy-name discover-db | jq -r '.ID')
for token in ${MANAGE_API_TOKEN_SECRETS}
do
   accessor=$(consul acl token read -self -token ${token} -format json | jq -r '.AccessorID')
   consul acl token update -id ${accessor} -role-id ${API_ROLE} > /dev/null
done