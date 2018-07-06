#!/usr/bin/env bash
if [ $# -ne 1 ]; then
	echo "please specify a stack name"
	exit 1
fi
STACKNAME=$1
aws cloudformation describe-stacks --stack-name=${STACKNAME} | jq '.Stacks[0].Outputs'
