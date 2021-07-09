#!/bin/bash
DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="main"

rm -rf decapod-base-yaml

site_list=$(ls -d */ | sed 's/\///g' | grep -v 'docs' | grep -v 'cd')

outputdir="cd"
if [ $# -eq 1 ]; then
  BRANCH=$1
elif [ $# -eq 2 ]; then
  BRANCH=$1
  outputdir=$2
elif [ $# -eq 3 ]; then
  BRANCH=$1
  outputdir=$2
  site_list=$3
fi

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
    docker run --rm -i -v $(pwd)/decapod-base-yaml/$app:/$app --name kustomize-build sktdev/decapod-kustomize:latest kustomize build --enable_alpha_plugins /$app/$i -o /$app/$i/$app-manifest.yaml
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
    docker run --rm -i --net=host -v $(pwd)/decapod-base-yaml:/decapod-base-yaml -v $(pwd)/$outputdir:/cd --name generate ghcr.io/openinfradev/helmrelease2yaml:v1.3.0 -m $output -t -o /cd/$i/$app
    rm $output

    rm -rf $i/base
  done
done

rm -rf decapod-base-yaml
