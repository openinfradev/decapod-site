#!/bin/bash
DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="main"

if [ $# -eq 0 ]; then
  echo 'Error: Missing Arguments "site name"'
  exit 1
fi
SITE_NAME=$1

git clone $DECAPOD_BASE_URL .base-yaml
for i in `ls -d .base-yaml/*/ | grep -v docs | sed 's/.base-yaml\///g'`
do
  mkdir -p $SITE_NAME/$i
  cp .base-yaml/${i}base/site-values.yaml $SITE_NAME/$i
  kustomization="$SITE_NAME/${i}kustomization.yaml"
  echo "resources:" > $kustomization
  echo "  - ../base" >> $kustomization
  echo "transformers:" >> $kustomization
  echo "  - site-values.yaml" >> $kustomization
done

rm -rf .base-yaml