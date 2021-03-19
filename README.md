# decapod-site
This repository contains custom configurations for [decapod-base-yaml](https://github.com/openinfradev/decapod-base-yaml) and [decapod-flow](https://github.com/openinfradev/decapod-flow).  

## Documents
* [Render decapod-site-yaml](https://github.com/openinfradev/decapod-base-yaml/blob/main/docs/quickstart.md#render-decapod-site-yaml)
* [Make your own site-yaml](https://github.com/openinfradev/decapod-base-yaml/blob/main/docs/quickstart.md#make-your-own-site-yaml)
* [CI pipeline](docs/ci.md)

## Example

base(1) + site(2) => [variant](https://kubectl.docs.kubernetes.io/references/kustomize/glossary/#variant)(3)

1. _decapod-base-yaml/lma/base/resources.yaml_:
   ```yaml
   apiVersion: helm.fluxcd.io/v1
   kind: HelmRelease
   metadata:
   name: elasticsearch-operator
   spec:
   chart:
      repository: https://openinfradev.github.io/hanu-helm-repo
      name: elasticsearch-operator
      version: 1.0.3
   releaseName: elasticsearch-operator
   targetNamespace: elastic-system
   values:
      elasticsearchOperator:
         nodeSelector: {} # TO_BE_FIXED
   ```

2. _decapod-site-yaml/{your site name}/lma/site-values.yaml_:
   ```yaml
   apiVersion: openinfradev.github.com/v1
   kind: HelmValuesTransformer
   metadata:
   name: site

   global:
   nodeSelector:
      taco-lma: enabled

   charts:
   - name: elasticsearch-operator
   override:
      elasticsearchOperator.nodeSelector: $(nodeSelector)
   ```

3. _decapod-site-yaml/{your site name}/lma/lma-manifest.yaml_:
   ```yaml
   apiVersion: helm.fluxcd.io/v1
   kind: HelmRelease
   metadata:
   name: elasticsearch-operator
   spec:
   chart:
      repository: https://openinfradev.github.io/hanu-helm-repo
      name: elasticsearch-operator
      version: 1.0.3
   releaseName: elasticsearch-operator
   targetNamespace: elastic-system
   values:
      elasticsearchOperator:
         nodeSelector:
         taco-lma: enabled
   ```