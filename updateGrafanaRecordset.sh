#!/bin/bash
# updateGrfanaRecordset.sh

NO_AVAIALABLE_REDIRECT_CODE=1
AWS_REGION="ap-southeast-2"
# The profile which sets the account to act in
PROFILE="sandboxDevOps"
# The target of the redirect
new_target="GrafanaLB-370208854.ap-southeast-2.elb.amazonaws.com"
# The Route 53 hosted zone
HOSTED_ZONE='mrsandbox.rocks.'
# The prefix to add to the hosted zone to produce the URL
URL_PREFIX='grafana'
# The site we intend to update
export DNS_REDIRECT="${URL_PREFIX}.${HOSTED_ZONE}"

echo "AWS_REGION is: ${AWS_REGION}"
HOSTED_ZONE_QUERY="HostedZones[?Name==\`${HOSTED_ZONE}\`].Id|[0]"

# Acquire TARGET of re-direct
MRSANDBOX_ROCKS_HOSTED_ZONE=`aws --profile ${PROFILE} --region ${AWS_REGION} route53 list-hosted-zones --query ${HOSTED_ZONE_QUERY}`

echo "MRSANDBOX_ROCKS_HOSTED_ZONE is ${MRSANDBOX_ROCKS_HOSTED_ZONE}"
ZONE=`echo $MRSANDBOX_ROCKS_HOSTED_ZONE | cut -d\" -f2`
echo "ZONE is ${ZONE}"
RECORDSET_QUERY="ResourceRecordSets[?Type==\`CNAME\` && Name==\`$DNS_REDIRECT\`].ResourceRecords[0]|[0].Value"
echo "Recordset query is ${RECORDSET_QUERY}"

ROUTE53_TARGET=`aws --profile ${PROFILE} --region ${AWS_REGION} route53 list-resource-record-sets --hosted-zone-id "${ZONE}" --query "${RECORDSET_QUERY}"`
echo "Route53 re-directs ${DNS_REDIRECT} to ${ROUTE53_TARGET}"

if [[ "$ROUTE53_TARGET" == "null" ]]; then
  # if no re-direct, no further queries
  echo "No current Route53 DNS re-direct for ${DNS_REDIRECT} - unable to update non-existent stack."
  exit ${NO_AVAIALABLE_REDIRECT_CODE}
fi

echo ""
echo "Attempting redirect of ${DNS_REDIRECT} to ${new_target} in Route53 Hosted Zone ${ZONE}"
INPUT_JSON_STR="{ \"ChangeBatch\": { \"Comment\": \"Update ${DNS_REDIRECT} re-direct\", \"Changes\": [ { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"${DNS_REDIRECT}\", \"Type\": \"CNAME\", \"TTL\": 120, \"ResourceRecords\": [ { \"Value\": \"${new_target}\" } ] } } ] } }"
REDIRECT_RESULT=`aws --profile ${PROFILE} --region ${AWS_REGION} route53 change-resource-record-sets --hosted-zone-id "${ZONE}" --cli-input-json "$INPUT_JSON_STR" --query 'ChangeInfo.Id'`
echo "REDIRECT_RESULT  is ${REDIRECT_RESULT}"
RESULT=`echo $REDIRECT_RESULT | cut -d\" -f2`
echo "RESULT is ${RESULT}"

until [[ "$REDIRECT_STATUS" =~ "INSYNC" ]];
  do
    REDIRECT_STATUS=`aws --profile ${PROFILE} --region ${AWS_REGION} route53 get-change --id ${RESULT} --query 'ChangeInfo.Status'`;
    echo "REDIRECT_STATUS is ${REDIRECT_STATUS}";
    sleep 120;
  done
