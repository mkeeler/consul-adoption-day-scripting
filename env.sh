export POLICY_DIR=/Users/mkeeler/consul-adoption-day/policies
export CONSUL_CACERT=/Users/mkeeler/Code/repos/consul-docker-test/secure/consul-agent-ca.pem
export CONSUL_HTTP_ADDR=https://localhost:8501
export CONSUL_HTTP_TOKEN=df87bdaa-b277-42d5-9b40-98d5d0fba61f

function consul-curl {
   endpoint=$1
   shift

   NS_HEADER=""
   if test -n "${CONSUL_NAMESPACE}"
   then
      NS_HEADER="-H 'X-Consul-Namespace: $CONSUL_NAMESPACE'"
   fi

   curl -s --cacert "$CONSUL_CACERT" \
        -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
        $NS_HEADER \
        $@ \
        "${CONSUL_HTTP_ADDR}/v1/${endpoint}?pretty"
}

function consul-discover {
   service=$1
   shift
   token=${1:-${CONSUL_HTTP_TOKEN}}
   CONSUL_HTTP_TOKEN=${token} consul-curl "catalog/service/$service"
}

alias register-web="consul services register -name web -port 1234"

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