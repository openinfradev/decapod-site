#!/bin/bash
DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="develop"
# DOCKER_IMAGE_REPO="docker.io"
DOCKER_IMAGE_REPO="harbor.taco-cat.xyz/tks"
GITHUB_IMAGE_REPO="ghcr.io"
outputdir="output"

site_list=$(ls -d */ | sed 's/\///g' | grep -v 'docs' | grep -v $outputdir | grep -v 'offline')

function usage {
        echo -e "\nUsage: $0 [--site TARGET_SITE] [--base_url DECAPOD_BASE_URL] [--registry REGISTRY_URL]"
        exit 1
}

# We use "$@" instead of $* to preserve argument-boundary information
ARGS=$(getopt -o 'b:s:r:h' --long 'base-url:,site:,registry:,help' -- "$@") || usage
eval "set -- $ARGS"

while true; do
    case $1 in
      (-h|--help)
            usage; shift 2;;
      (-b|--base-url)
            DECAPOD_BASE_URL=$2; shift 2;;
      (-s|--site)
            site_list=$2; shift 2;;
      (-r|--registry)
            DOCKER_IMAGE_REPO=$2
            GITHUB_IMAGE_REPO=$2; shift 2;;
      (--)  shift; break;;
      (*)   exit 1;;           # error
    esac
done

echo "[render-cd] dacapod branch=$BRANCH, output target=$outputdir ,target site(s)=${site_list}\n\n"

echo "Fetch base with $BRANCH branch/tag........"
git clone -b $BRANCH $DECAPOD_BASE_URL
if [ $? -ne 0 ]; then
  exit $?
fi

mkdir $outputdir

for site in ${site_list}
do
  echo "[render-cd] Starting build manifests for '$site' site"

  for app in `ls $site/`
  do
    echo docker run --rm -i --net=host -v $(pwd):/decapod -v $(pwd)/$outputdir:/output --name generate ${DOCKER_IMAGE_REPO}/decapod-render:v3.0.0 -b /decapod/decapod-base-yaml/$app/base/resources.yaml -o /decapod/$site/$app/site-values.yaml --output /output/$site/$app
    docker run --rm -i --net=host -v $(pwd):/decapod -v $(pwd)/$outputdir:/output --name generate ${DOCKER_IMAGE_REPO}/decapod-render:v3.0.0 -b /decapod/decapod-base-yaml/$app/ -o /decapod/$site/$app/site-values.yaml --output /output/$site/$app
    sudo mkdir $outputdir/$site/$app/CRD
    
    echo "Move every CustomResourceDefinition to $outputdir/$site/$app/CRD"
    for i in `find $outputdir/$site/$app | grep CustomResourceDefinition | grep -v '/CRD/'` 
    do 
      sudo mv $i $outputdir/$site/$app/CRD
    done
  done

  # Post processes for the customized action
  #   Action1. change the namespace for cluster-resouces from argo to cluster-name
  echo "Almost finished: changing namespace for cluster-resouces from argo to cluster-name.."
  sudo sed -i "s/ namespace: argo/ namespace: $site/g" $(pwd)/$outputdir/$site/tks-cluster/cluster-api-aws/*
  sudo sed -i "s/ - argo/ - $site/g" $(pwd)/$outputdir/$site/tks-cluster/cluster-api-aws/*
  sudo sed -i "s/ namespace: argo/ namespace: $site/g" $(pwd)/$outputdir/$site/tks-cluster/cluster-api-byoh/*
  sudo sed -i "s/ - argo/ - $site/g" $(pwd)/$outputdir/$site/tks-cluster/cluster-api-byoh/*
  # It's possible besides of two above but very tricky!!
  # sudo sed -i "s/ argo$/ $site/g" $(pwd)/$outputdir/$site/tks-cluster/cluster-api-aws/*
  echo "---
apiVersion: v1
kind: Namespace
metadata:
  name: $site
  labels:
    name: $site
    # It bring the secret 'dacapod-argocd-config' using kubed
    decapod-argocd-config: enabled
" > Namespace_rc.yaml
  sudo cp Namespace_rc.yaml $(pwd)/$outputdir/$site/tks-cluster/cluster-api-aws/
  sudo cp Namespace_rc.yaml $(pwd)/$outputdir/$site/tks-cluster/cluster-api-byoh/
  # End of Post process
done

rm -rf decapod-base-yaml
