#!/bin/bash

def_cap() {
  if [[ "$KUBECONFIG" == "$HOME/.kube/olympus" ]]; then
    echo "olympus"
  else
    echo "moulick-test"
  fi
}

pod_name="$(id -un | tr '.' '-')-debug"
read_only_creds_secret_name=rds-readonly-credentials

urlencode_old() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <string>" >&2
    return 1
  fi

  old_lc_collate=$LC_COLLATE
  LC_COLLATE=C
  local length="${#1}"
  for ((i = 0; i < length; i++)); do
    local c="${1:$i:1}"
    case $c in
    [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
    *) printf '%%%02X' "'$c" ;;
    esac
  done
  LC_COLLATE=$old_lc_collate

}

urlencode() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <string>" >&2
    return 1
  fi
  # Jq can also do the encoding for us, and is probably more robust than the above
  printf %s "$1" | jq -sRr @uri
}

urldecode() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <string>" >&2
    return 1
  fi

  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

kdebug() {
  pod_status=$(kubectl get pods "$pod_name" -n "$(def_cap)" -o=jsonpath='{.status.phase}')
  if [[ "$pod_status" == "Running" ]]; then
    kubectl exec -it "$pod_name" -n "$(def_cap)" -- bash
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢 $(tput sgr0)"
    kubectl delete pod "$pod_name" -n "$(def_cap)" --grace-period=0 --force --ignore-not-found
    kubectl run -it --labels="sidecar.istio.io/inject=true" --restart=Never "$pod_name" --image=moulick/debug-image:latest -n "$(def_cap)" -- bash
    # kubectl run -it --restart=Never "$pod_name" --image=moulick/debug-image:latest -n "$(def_cap)" -- bash
  fi
}

kdebug-kill() {
  echo "\ufb81 Killing pod $pod_name"
  kubectl delete pod "$pod_name" -n "$(def_cap)" --grace-period=0 --force --ignore-not-found
}

db_shell() {
  if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <user> <urlencoded password> <url> <port> <db_name>" >&2
    return 1
  else
    echo "launching pod shell"
  fi

  user=$1
  pass=$2
  url=$3
  port=$4
  db_name=$5

  postg="postgresql://$user:$pass@$url:$port/$db_name"

  pod_status=$(kubectl get pods "$pod_name" -n "$(def_cap)" -o=jsonpath='{.status.phase}')

  if [[ "$pod_status" == "Running" ]]; then
    kubectl exec -it "$pod_name" -n "$(def_cap)" -- psql "$postg"
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢, making a new one $(tput sgr0)"
    kubectl delete pod "$pod_name" -n "$(def_cap)" --grace-period=0 --force --ignore-not-found
    kubectl run -it --restart=Never "$pod_name" --image=moulick/debug-image:latest -n "$(def_cap)" -- psql "$postg"
  fi
}

create-readonly-user() {
  if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <user> <urlencoded password> <url> <port> <db_name>" >&2
    return 1
  fi

  user=$1
  pass=$2
  url=$3
  port=$4
  db_name=$5

  postg="postgresql://$user:$pass@$url:$port/$db_name"

  # disbaling the shellchecks as this is like embeded SQL Query
  # shellcheck disable=SC2016,SC2089
  SQLCMD='DO
  $do$
  BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles
        WHERE  rolname = '\''readonly_user'\'') THEN
        CREATE ROLE readonly_user LOGIN PASSWORD '\''EfY5czJ&zctM$jcX'\'';
    END IF;
    ALTER USER readonly_user PASSWORD '\''EfY5czJ&zctM$jcX'\'';
  END
  $do$;
  REVOKE CREATE ON SCHEMA public FROM public;
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;
  GRANT USAGE ON SCHEMA public TO readonly_user;
  GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO readonly_user;
  -- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO readonly_user;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO readonly_user;'
  echo "$SQLCMD"

  pod_status=$(kubectl get pods "$pod_name" -n "$(def_cap)" -o=jsonpath='{.status.phase}')

  if [[ "$pod_status" == "Running" ]]; then
    kubectl exec -it "$pod_name" -n "$(def_cap)" -- psql "$postg" -c "$SQLCMD"
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢, making a new one $(tput sgr0)"
    kubectl delete pod "$pod_name" -n "$(def_cap)" --grace-period=0 --force --ignore-not-found
    kubectl run -it --restart=Never "$pod_name" --image=moulick/debug-image:latest -n "$(def_cap)" -- psql "$postg" -c "$SQLCMD"
  fi
}

alfresco() {
  db_shell alfresco alfresco alfresco-postgresql-acs.catalogue-doc-mgmt 5432 alfresco
}

in-cluster-post() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <name>" >&2
    return 1
  fi

  secret=$(kubectl get secret "$1-main-postgresql" -n "${1}" -o json | jq -er '.data | map_values(@base64d)')
  if [[ -z $secret ]]; then
    echo "could not connect to $1"
    return 1
  else
    echo "got secret from cluster"
  fi

  escaped_password=$(urlencode "$(echo -E "$secret" | jq -er '.MAIN_PASSWORD')")

  user=$(echo -E "$secret" | jq -er '.MAIN_USERNAME')
  addr="helm-$1-main-postgresql.${1/-(master|develop|v1)/}"
  port="5432"
  db_name="main"
  echo "${addr}"

  db_shell "$user" "$escaped_password" "$addr" "$port" "$db_name"
}

in-cluster-post-create-readonly-user() {
  secret=$(kubectl get secret "$1-main-postgresql" -n "${1}" -o json | jq -er '.data | map_values(@base64d)')
  if [[ -z $secret ]]; then
    echo "could not connect to $1"
    return 1
  else
    echo "got secret from cluster"
  fi

  escaped_password=$(urlencode "$(echo -E "$secret" | jq -er '.MAIN_PASSWORD')")

  user=$(echo -E "$secret" | jq -er '.MAIN_USERNAME')
  addr="helm-$1-main-postgresql.${1}"
  port="5432"
  db_name="main"
  echo "${addr}"

  create-readonly-user "$user" "$escaped_password" "$addr" "$port" "$db_name"
}

rds-create-readonly-user() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <instance name> <db name>" >&2
    return 1
  fi

  secret=$(kubectl get secret "$1-$2-rds-instance" -n "${1}" -o json | jq -er '.data | map_values(@base64d)')
  if [[ -z $secret ]]; then
    echo "could not connect to $1-$2"
    return 1
  else
    echo "got secret from cluster"
  fi

  escaped_password=$(urlencode "$(echo -E "$secret" | jq -er '.MASTER_PASSWORD')")
  echo -E "$secret" | jq -er '.ENDPOINT_ADDRESS'

  user=$(echo -E "$secret" | jq -er '.MASTER_USERNAME')
  addr=$(echo -E "$secret" | jq -er '.ENDPOINT_ADDRESS')
  port=$(echo -E "$secret" | jq -er '.PORT')
  db_name=$(echo -E "$secret" | jq -er '.DB_NAME')

  create-readonly-user "$user" "$escaped_password" "$addr" "$port" "$db_name"
}

# rds-rw() {
#   secret=$(kubectl get secret "$1-main-postgresql" -n "${1}" -o json | jq -er '.data | map_values(@base64d)')

#   if [[ -z $secret ]]; then
#     echo "could not connect to $1"
#     return 1
#   fi

#   escaped_password=$(urlencode "$(echo -E "$secret" | jq -er '.MASTER_PASSWORD')")
#   echo "$secret" | jq -er '.DB_INSTANCE_IDENTIFIER'

#   user=$(echo -E "$secret" | jq -er '.MASTER_USERNAME')
#   addr=$(echo -E "$secret" | jq -er '.ENDPOINT_ADDRESS')
#   port=$(echo -E "$secret" | jq -er '.PORT')
#   db_name=$(echo -E "$secret" | jq -er '.DB_NAME')

#   db_shell "$user" "$escaped_password" "$addr" "$port" "$db_name"
# }

rds() {

  if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <instance name> <db name>" >&2
    return 1
  fi

  secretmanager_secret_name="/$ENVIRONMENT/$STAGE/$read_only_creds_secret_name"

  secret=$(kubectl get secret "$1-$2-rds-instance" -n "${1}" -o json | jq -er '.data | map_values(@base64d)')
  if [[ -z $secret ]]; then
    echo "could not connect to $1-$2"
    return 1
  else
    echo "got secret from cluster"
  fi

  readonly_creds=$(aws secretsmanager get-secret-value --secret-id "$secretmanager_secret_name" --output json | jq -er '.SecretString')
  if [[ -z $readonly_creds ]]; then
    echo "could not find read only secret $secretmanager_secret_name in aws secretmanager "
    return 1
  else
    echo "got read_only secret from aws"
  fi

  escaped_password=$(urlencode "$(echo -E "$readonly_creds" | jq -er .RDS_READONLY_USER_PASSWORD)")
  echo -E "$secret" | jq -er '.ENDPOINT_ADDRESS'

  user=$(echo -E "$readonly_creds" | jq -er .RDS_READONLY_USER)
  addr=$(echo -E "$secret" | jq -er '.ENDPOINT_ADDRESS')
  port=$(echo -E "$secret" | jq -er '.PORT')
  db_name=$(echo -E "$secret" | jq -er '.DB_NAME')

  db_shell "$user" "$escaped_password" "$addr" "$port" "$db_name"
}

rds-rw() {

  if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <instance name> <db name>" >&2
    return 1
  fi

  secret=$(kubectl get secret "$1-$2-rds-instance" -n "${1}" -o json | jq -er '.data | map_values(@base64d)')

  if [[ -z $secret ]]; then
    echo "could not connect to $1-$2"
    return 1
  fi

  escaped_password=$(urlencode "$(echo -E "$secret" | jq -er '.MASTER_PASSWORD')")
  echo -E "$secret" | jq -er '.ENDPOINT_ADDRESS'

  user=$(echo -E "$secret" | jq -er '.MASTER_USERNAME')
  addr=$(echo -E "$secret" | jq -er '.ENDPOINT_ADDRESS')
  port=$(echo -E "$secret" | jq -er '.PORT')
  db_name=$(echo -E "$secret" | jq -er '.DB_NAME')

  db_shell "$user" "$escaped_password" "$addr" "$port" "$db_name"
}

argo() {
  local_url="http://localhost:8083"
  echo "argo at $local_url"
  open $local_url
  kubectl port-forward svc/argocd-server -n argo 8083:80
}

logs() {
  local_url="http://localhost:5602"
  echo "kibana at $local_url"
  open $local_url
  kubectl port-forward svc/logging-kibana-kb-http -n mla 5602:5601
}

# logs-etoe() {
#   local_url="http://localhost:5603"
#   echo "kibana at $local_url"
#   open $local_url
#   kubectl port-forward svc/kibana-etoe-kb-http -n capabilities 5603:5601
# }

grafana() {
  local_url="http://localhost:3002"
  echo "grafana at $local_url"
  open $local_url
  kubectl port-forward svc/grafana-service -n mla 3002:3000
}

glowroot() {
  local_url="http://localhost:4000"
  echo "glowroot at $local_url"
  open $local_url
  kubectl port-forward svc/main-glowroot-collector -n mla 4000:4000
}

start_automation() {
  kubectl scale --replicas=1 deploy -n ontrack-system ontrack-operator
  kubectl scale --replicas=1 deploy -n capabilities ontrack-operator
}

stop_automation() {
  kubectl scale --replicas=0 deploy -n ontrack-system ontrack-operator
  kubectl scale --replicas=0 deploy -n capabilities ontrack-operator
}

mongo() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <instance name>" >&2
    return 1
  fi
  # Mongo still needs this version stripping due to needing to get the hostname etc from resourcedata secret
  echo kubectl get secret "$1-resourcedata" -n "${1/-(master|develop|v1)/}" -o json
  mongo_secret=$(kubectl get secret "$1-resourcedata" -n "${1/-(master|develop|v1)/}" -o json | jq -er '.data | map_values(@base64d)')

  if [[ -z $mongo_secret ]]; then
    echo "could not connect to $1"
    return 1
  fi

  escaped_password=$(urlencode "$(echo "$mongo_secret" | jq -er '.MAIN_MONGO_PASSWORD')")
  user=$(echo -E "$mongo_secret" | jq -er '.MAIN_MONGO_USER')
  # user="qezzsznytpxyongclq"
  addr=$(echo -E "$mongo_secret" | jq -er '.MAIN_MONGO_HOST')
  port=$(echo -E "$mongo_secret" | jq -er '.MAIN_MONGO_PORT')
  db_name=$(echo -E "$mongo_secret" | jq -er '.MAIN_MONGO_DATABASE')
  # db_name="main"
  replica=$(echo -E "$mongo_secret" | jq -er '.MAIN_MONGO_REPLICA_SET_PARAM')
  echo "$addr"

  mong="mongodb://$user:$escaped_password@$addr:$port/$db_name$replica&authSource=$db_name"

  pod_status=$(kubectl get pods "$pod_name" -n "$(def_cap)" -o=jsonpath='{.status.phase}')
  if [[ "$pod_status" == "Running" ]]; then
    kubectl exec -it "$pod_name" -n "$(def_cap)" -- mongo "$mong"
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢 $(tput sgr0)"
    kubectl delete pod "$pod_name" -n "$(def_cap)" --grace-period=0 --force --ignore-not-found
    kubectl run -it --restart=Never "$pod_name" --image=moulick/debug-image:latest -n "$(def_cap)" -- mongo "$mong"
  fi
}

mq() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 active for broker -1 or $0 standby broker 2" >&2
    return 1
  fi

  mq_pod="mq-access-$1"
  local_url="https://localhost:8163/admin"

  mq_secret=$(kubectl get secret ontrack3-mq -n ontrack-system -o json | jq -er '.data | map_values(@base64d)')
  if [[ -z $mq_secret ]]; then
    echo "could get MQ secret"
    return 1
  fi
  addr=$(echo -E "$mq_secret" | jq -er '.ATMQ_WEB_CONSOLE')
  domain="${addr/(https:\/\/)/}"         # removes https:// from url for socat
  domain_standby="${domain/-1.mq/-2.mq}" # url for MQ is running in active/standby mode
  echo "$mq_secret" | jq -jer '.ACTIVE_MQ_PASSWORD' | pbcopy
  case $1 in
  active)
    web_url=$domain
    echo "$web_url"
    ;;
  standby)
    web_url=$domain_standby
    echo "$web_url"
    ;;
  *)
    echo "Usage: $0 active for broker -1 or $0 standby broker 2" >&2
    return 1
    ;;
  esac

  pod_status=$(kubectl get pods "$mq_pod" -n "$(def_cap)" -o=jsonpath='{.status.phase}')
  if [[ "$pod_status" == "Running" ]]; then
    echo "MQ at $local_url"
    open $local_url
    kubectl port-forward "$mq_pod" -n "$(def_cap)" 8163:80
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢 $(tput sgr0)"
    kubectl delete pod "$mq_pod" -n "$(def_cap)" --grace-period=0 --force --ignore-not-found
    echo "pushing kubectl run to backgroud"
    kubectl run -i --rm --tty "$mq_pod" -n "$(def_cap)" --image=alpine/socat --restart=Never tcp-listen:80,fork,reuseaddr tcp-connect:"$web_url" &
    sleep 5
    echo "MQ at $local_url"
    open $local_url
    kubectl port-forward "$mq_pod" -n "$(def_cap)" 8163:80
  fi
}

proxy() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 d/q/p" >&2
    return 1
  fi
  telepresence_namespace="default"

  case $1 in
  d)
    echo "Telepresense to D"
    kubectl delete pod --ignore-not-found "telepresense-$pod_name" -n "$telepresence_namespace"

    telepresence \
      --also-proxy hc-apigw-d-internal.hilti.com \
      --also-proxy hc-apigw-d.hilti.com \
      --also-proxy hc-webgate-d.hilti.com \
      --method=vpn-tcp \
      --new-deployment "telepresense-$pod_name" \
      --namespace "$telepresence_namespace"

    kubectl delete pod --ignore-not-found "telepresense-$pod_name" -n "$telepresence_namespace"
    ;;
  q)
    echo "Telepresense to Q"
    kubectl delete pod --ignore-not-found "telepresense-$pod_name" -n "$telepresence_namespace"

    telepresence \
      --also-proxy hc-apigw-q-internal.hilti.com \
      --also-proxy hc-apigw-q.hilti.com \
      --also-proxy hc-webgate-q.hilti.com \
      --method=vpn-tcp \
      --new-deployment "telepresense-$pod_name" \
      --namespace "$telepresence_namespace"

    kubectl delete pod --ignore-not-found "telepresense-$pod_name" -n "$telepresence_namespace"
    ;;
  p)
    echo "Telepresense to P"
    kubectl delete pod --ignore-not-found "telepresense-$pod_name" -n "$telepresence_namespace"

    telepresence \
      --also-proxy cloudapis.hilti.com \
      --also-proxy cloudapis-internal.hilti.com \
      --method=vpn-tcp \
      --new-deployment "telepresense-$pod_name" \
      --namespace "$telepresence_namespace"

    kubectl delete pod --ignore-not-found "telepresense-$pod_name" -n "$telepresence_namespace"
    ;;
  *)
    echo "Pure Telepresense"
    kubectl delete pod --ignore-not-found "telepresense-$pod_name" -n "$telepresence_namespace"

    telepresence \
      --method=vpn-tcp \
      --new-deployment "telepresense-$pod_name" \
      --namespace "$telepresence_namespace"

    kubectl delete pod --ignore-not-found "telepresense-$pod_name" -n "$telepresence_namespace"
    ;;
  esac
}

es() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 microservicename" >&2
    return 1
  fi

  pod="es-access-$1"
  local_url="https://localhost:8085/_plugin/kibana/app/kibana#/dev_tools/console?_g=()"

  secret=$(kubectl get secret "$1-resourcedata" -n "${1/-(master|develop|v1)/}" -o json | jq -er '.data | map_values(@base64d)')

  if [[ -z $secret ]]; then
    echo "could not connect to $1"
    return 1
  fi

  addr=$(echo "$secret" | jq -er '.ES_ELASTIC_HOST')
  port=$(echo "$secret" | jq -er '.ES_ELASTIC_PORT')
  domain="${addr/(https:\/\/)/}" # removes https:// from url for socat

  pod_status=$(kubectl get pods "$pod" -n "$(def_cap)" -o=jsonpath='{.status.phase}')
  if [[ "$pod_status" == "Running" ]]; then
    echo "ES at $local_url"
    open "$local_url"
    kubectl port-forward "$pod" -n "$(def_cap)" 8085:80
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢 $(tput sgr0)"
    kubectl delete pod "$pod" -n "$(def_cap)" --grace-period=0 --force --ignore-not-found
    echo "pushing kubectl run to backgroud"
    kubectl run -i --rm --tty "$pod" -n "$(def_cap)" --image=alpine/socat --restart=Never tcp-listen:80,fork,reuseaddr tcp-connect:"$domain:$port" &
    sleep 5
    echo "ES at $local_url"
    open "$local_url"
    kubectl port-forward "$pod" -n "$(def_cap)" 8085:80
  fi
}

waiter() {
  TIMEOUT=30
  retries=0
  echo "Waiting for localhost:8080"
  while ! (nc -w 3 -z localhost 8080); do
    sleep 1
    echo -n "."
    if [ $retries -eq $TIMEOUT ]; then
      echo "😱 Port Forward did not start, Timeout, aborting, mayday mayday 😱"
      exit 1
    fi
    retries=$((retries + 1))
  done
}
