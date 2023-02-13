#!/bin/bash
set -ex

VALIDATE_TARGET_REPO='https://harbor-cicd.taco-cat.xyz/tks'
EXCEPTION_LIST='appscode/kubed:v0.12.0,appscode/kubed:v0.12.0-rc.3,busybox:1.31,busybox:1.31.1,calico/cni:v3.15.5,calico/kube-controllers:v3.15.5,calico/node:v3.15.5,calico/pod2daemon-flexvol:v3.15.5,directxman12/k8s-prometheus-adapter-amd64:v0.7.0,docker.elastic.co/eck/eck-operator:1.8.0,docker.elastic.co/elasticsearch/elasticsearch:7.5.1,docker.elastic.co/kibana/kibana:7.5.1,docker.io/bitnami/kube-state-metrics:1.9.7-debian-10-r143,docker.io/bitnami/minio:2021.6.14-debian-10-r0,docker.io/bitnami/postgresql:11.7.0-debian-10-r98,docker.io/bitnami/postgresql:15.1.0-debian-11-r0,docker.io/bitnami/thanos:0.17.2-scratch-r1,docker.io/grafana/loki:2.6.1,docker.io/grafana/promtail:2.4.1,docker.io/jboss/keycloak:10.0.0,docker.io/ncabatoff/process-exporter:0.2.11,docker.io/nginxinc/nginx-unprivileged:1.19-alpine,docker:19.03,ghcr.io/openinfradev/fluentbit:25bc31cd4333f7f77435561ec70bc68e0c73a194,ghcr.io/resmoio/kubernetes-event-exporter:v1.0,grafana/grafana:8.3.3,istio/pilot:1.13.1,istio/proxyv2:1.13.1,jaegertracing/jaeger-operator:1.29.1,k8s.gcr.io/autoscaling/cluster-autoscaler:v1.22.2,k8s.gcr.io/hyperkube:v1.18.8,k8s.gcr.io/ingress-nginx/controller:v1.1.1@sha256:0bc88eb15f9e7f84e8e56c14fa5735aaa488b840983f87bd79b1054190e660de,k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.0@sha256:f3b6b39a6062328c095337b4cadcefd1612348fdd5190b1dcbcb9b9e90bd8068,k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.1.1@sha256:64d8c73dca984af206adf9d6d7e46aa550362b1d7a01f3a0a91b20cc67868660,k8s.gcr.io/metrics-server/metrics-server:v0.6.1,kubesphere/fluent-operator:v1.5.0,prom/pushgateway:v1.3.0,quay.io/airshipit/kubernetes-entrypoint:v1.0.0,quay.io/argoproj/argocli:v3.2.6,quay.io/argoproj/workflow-controller:v3.2.6,quay.io/bitnami/sealed-secrets-controller:v0.16.0,quay.io/keycloak/keycloak-operator:17.0.0,quay.io/kiali/kiali-operator:v1.45.1,quay.io/kiwigrid/k8s-sidecar:1.14.2,quay.io/prometheus-operator/prometheus-operator:v0.52.0,quay.io/prometheus/alertmanager:v0.23.0,quay.io/prometheus/node-exporter:v1.0.1,quay.io/prometheus/prometheus:v2.31.1,rancher/local-path-provisioner:v0.0.22,siim/logalert-exporter:v0.1.1,sktdev/cloud-console:v1.0.4,sktdev/os-eventrouter:69a58b,fluent/fluent-bit:1.9.7-debug,k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.0,k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.0'
if [ $EXCEPTION_LIST ]; then
  EXCEPTION_ARG="-e $EXCEPTION_LIST"
else
  EXCEPTION_ARG=
fi

DECAPOD_BASE_URL=https://github.com/openinfradev/decapod-base-yaml.git
BRANCH="main"
DOCKER_IMAGE_REPO="docker.io"
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

pip install shyaml

echo "[validate image repositories] dacapod branch=$BRANCH, output target=$outputdir.\n\n"

echo "Fetch base with $BRANCH branch/tag........"
git clone -b $BRANCH $DECAPOD_BASE_URL
if [ $? -ne 0 ]; then
  exit $?
fi

for site in ${site_list}
do
  echo "[validate image repositories] Starting build manifests for '$site' site"

  for app in `ls $site/`
  do
    # helm-release file name rendered on 1st phase
    hr_file="decapod-base-yaml/$app/$site/$app-manifest.yaml"
    mkdir decapod-base-yaml/$app/$site
    cp -r $site/$app/*.yaml decapod-base-yaml/$app/$site/

    echo "Rendering $hr_file"
    docker run --rm -i -v $(pwd)/decapod-base-yaml/$app:/$app --name kustomize-build ${DOCKER_IMAGE_REPO}/sktcloud/decapod-render:v3.1.0  kustomize build --enable-alpha-plugins /${app}/${site} -o /$app/$site/$app-manifest.yaml
    build_result=$?

    if [ $build_result != 0 ]; then
      exit $build_result
    fi

    if [ -f "$hr_file" ]; then
      echo "[$app] Successfully Generate Helm-Release Files!"
    else
      echo "[$app] Failed to render $app-manifest.yaml"
      exit 1
    fi

    docker run --rm -i --net=host -v $(pwd)/decapod-base-yaml:/decapod-base-yaml --name generate ${DOCKER_IMAGE_REPO}/sktcloud/decapod-render:v3.1.0 helm2yaml/check_repo.py -m /$hr_file -r $VALIDATE_TARGET_REPO -t image $EXCEPTION_ARG

    ## Coner-case handling section begins
    if [ $app = "lma" ]; then
      awk '{f="split_" NR; print $0 > f}' RS='---' decapod-base-yaml/lma/${site}/lma-manifest.yaml
      for i in `ls split_*`; do
        if [ $(cat $i|shyaml get-value metadata.name) = 'prometheus-operator' ]; then
          [ $(cat $i | shyaml get-value spec.values.prometheusOperator.thanosImage.repository) = "${VALIDATE_TARGET_REPO}*" ] || exit 1
          [ $(cat $i | shyaml get-value spec.values.prometheusOperator.prometheusConfigReloader.image.repository) = "${VALIDATE_TARGET_REPO}*" ] || exit 1
        fi
      done
      rm split_*
      exit 1
    # elif [ $app = "servicemesh" ]; then
    #   echo "yahoo ServiceMesh"
    fi

    ## Coner-case handling section ends
    rm -f $hr_file

  done
done

rm -rf decapod-base-yaml

