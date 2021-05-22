#!/bin/bash

def_cap="capabilities"
pod_name="$(id -un | tr '.' '-')-debug"
alias kpf="kubectl port-forward"

urlencode() {
  # urlencode <string>
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
urldecode() {
  # urldecode <string>
  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

kdebug() {
  pod_status=$(kubectl get pods "$pod_name" -n $def_cap -o=jsonpath='{.status.phase}')
  if [[ "$pod_status" == "Running" ]]; then
    kubectl exec -it "$pod_name" -n $def_cap -- bash
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢 $(tput sgr0)"
    kubectl delete pod "$pod_name" -n $def_cap --grace-period=0 --force --ignore-not-found
    kubectl run -it --restart=Never "$pod_name" --image=moulick/debug-image:latest -n $def_cap -- bash
  fi
}

db_shell() {
  if [ "$#" -ne 5 ]; then
    echo "Usage: $0 user pass url port db_name" >&2
    return 1
  fi

  user=$1
  pass=$2
  url=$3
  port=$4
  db_name=$5

  postg="postgresql://$user:$pass@$url:$port/$db_name"

  pod_status=$(kubectl get pods "$pod_name" -n $def_cap -o=jsonpath='{.status.phase}')

  if [[ "$pod_status" == "Running" ]]; then
    kubectl exec -it "$pod_name" -n $def_cap -- psql "$postg"
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢, making a new one $(tput sgr0)"
    kubectl delete pod "$pod_name" --ignore-not-found -n $def_cap --grace-period=0 --force --ignore-not-found
    kubectl run -it --restart=Never "$pod_name" --image=moulick/debug-image:latest -n $def_cap -- psql "$postg"
  fi
}

alfresco() {
  db_shell alfresco alfresco alfresco-postgresql-acs.catalogue-doc-mgmt 5432 alfresco
}

in-cluster-post() {

  secret=$(kubectl get secret "$1-main-postgresql" -n "${1/-(master|develop|v1)/}" -o json | jq -r '.data | map_values(@base64d)')
  if [[ -z $secret ]]; then
    echo "could not connect to $1"
    return 1
  fi

  escaped_password=$(urlencode "$(echo "$secret" | jq -r '.MAIN_PASSWORD')")

  user=$(echo "$secret" | jq -r '.MAIN_USERNAME')
  addr="helm-$1-main-postgresql.${1/-(master|develop|v1)/}"
  port="5432"
  db_name="main"
  echo "${addr}"

  db_shell "$user" "$escaped_password" "$addr" "$port" "$db_name"
}

rds() {
  secret=$(kubectl get secret "$1-main-postgresql" -n "${1/-(master|develop|v1)/}" -o json | jq -er '.data | map_values(@base64d)')

  if [[ -z $secret ]]; then
    echo "could not connect to $1"
    return 1
  fi

  escaped_password=$(urlencode "$(echo "$secret" | jq -er '.MASTER_PASSWORD')")
  echo "$secret" | jq -r '.DB_INSTANCE_IDENTIFIER'

  user=$(echo "$secret" | jq -er '.MASTER_USERNAME')
  addr=$(echo "$secret" | jq -er '.ENDPOINT_ADDRESS')
  port=$(echo "$secret" | jq -er '.PORT')
  db_name=$(echo "$secret" | jq -er '.DB_NAME')

  db_shell "$user" "$escaped_password" "$addr" "$port" "$db_name"
}

argo() {
  local_url="http://localhost:8083"
  echo "argo at $local_url"
  open-chrome $local_url
  kpf svc/argocd-server -n capabilities 8083:80
}

logs() {
  local_url="http://localhost:5602"
  echo "kibana at $local_url"
  open-chrome $local_url
  kpf svc/kibana-kb-http -n capabilities 5602:5601
}

logs-etoe() {
  local_url="http://localhost:5603"
  echo "kibana at $local_url"
  open-chrome $local_url
  kpf svc/kibana-etoe-kb-http -n capabilities 5603:5601
}

grafana() {
  local_url="http://localhost:3002"
  echo "grafana at $local_url"
  open-chrome $local_url
  kpf svc/grafana-service -n capabilities 3002:3000
}

glowroot() {
  local_url="http://localhost:4000"
  echo "glowroot at $local_url"
  open-chrome $local_url
  kpf svc/glowroot-collector -n capabilities 4000:4000
}

start_automation() {
  kubectl scale --replicas=1 deploy -n capabilities ontrack-operator
}

stop_automation() {
  kubectl scale --replicas=0 deploy -n capabilities ontrack-operator
}

mongo() {
  echo kubectl get secret "$1-resourcedata" -n "${1/-(master|develop|v1)/}" -o json
  secret=$(kubectl get secret "$1-resourcedata" -n "${1/-(master|develop|v1)/}" -o json | jq -er '.data | map_values(@base64d)')

  if [[ -z $secret ]]; then
    echo "could not connect to $1"
    return 1
  fi

  escaped_password=$(urlencode "$(echo "$secret" | jq -er '.MAIN_MONGO_PASSWORD')")
  user=$(echo "$secret" | jq -er '.MAIN_MONGO_USER')
  addr=$(echo "$secret" | jq -er '.MAIN_MONGO_HOST')
  port=$(echo "$secret" | jq -er '.MAIN_MONGO_PORT')
  db_name=$(echo "$secret" | jq -er '.MAIN_MONGO_DATABASE')
  replica=$(echo "$secret" | jq -er '.MAIN_MONGO_REPLICA_SET_PARAM')
  echo "$addr"

  mong="mongodb://$user:$escaped_password@$addr:$port/$db_name$replica&authSource=$db_name"

  pod_status=$(kubectl get pods "$pod_name" -n $def_cap -o=jsonpath='{.status.phase}')
  if [[ "$pod_status" == "Running" ]]; then
    kubectl exec -it "$pod_name" -n $def_cap -- mongo "$mong"
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢 $(tput sgr0)"
    kubectl delete pod "$pod_name" -n $def_cap --grace-period=0 --force --ignore-not-found
    kubectl run -it --restart=Never "$pod_name" --image=moulick/debug-image:latest -n $def_cap -- mongo "$mong"
  fi
}

mq() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 active for broker -1 or $0 standby broker 2" >&2
    return 1
  fi

  mq_pod="mq-access-$1"
  local_url="https://localhost:8163/admin"

  secret=$(kubectl get secret ontrack3-mq -n ontrack-system -o json | jq -er '.data | map_values(@base64d)')
  if [[ -z $secret ]]; then
    echo "could get MQ secret"
    return 1
  fi
  addr=$(echo "$secret" | jq -er '.ATMQ_WEB_CONSOLE')
  domain="${addr/(https:\/\/)/}" # removes https:// from url for socat
  domain_standby="${domain/-1.mq/-2.mq}" # url for MQ is running in active/standby mode

  case $1 in
  active)
    web_url=$domain
    echo "$secret" | jq -er '.ACTIVE_MQ_PASSWORD' | pbcopy
    echo "$web_url"
    ;;
  standby)
    web_url=$domain_standby
    echo "$secret" | jq -er '.ACTIVE_MQ_PASSWORD' | pbcopy
    echo "$web_url"
    ;;
  *)
    echo "Usage: $0 active for broker -1 or $0 standby broker 2" >&2
    return 1
    ;;
  esac

  pod_status=$(kubectl get pods "$mq_pod" -n $def_cap -o=jsonpath='{.status.phase}')
  if [[ "$pod_status" == "Running" ]]; then
    echo "MQ at $local_url"
    open-chrome $local_url
    kpf "$mq_pod" -n capabilities 8163:80
  else
    # tput setaf 1 = red
    echo "$(tput setaf 1)Pod not found or dead 😢 $(tput sgr0)"
    kubectl delete pod "$mq_pod" -n $def_cap --grace-period=0 --force --ignore-not-found
    echo "pushing kubectl run to backgroud"
    kubectl run -i --rm --tty "$mq_pod" -n capabilities --image=alpine/socat --restart=Never tcp-listen:80,fork,reuseaddr tcp-connect:"$web_url" &
    sleep 5
    echo "MQ at $local_url"
    open-chrome $local_url
    kpf "$mq_pod" -n capabilities 8163:80
  fi
}

open-chrome() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 url" >&2
    return 1
  fi
  open -a "/Applications/Google Chrome.app" $1
}
