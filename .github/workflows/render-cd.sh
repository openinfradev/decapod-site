#!/bin/bash
DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="main"
CD_FILE_TARGET_URL=https://github.com/openinfradev/decapod-site-cd.git
CD_BRANCH="main"

if [ $# -eq 1 ]; then
  BRANCH=$1
fi

site_list=$(ls -d */ | sed 's/\///g' | grep -v 'docs')
echo "Fetch base with $BRANCH branch/tag........"
git clone -b $BRANCH $DECAPOD_BASE_URL
if [ $? -ne 0 ]; then
  exit $?
fi
git clone -b $CD_BRANCH $CD_FILE_TARGET_URL cd
if [ $? -ne 0 ]; then
  exit $?
fi

for i in ${site_list}
do
  echo "Starting build manifests for '$i' site"

  for app in `ls $i/`
  do
    output="$i/$app/$app-manifest.yaml"
    cp -r decapod-base-yaml/$app/base $i/
    echo "Rendering $app-manifest.yaml for $i site"
    docker run --rm -i -v $(pwd)/$i:/$i --name kustomize-build sktdev/decapod-kustomize:latest kustomize build --enable_alpha_plugins /$i/$app -o /$i/$app/$app-manifest.yaml
    build_result=$?

    if [ $build_result != 0 ]; then
      exit $build_result
    fi

    if [ -f "$output" ]; then
      echo "[$i, $app] Successfully Generate Helm-Release Files!"
    else
      echo "[$i, $app] Failed to render $app-manifest.yaml"
      rm -rf $i/base decapod-yaml
      exit 1
    fi

    docker run --rm -i -v $(pwd)/$i:/$i -v $(pwd)/cd:/cd --name generate siim/helmrelease2yaml:1.0.0 $output cd/$i/$app

    rm -rf $i/base
  done
done

rm -rf decapod-base-yaml
