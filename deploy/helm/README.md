# Wordtkeh chart

Copy this directory, including `.gitlab-ci.yml` and `ci/`, to the root of a separate
GitLab repository. Set `image.repository` and immutable `image.tag` manually. There
is no image build in this chart or pipeline. Default exposure is ClusterIP with
port-forward access; `values-openshift.yaml` enables a TLS edge Route and two replicas.

The application reads `config` as public JSON at `/config.json`. The ConfigMap mounts
at `/usr/share/nginx/html/config.json`; changes trigger a checksum-based rollout.
The complete shipped config is in values.yaml. Edit deployment overrides in your
selected values file; no credentials belong in config. Keep epoch and schedules
stable after publication. The initial epoch is 2026-10-01; set it before launch.

```sh
helm lint .
helm lint . -f values-openshift.yaml
helm template wordtkeh .
helm template wordtkeh . -f values-openshift.yaml
helm upgrade --install wordtkeh . -n games -f values-openshift.yaml --reset-values --atomic --wait --timeout 5m
helm history wordtkeh -n games
helm rollback wordtkeh 1 -n games --wait --timeout 5m
helm uninstall wordtkeh -n games
kubectl -n games port-forward service/wordtkeh-wordtkeh 8080:80
```

Namespace must already exist. Helm 3.19 is tested and pinned in CI. The master
branch and production environment must be protected. Required protected GitLab
variables: `OPENSHIFT_SERVER` (HTTPS API URL), `OPENSHIFT_TOKEN` (masked token),
`KUBE_NAMESPACE`, `HELM_RELEASE`. For private CAs use a protected File variable
`OPENSHIFT_CA_FILE` containing PEM trust material. Optional `HELM_VALUES_FILE`
defaults to `values-openshift.yaml`; `HELM_TIMEOUT` defaults to `5m`. The runner
only needs API access; Helm creates a temporary private kubeconfig with certificate
verification enabled. Do not enable CI debug tracing. There is no namespace creation
or insecure-TLS option. Jobs serialize through a production resource group.

The default security contexts omit fixed UIDs/fsGroup, drop all capabilities and
use non-root, read-only root, no privilege escalation and RuntimeDefault seccomp.
Only a bounded /tmp emptyDir is writable. No application API token is mounted.
Probes use /healthz:8080. Resource defaults are 25m/32Mi requests and 250m/128Mi
limits. Customize scheduling, image pull secrets, labels, annotations and probes
through values. Keep release/name overrides and reserved selector labels stable.

Ingress and Route are alternatives; never enable both. Ingress needs an existing
controller and TLS Secret. Route supports edge TLS only (HTTP backend), with router
certificate management. The OpenShift example enables HSTS at the TLS router;
remove that annotation if disabling TLS. No HSTS is emitted by the HTTP container.

For failed rollouts inspect pod events/logs and mounted config:

```sh
kubectl -n games describe pod POD_NAME
kubectl -n games logs deployment/wordtkeh-wordtkeh
kubectl -n games exec deployment/wordtkeh-wordtkeh -- cat /usr/share/nginx/html/config.json
oc -n games get route wordtkeh-wordtkeh
```

Health checks verify NGINX only; validate config semantics in the app before release.
Changing values rolls pods; reload browsers to apply new config. Helm rollback
restores prior image/config; preserve registry image tags. Uninstall does not erase
browser data. Test cluster admission, TLS, rollback and GitLab credentials in your
own environment before production.
