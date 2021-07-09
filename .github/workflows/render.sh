#!/bin/bash
DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="main"

site_list=$(ls -d */ | sed 's/\///g' | grep -v 'docs')
if [ $# -eq 1 ]; then
  BRANCH=$1
elif [ $# -eq 2 ]; then
  BRANCH=$1
  site_list=$2
fi

echo "Fetch base with $BRANCH branch/tag........"
git clone -b $BRANCH $DECAPOD_BASE_URL
if [ $? -ne 0 ]; then
  exit $?
fi

for i in ${site_list}
do
  echo "Starting build manifests for '$i' site"

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
      echo "[$i] Successfully Completed!"
    else
      echo "[$i] Failed to render $app-manifest.yaml"
      exit 1
    fi
  done
done

