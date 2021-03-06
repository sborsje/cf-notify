#!/usr/bin/env bash

test $(which pwgen)
if [ $? != "0" ]; then
    echo -e "pwgen not found. Please install using 'sudo apt-get install pwgen' (GNU/Linux) or 'brew install pwgen' (OSX)"
    exit 1
fi

if [ $# -lt 1 ]
then
    echo "usage: $0 <CHANNEL> <WEBHOOK>"
    exit 1
fi

CHANNEL=$1
WEBHOOK=$2

if [ -z $CHANNEL ];
then
    echo "Please specify a Slack Channel e.g #general or @me";
    exit 1
fi

if [ -z $WEBHOOK ];
then
    echo "Please specify a Slack WebHook";
    exit 1
fi

if [ ${CHANNEL:0:1} != '#' ] && [ ${CHANNEL:0:1} != '@' ];
then
    echo ${CHANNEL:0:1}
    echo 'Invalid Channel. Slack channels begin with # or @'
    exit 1
fi

CHANNEL_NAME=`echo ${CHANNEL:1} | tr '[:upper:]' '[:lower:]'`

echo 'Creating bucket'
BUCKET="cf-notify-$CHANNEL_NAME-`pwgen -1 --no-capitalize 5`"
echo $BUCKET
aws s3 mb "s3://$BUCKET"
echo "Bucket $BUCKET created"


echo 'Creating lambda zip artifact'
cat > slack.py <<EOL
WEBHOOK='$WEBHOOK'
CHANNEL='$CHANNEL'
EOL

zip cf-notify.zip lambda_notify.py slack.py
echo 'Lambda artifact created'


echo 'Moving lambda artifact to S3'
aws s3 cp cf-notify.zip s3://$BUCKET/cf-notify-$CHANNEL_NAME.zip

rm slack.py
rm cf-notify.zip
echo 'Lambda artifact moved'

echo 'Creating stack'
aws cloudformation create-stack \
    --template-body file://cf-notify.json \
    --stack-name cf-notify-$CHANNEL_NAME \
    --capabilities CAPABILITY_IAM \
    --parameters ParameterKey=Bucket,ParameterValue=$BUCKET ParameterKey=Channel,ParameterValue=$CHANNEL_NAME
echo 'Stack created'