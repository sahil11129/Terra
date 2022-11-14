#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

eval "$(jq -r '@sh "API_KEY=\(.ibmcloud_api_key) ZONE=\(.datacenter)"')"

echo $(ibmcloud login --apikey ${API_KEY}) > /dev/null

i="0"
re='^[0-9]+$'
publicVLAN=noVLAN
privateVLAN=noVLAN

while ! [[ $publicVLAN =~ $re ]] && ! [[ $privateVLAN =~ $re ]] && [[ $i -lt 10 ]]; do
    publicVLAN=$(ibmcloud sl vlan list -d ${ZONE} --output json | jq -c '.[] | select(.networkSpace | contains("PUBLIC"))' | jq -r .id | head -n 1)
    privateVLAN=$(ibmcloud sl vlan list -d ${ZONE} --output json | jq -c '.[] | select(.networkSpace | contains("PRIVATE"))' | jq -r .id | head -n 1)
    i=$[$i+1]
    sleep 5
done

if ! [[ $publicVLAN =~ $re ]] || ! [[ $privateVLAN =~ $re ]]; then
    echo "Unable to get VLANs for ${ZONE}. Please try again." 1>&2
    exit 1
fi

jq -n --arg publicVLAN "$publicVLAN" --arg privateVLAN "$privateVLAN" '{"publicVLAN":$publicVLAN, "privateVLAN":$privateVLAN}'