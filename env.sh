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
