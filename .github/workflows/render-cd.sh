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

for site in ${site_list}
do
  echo "Starting build manifests for '$site' site"

  for app in `ls $site/`
  do
    output="$site/$app/$app-manifest.yaml"
    cp -r decapod-base-yaml/$app/base $site/
    echo "Rendering $app-manifest.yaml for $site site"
    docker run --rm -i -v $(pwd)/$site:/$site --name kustomize-build sktdev/decapod-kustomize:latest kustomize build --enable_alpha_plugins /$site/$app -o /$site/$app/$app-manifest.yaml
    build_result=$?

    if [ $build_result != 0 ]; then
      exit $build_result
    fi

    if [ -f "$output" ]; then
      echo "[$site, $app] Successfully Generate Helm-Release Files!"
      cat $output
    else
      echo "[$site, $app] Failed to render $app-manifest.yaml"
      rm -rf $site/base decapod-yaml
      exit 1
    fi

    docker run --rm -i -v $(pwd)/$site:/$site -v $(pwd)/cd:/cd --name generate siim/helmrelease2yaml:1.0.0 $output cd/$site/$app

    rm -rf $site/base
  done
done

rm -rf decapod-base-yaml
