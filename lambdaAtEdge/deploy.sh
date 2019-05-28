#! /bin/bash
# Deploy the LambdaAtEdge_template to create a CloudFront distribution with a Lambda to gate requests according to Cognito status

ARTIFACT_BUCKET="mr-artefacts"
S3_IMAGE_BUCKET="mr-cognito-images"
STACK_NAME="grafana-POC2-LambdaAtEdge"

# CloudFront can only reference lambdas in us-east-1.
# Artifact bucket should be in us-east-1.
# The image bucket does not need to be in us-east-1, though.
AWS_REGION="us-east-1"
PROFILE="sandboxDevOps"

# The idea here is that the code referenced in the template will be uploaded
# to the artifact bucket as a zip file. Then another template is written out
# with the correct reference to the artifact bucket
aws --region ${AWS_REGION} --profile ${PROFILE} cloudformation package \
    --template-file ./LambdaAtEdge_template.yaml \
	--s3-bucket ${ARTIFACT_BUCKET} \
	--output-template-file packaged.yaml

# This will deploy the 'packaged template' which correctly references the code
# The identity that is acting as the 'deployer' must have access to the artifact
# bucket in order to deploy the lambda function code in the template.
aws --region ${AWS_REGION} --profile ${PROFILE} cloudformation deploy \
    --template-file packaged.yaml \
	--stack-name ${STACK_NAME} \
	--capabilities "CAPABILITY_AUTO_EXPAND" "CAPABILITY_NAMED_IAM" "CAPABILITY_IAM" \
    --parameter-overrides BucketName=${S3_IMAGE_BUCKET}