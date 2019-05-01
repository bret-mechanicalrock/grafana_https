ARTIFACT_BUCKET= #something a bucket provided just for deployment to hold the code - empty
S3_IMAGE_BUCKET= #something else provided for Austal's vessel images
STACK_NAME = #provide desired name for deployment

# This template must be deployed in us-east-1 because CloudFront can
# only reference lambdas in us-east-1.
# Artifact bucket should be in us-east-1.
# The image bucket does not need to be in us-east-1 though.
AWS_REGION=us-east-1

# sam is an alias for 'aws cloudformation'
# The idea here is that the code referenced in the template will be uploaded
# to the artifact bucket as a zip file. Then another template is written out
# with the correct reference to the artifact bucket
sam package --template-file ./template.yaml \
	--s3-bucket $(ARTIFACT_BUCKET) --output-template-file packaged.yaml

# This will deployed the 'packaged template' which correctly references the code
# The identity that is acting as the 'deployer' must have access to the artifact
# bucket in order to deploy the lambda function code in the template.
sam deploy --template-file packaged.yaml --stack-name $(STACK_NAME) \
		--capabilities CAPABILITY_IAM,CAPABILITY_AUTO_EXPAND \
        --parameter-overrides BucketName=$(S3_IMAGE_BUCKET)