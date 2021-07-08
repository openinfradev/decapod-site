#!/bin/bash
DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="main"

pwd
ls

if [ $# -eq 1 ]; then
  BRANCH=$1
fi

site_list=$(ls -d */ | sed 's/\///g' | grep -v 'docs' | grep -v 'cd')
echo "Fetch base with $BRANCH branch/tag........"
git clone -b $BRANCH $DECAPOD_BASE_URL
if [ $? -ne 0 ]; then
  exit $?
fi
mkdir cd

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
      echo "[$i, $app] Successfully Generate Helm-Release Files!"
      cat $output
    else
      echo "[$i, $app] Failed to render $app-manifest.yaml"
      exit 1
    fi

    docker run --rm -i -v $(pwd)/decapod-base-yaml:/decapod-base-yaml -v $(pwd)/cd:/cd --name generate siim/helmrelease2yaml:1.0.0 $output cd/$i/$app
  done
done

rm -rf decapod-base-yaml
