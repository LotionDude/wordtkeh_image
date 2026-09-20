#!/bin/sh
set -eu
# Never enable shell tracing: credentials are expanded only into a private file.
: "${OPENSHIFT_SERVER:?Set OPENSHIFT_SERVER}"
: "${OPENSHIFT_TOKEN:?Set a masked protected OPENSHIFT_TOKEN}"
: "${KUBE_NAMESPACE:?Set KUBE_NAMESPACE}"
: "${HELM_RELEASE:?Set HELM_RELEASE}"
case "$OPENSHIFT_SERVER" in https://*) ;; *) echo 'OPENSHIFT_SERVER must use HTTPS' >&2; exit 1;; esac
case "$OPENSHIFT_SERVER" in *[!a-zA-Z0-9:/._-]*) echo 'Invalid API URL' >&2; exit 1;; esac
case "$OPENSHIFT_TOKEN" in *[!a-zA-Z0-9._~/-]*) echo 'Invalid token format' >&2; exit 1;; esac
case "$KUBE_NAMESPACE" in *[!a-z0-9-]*) echo 'Invalid namespace' >&2; exit 1;; esac
case "$HELM_RELEASE" in *[!a-z0-9-]*) echo 'Invalid release name' >&2; exit 1;; esac
case "$(helm version --short)" in v3.*) ;; *) echo 'This pipeline requires Helm 3 (--atomic)' >&2; exit 1;; esac
umask 077
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM
export KUBECONFIG="$WORK_DIR/kubeconfig"
CA_LINE=''
if [ -n "${OPENSHIFT_CA_FILE:-}" ]; then
  test -r "$OPENSHIFT_CA_FILE"
  CA_DATA=$(base64 < "$OPENSHIFT_CA_FILE" | tr -d '\n\r')
  CA_LINE="    certificate-authority-data: $CA_DATA"
fi
cat > "$KUBECONFIG" <<EOF
apiVersion: v1
kind: Config
clusters:
- name: production
  cluster:
    server: $OPENSHIFT_SERVER
$CA_LINE
users:
- name: deployer
  user:
    token: $OPENSHIFT_TOKEN
contexts:
- name: production
  context:
    cluster: production
    user: deployer
    namespace: $KUBE_NAMESPACE
current-context: production
EOF
unset OPENSHIFT_TOKEN CA_DATA CA_LINE
# Authenticated API/namespace reachability check; no oc binary or in-cluster runner needed.
helm list --namespace "$KUBE_NAMESPACE" --max 1 > /dev/null
VALUES_FILE=${HELM_VALUES_FILE:-values-openshift.yaml}
test -f "$VALUES_FILE"
helm lint . -f "$VALUES_FILE"
helm upgrade --install "$HELM_RELEASE" . \
  --namespace "$KUBE_NAMESPACE" --values "$VALUES_FILE" \
  --reset-values --atomic --wait --timeout "${HELM_TIMEOUT:-5m}" --history-max 10
helm status "$HELM_RELEASE" --namespace "$KUBE_NAMESPACE"
