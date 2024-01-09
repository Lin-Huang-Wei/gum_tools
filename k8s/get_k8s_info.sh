#!/bin/bash

source ./aws_info.sh

function _k8s_config_update() {
  local region=${region}
  local clusterName=${clusterName}
  gum log --time="DateTime" --structured --level info $(aws eks update-kubeconfig --region ${region} --name ${clusterName})
}

function _k8s_change_ns() {
  local namespace=$(kubectl get namespace -o json | jq -r '.items[].metadata.name' | gum choose --height 15)
  export CUREENT_K8S_NAMESPACE=${namespace}
  gum log --time="DateTime" --structured --level info $(kubectl config set-context --current --namespace=${namespace})
}

function _get_pod_secrets() {
  local pod_secrets=$(kubectl get secrets -n ${CUREENT_K8S_NAMESPACE} --field-selector type=Opaque -o custom-columns=NAME:.metadata.name --no-headers)

  [[ -z ${pod_secrets} ]] && gum log --time="DateTime" --structured --level error "Couldn't find the Secret belonging to pods." && exit 1
  result=$(gum choose --no-limit ${pod_secrets})
  gum style --padding "1 5" --border double --border-foreground 212 "${result}"

  pod_secrets_lists=(${result})
  [[ -z ${result} ]] && gum log --time="DateTime" --structured --level error "You must have to pick one, please try again" && exit 1

  gum confirm "Are these what you want to do ?"
  if [ $? -eq 0 ]; then
    for (( m=0; m<${#pod_secrets_lists[@]}; m++ )); do
      [[ -f Secret-${pod_secrets_lists[$m]}.md ]] && rm -rf Secret-${pod_secrets_lists[$m]}.md
      echo "| Secret Name |  Secret Key | Secret Values |" | tee -a Secret-${pod_secrets_lists[$m]}.md
      echo "| --- | --- | --- |" | tee -a Secret-${pod_secrets_lists[$m]}.md
      kubectl get secrets -n ${CUREENT_K8S_NAMESPACE} ${pod_secrets_lists[$m]} -o jsonpath='{.data}' | jq -r "to_entries[] | \"| ${pod_secrets_lists[$m]} |\(.key) | \(.value) |\"" | tee -a Secret-${pod_secrets_lists[$m]}.md
      echo ""
    done
  fi
}

function _get_pod_cm() {
  local pod_configmaps=$(kubectl get cm -n ${CUREENT_K8S_NAMESPACE} -o custom-columns=NAME:.metadata.name --no-headers | grep -v kube-root-ca.crt)

  [[ -z ${pod_configmaps} ]] && gum log --time="DateTime" --structured --level error "Couldn't find the configMap belonging to pods." && exit 1
  result=$(gum choose --height 15 ${pod_configmaps})
  gum confirm "You pick ${result} ?"

  if [ $? -eq 0 ]; then
    for name in ${result}; do
      [[ -f ConfigMap-${name}.md ]] && rm -rf ConfigMap-${name}.md
      echo "| ConfigMap Name |  ConfigMap Key | ConfigMap Values |" | tee -a ConfigMap-${name}.md
      echo "| --- | --- | --- |" | tee -a ConfigMap-${name}.md
      kubectl get cm -n ${CUREENT_K8S_NAMESPACE} ${name} -o yaml  | yq -r '.data.*' | jq -r ". | to_entries[] | \"| ${name} | \(.key) | \(.value) |\"" | tee -a ConfigMap-${name}.md
    done
  fi
}

while true; do
  menu_options=("1. Update ${HOME}/.kube/config" "2. Change the namespace" "3. Get Secret belonging to pods" "4. Get configMap belonging to pods" "5. Exit")
  choice=$(gum choose --no-limit "${menu_options[@]}")

  case "${choice}" in
    "${menu_options[0]}")
      _k8s_config_update
      ;;
    "${menu_options[1]}")
      _k8s_change_ns
      ;;
    "${menu_options[2]}")
      _k8s_change_ns
      _get_pod_secrets
      ;;
    "${menu_options[3]}")
      _k8s_change_ns
      _get_pod_cm
      ;;
    "${menu_options[4]}")
      echo "Exiting the program."
      exit 1
      ;;
    *)
      gum log --time="DateTime" --structured --level error "Invalid option. Please try again."
      echo ""
      sleep 1
      ;;
  esac
done
