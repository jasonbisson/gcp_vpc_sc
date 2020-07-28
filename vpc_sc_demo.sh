#!/bin/bash
#set -x
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[[ "$#" -ne 4 ]] && { echo "Usage : `basename "$0"` --dns-domain <your_dns_domain> --service-account"; exit 1; }
[[ "$1" = "--dns-domain" ]] &&  export org_name=$2
[[ "$3" = "--service-account" ]] &&  export SERVICE_ACCOUNT=$4

export project_id=$(gcloud config list --format 'value(core.project)')
export project_number=$(gcloud projects list |grep $project_id |awk '{print $3}')
export org_id=$(gcloud organizations list --format=[no-heading] | grep ${org_name} | awk '{print $2}')
export perimeter_name="big_data_security_fence"
export initial_services="storage.googleapis.com,bigquery.googleapis.com"
export add_services="pubsub.googleapis.com"
export CLIENT_IP_ADDRESS=$(curl -s ifconfig.co)
export ACCESS_IP_TEMPLATE="allowedips.template.yaml"
export ACCESS_IP="/tmp/allowedips.yaml"
export ACCESS_SERVICE_ACCOUNT_TEMPLATE="allowedusers.template.yaml"
export ACCESS_SERVICE_ACCOUNT="/tmp/allowedusers.yaml"
export ACCESS_IP_SERVICE_ACCOUNT_TEMPLATE="allowedips_users.template.yaml"
export ACCESS_IP_SERVICE_ACCOUNT="/tmp/allowedips_users.yaml"

QUIET=0

function ask_for_confirmation {
    if [ $QUIET -eq 1 ]; then
        return 0
    fi
    read -p "${1} [y/N] " yn
    case $yn in
        [Yy]* )
            return 0
        ;;
        * )
            exit 1
        ;;
    esac
}

function check_variables () {
    if [  -z "$project_id" ]; then
        printf "ERROR: GCP PROJECT_ID is not set.\n\n"
        printf "To update project config: gcloud config set project PROJECT_ID \n\n"
        exit
    fi
    
    if [  -z "$project_number" ]; then
        printf "ERROR: GCP PROJECT NUMBER is not set.\n\n"
        printf "To update project config: gcloud config set project PROJECT_ID \n\n"
        exit
    fi
    
    if [  -z "$org_id" ]; then
        printf "ERROR: GCP Organization id is not set.\n\n"
        printf "Confirm permission with this command: gcloud organizations list \n\n"
        exit
    fi
    
    if [  -z "$CLIENT_IP_ADDRESS" ]; then
        printf "ERROR: Your session IP was not set.\n\n"
        printf "Confirm access to set IP address or manually set: curl http://ipecho.net/plain \n\n"
        exit
    fi
    
    if [  -z "$SERVICE_ACCOUNT" ]; then
        printf "ERROR: The Service account was not set.\n\n"
        printf "Run the script again with --service-account argument \n\n"
        exit
    fi
}

function update_ip_template () {
    sed "s/\$CLIENT_IP_ADDRESS/${CLIENT_IP_ADDRESS}/g" $ACCESS_IP_TEMPLATE > $ACCESS_IP
}

function update_user_template () {
    sed "s/\$SERVICE_ACCOUNT/${SERVICE_ACCOUNT}/g" $ACCESS_SERVICE_ACCOUNT_TEMPLATE > $ACCESS_SERVICE_ACCOUNT
}

function update_ip_user_template () {
    sed "s/\$SERVICE_ACCOUNT/${SERVICE_ACCOUNT}/g;s/\$CLIENT_IP_ADDRESS/${CLIENT_IP_ADDRESS}/g" $ACCESS_IP_SERVICE_ACCOUNT_TEMPLATE > $ACCESS_IP_SERVICE_ACCOUNT
}

function enable_api () {
    gcloud services list --enabled |grep accesscontextmanager.googleapis.com
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Access Context Manager API enabled"
    else
        gcloud services enable accesscontextmanager.googleapis.com
    fi
}

function create_policy () {
    RESULT=$(gcloud  access-context-manager policies list --organization=$org_id |wc -l)
    if [ $RESULT -eq 0 ]; then
        gcloud  access-context-manager policies create --organization=$org_id --title $org_name
    fi
    export policy_id=$(gcloud  access-context-manager policies list --organization=$org_id |grep $org_name |awk '{print $1}')
    echo "Access Context Manager Policy $policy_id created"
}

function create_perimeter () {
    gcloud access-context-manager perimeters create $perimeter_name --title="$perimeter_name for $org_name" --resources=projects/$project_number --restricted-services=$initial_services --policy=$policy_id
}

function list_perimeter () {
    perimeter_name=$(gcloud  access-context-manager perimeters list --policy=$policy_id |grep $perimeter_name |awk '{print $1}')
    gcloud access-context-manager perimeters describe $perimeter_name --policy=$policy_id
}

function update_perimeter () {
    gcloud access-context-manager perimeters update $perimeter_name --title="$perimeter_name for $org_name" --add-restricted-services=$add_services --policy=$policy_id
}

function add_service_accounts () {
    gcloud access-context-manager levels create service_accounts --title "Service Accounts" --basic-level-spec=$ACCESS_SERVICE_ACCOUNT --policy=$policy_id
    gcloud access-context-manager perimeters update $perimeter_name --add-access-levels service_accounts --policy=$policy_id
}

function add_ip_subnet () {
    gcloud access-context-manager levels create ip_subnets --title "IP subnets" --basic-level-spec=$ACCESS_IP --combine-function=OR --policy=$policy_id
    gcloud access-context-manager perimeters update $perimeter_name --add-access-levels ip_subnets --policy=$policy_id
}

function add_service_account_or_ip () {
    gcloud access-context-manager levels create service_account_ips --title "Service Account or IPs" --basic-level-spec=$ACCESS_IP_SERVICE_ACCOUNT --combine-function=OR --policy=$policy_id
    gcloud access-context-manager perimeters update $perimeter_name --add-access-levels service_account_ips --policy=$policy_id
}

function delete_perimeter () {
    gcloud access-context-manager perimeters delete $perimeter_name --policy=$policy_id
}

function delete_policy () {
    gcloud access-context-manager policies delete $policy_id
}

function disable_api () {
    gcloud services disable accesscontextmanager.googleapis.com
}

function clear_access () {
    gcloud access-context-manager perimeters update $perimeter_name --clear-access-levels --policy=$policy_id
}

check_variables
update_ip_template
update_user_template
update_ip_user_template
ask_for_confirmation 'Are you sure you want to enable Access Context Manager API?'
enable_api
ask_for_confirmation 'Are you sure you want to create an Access Context Manager Policy for Organization?'
create_policy
ask_for_confirmation 'Are you sure you want to create a VPC Service Control Perimeter?'
create_perimeter
list_perimeter
ask_for_confirmation 'Are you sure you want to update a VPC Service Control Perimeter?'
update_perimeter
list_perimeter
ask_for_confirmation 'Are you sure you want to add a Service Account to access level?'
add_service_accounts
list_perimeter
ask_for_confirmation 'Are you sure you want to add an IP Subnet to access level?'
clear_access
add_ip_subnet
list_perimeter
ask_for_confirmation 'Are you sure you want to add an Service account or IP Subnet to access level?'
clear_access
add_service_account_or_ip
list_perimeter
ask_for_confirmation 'Are you sure you want to remove all access levels from VPC Service Control Perimeter?'
clear_access
ask_for_confirmation 'Are you sure you want to delete a VPC Service Control Perimeter?'
delete_perimeter
ask_for_confirmation 'Are you sure you want to delete a VPC Service Control Policy?'
delete_policy
ask_for_confirmation 'Are you sure you want to disable Access Context Manager API?'
disable_api
