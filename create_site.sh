#!/bin/bash

set -e

BASE_SITE="hanu-reference"

function usage {
        echo -e "\nUsage: ./$0 site_name [--helm-repo LOCAL_HELM_REPO --registry IMAGE_LOCAL_REGISTRY]"
        exit 1
}

# We use "$@" instead of $* to preserve argument-boundary information
ARGS=$(getopt -o 'h:r:' --long 'helm-repo:,registry:' -- "$@") || usage
eval "set -- $ARGS"

while true; do
    case $1 in
      (-h|--helm-repo)
            LOCAL_HELM_REPO=$2; shift 2;;
      (-r|--registry)
            LOCAL_REGISTRY=$2; shift 2;;
      (--)  shift; break;;
      (*)   exit 1;;           # error
    esac
done
SITE_NAME=("$@")

[ -z $SITE_NAME ] && echo 'Error: missing argument "site_name"' && usage
[ -e $SITE_NAME ] && echo "Error: \"$SITE_NAME\" already exists" && usage
[ ! -z $LOCAL_HELM_REPO ] && [ -z $LOCAL_REGISTRY ] && echo 'Error: Helm repo and Container registry must be specified together' && usage
[ -z $LOCAL_HELM_REPO ] && [ ! -z $LOCAL_REGISTRY ] && echo 'Error: Helm repo and Container registry must be specified together' && usage

[ ! -z $LOCAL_HELM_REPO ] && offline=true && echo "Helm repo: "$LOCAL_HELM_REPO
[ ! -z $LOCAL_REGISTRY ] && echo "Container Image Registry: "$LOCAL_REGISTRY
export LOCAL_HELM_REPO
export LOCAL_REGISTRY

if [ "$offline" = true ]
then
	BASE_SITE="hanu-reference-offline"
fi

echo "=== new site $SITE_NAME is creating from $BASE_SITE..."

cp -r $BASE_SITE $SITE_NAME

if [ "$offline" = true ]
then
	for yaml in $(find $SITE_NAME -type f -name site-values.yaml -o -name image-values.yaml)
        do
		cp $yaml .tmp-yaml
                cat .tmp-yaml | envsubst '$LOCAL_HELM_REPO $LOCAL_REGISTRY' > $yaml
		rm .tmp-yaml
        done
fi
