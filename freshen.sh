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
export CONSUL_WEB_NAMESPACE=
export CONSUL_DB_NAMESPACE=
export CONSUL_API_NAMESPACE=
export CONSUL_CACERT=/Users/mkeeler/Code/repos/consul-docker-test/secure/consul-agent-ca.pem
export CONSUL_HTTP_ADDR=https://localhost:8501
export CONSUL_HTTP_TOKEN=df87bdaa-b277-42d5-9b40-98d5d0fba61f
export MOCK_RAW_ERRORS=false
export USE_NAMESPACES=
export MOCK_USE_DISCO=false
export MANAGE_DB_POLICY_ID=
export MANAGE_API_POLICY_ID=
export DB_ROLE=
export API_ROLE=


alias freshen="source ../freshen.sh"
alias import-web="source ../web-tokens.sh"
alias init-other="source ../other-tokens.sh"
alias convert-to-roles="source ../token-to-roles.sh"
alias reset-demo="source ../transition.sh"
alias enable-service-discovery="export MOCK_USE_DISCO=true"
alias enable-kv="export MOCK_USE_KV=true"
alias deploy-web="docker-compose up web1 web2 web3"
alias deploy-all="docker-compose up"
alias copy-token="echo $CONSUL_HTTP_TOKEN | pbcopy"