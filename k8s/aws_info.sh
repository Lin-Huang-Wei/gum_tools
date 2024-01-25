#!/bin/bash

[[ ! -f $(command -v gum) ]] && gum log --time="DateTime" --structured --level error "Could not find gum command, please install from [github](https://github.com/charmbracelet/gum)" && exit 1
[[ ! -d ${HOME}/.aws ]] && gum log --time="DateTime" --structured --level error "Could not find ${HOME}/.aws, please run 'aws configure sso --profile xxx' to setup"

echo '{{ Bold "Please enter where your" }} {{ Color "208" "AWS_CONFIG_FILE path" }} {{ Bold "?" }}' | gum format -t template
AWS_CONFIG_PATH=$(gum input \
  --cursor.foreground "#FFA500"\
  --prompt.foreground "#6495ED" \
  --prompt ">>> " \
  --placeholder "${HOME}/.aws/config" \
  --width 80 \
  --value "${HOME}/.aws/config"
)

[[ -n "${AWS_CONFIG_PATH}" ]] && [[ -f "${AWS_CONFIG_PATH}" ]];
[[ $? -ne 0 ]] && gum log --time="DateTime" --structured --level error "You enter the wrong path or empty value. Please try again."
gum style \
  --border-foreground 212 \
  --border double  \
  --margin "1 2" \
  --padding "1 5" \
  --align left \
  "AWS CONFIG PATH: ${AWS_CONFIG_PATH}"
gum confirm "Are you sure ?"; [[ $? -ne 0 ]] && exit 1
export AWS_CONFIG_FILE=${AWS_CONFIG_PATH}

echo '{{ Bold "Please choose which" }} {{ Color "208" "AWS profile" }} {{ Bold "you prefer to use." }}' | gum format -t template
[[ -f ${AWS_CONFIG_FILE} ]] &&  profileName=$(aws configure list-profiles | gum choose --limit 1)
check_aws_login=$(aws sts get-caller-identity --profile ${profileName} 2> /dev/null)
if [[ $? -eq 0 ]]; then
  gum log --time="DateTime" --structured --level info "Success login"
else
  gum log --time="DateTime" --structured --level error "The SSO session associated with this profile has expired or is otherwise invalid. To refresh this SSO session run aws sso login with the corresponding profile."
  aws sso login --profile ${profileName}
fi

region=$(aws configure get sso_region --profile ${profileName})
echo '{{ Bold "Please choose which" }} {{ Color "27" "K8S Cluster" }} {{ Bold "you prefer to use." }}' | gum format -t template
clusterName=$(aws eks list-clusters --profile ${profileName} | jq -r '.clusters[]' | gum choose --limit 1)
gum style \
  --border-foreground 212 \
  --border double  \
  --margin "1 2" \
  --padding "1 5" \
  --align left \
  "AWS Profile: ${profileName}" \
  "AWS Region: ${region}" \
  "AWS EKS Name: ${clusterName}"

  gum confirm "Are you sure ?"



