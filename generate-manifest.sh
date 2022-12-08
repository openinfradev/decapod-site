#!/bin/bash
COMMIT_ID=fc42dbf4527a0f64f808d99a49e16b3a573b31f5

# same with rende-cd.sh
DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="main"
DOCKER_IMAGE_REPO="docker.io"
GITHUB_IMAGE_REPO="ghcr.io"
outputdir="output"

rm -rf decapod-base-yaml
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

if [ $COMMIT_ID ]
then
  echo "reset to $COMMIT_ID"
  cd decapod-base-yaml
  git reset ${COMMIT_ID} --hard
  cd -
fi

mkdir -p $outputdir

for site in ${site_list}
do
  echo "[render-cd] Starting build manifests for '$site' site"

  for app in `ls $site/`
  do
    # helm-release file name rendered on 1st phase
    hr_file="decapod-base-yaml/$app/$site/$app-manifest.yaml"
    mkdir decapod-base-yaml/$app/$site
    cp -r $site/$app/*.yaml decapod-base-yaml/$app/$site/

    echo "Rendering $app-manifest.yaml for $site site"
    docker run --rm -i -v $(pwd)/decapod-base-yaml/$app:/$app --name kustomize-build ${DOCKER_IMAGE_REPO}/sktcloud/helm2yaml:v3.0.0  kustomize build --enable-alpha-plugins /${app}/${site} -o /$app/$site/$app-manifest.yaml
    build_result=$?

    if [ $build_result != 0 ]; then
      exit $build_result
    fi

    if [ -f "$hr_file" ]; then
      echo "[render-cd] [$site, $app] Successfully Generate Helm-Release Files!"
    else
      echo "[render-cd] [$site, $app] Failed to render $app-manifest.yaml"
      exit 1
    fi

    mv $hr_file $outputdir
  done

  # End of Post process
done

chown siim:siim -R .
#rm -rf decapod-base-yaml
