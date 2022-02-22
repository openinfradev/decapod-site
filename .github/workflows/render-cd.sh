#!/bin/bash
DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="main"
DOCKER_IMAGE_REPO="docker.io"
GITHUB_IMAGE_REPO="ghcr.io"
outputdir="output"

rm -rf decapod-base-yaml
site_list=$(ls -d */ | sed 's/\///g' | grep -v 'docs' | grep -v 'output' | grep -v 'offline')

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

for i in ${site_list}
do
  echo "[render-cd] Starting build manifests for '$i' site"

  for app in `ls $i/`
  do
    output="decapod-base-yaml/$app/$i/$app-manifest.yaml"
    mkdir decapod-base-yaml/$app/$i
    cp -r $i/$app/*.yaml decapod-base-yaml/$app/$i/

    echo "Rendering $app-manifest.yaml for $i site"
    docker run --rm -i -v $(pwd)/decapod-base-yaml/$app:/$app --name kustomize-build ${DOCKER_IMAGE_REPO}/sktdev/decapod-kustomize:latest kustomize build --enable_alpha_plugins /$app/$i -o /$app/$i/$app-manifest.yaml
    build_result=$?

    if [ $build_result != 0 ]; then
      exit $build_result
    fi

    if [ -f "$output" ]; then
      echo "[render-cd] [$i, $app] Successfully Generate Helm-Release Files!"
    else
      echo "[render-cd] [$i, $app] Failed to render $app-manifest.yaml"
      rm -rf $i/base decapod-yaml
      exit 1
    fi

    # cat $output
    docker run --rm -i --net=host -v $(pwd)/decapod-base-yaml:/decapod-base-yaml -v $(pwd)/$outputdir:/cd --name generate ${DOCKER_IMAGE_REPO}/sktcloud/helmrelease2yaml:v1.5.0 -m $output -t -o /cd/$i/$app
    rm $output

    rm -rf $i/base
  done
done

rm -rf decapod-base-yaml
