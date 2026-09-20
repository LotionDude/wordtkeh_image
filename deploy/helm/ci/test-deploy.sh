#!/bin/sh
set -eu
# Exercise control flow with synthetic credentials and a fake Helm executable.
# No cluster connection or real secret is used by this test.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
mkdir "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/helm" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
  version) echo v3.19.0 ;;
  list)
    test -r "$KUBECONFIG"
    grep -q 'certificate-authority-data:' "$KUBECONFIG"
    if grep -q 'insecure-skip-tls-verify' "$KUBECONFIG"; then exit 90; fi
    test "$(stat -c %a "$KUBECONFIG")" = 600
    printf '%s' "$KUBECONFIG" > "$TEST_STATE"
    ;;
  lint) ;;
  upgrade)
    printf '%s\n' "$*" | grep -q -- '--install'
    printf '%s\n' "$*" | grep -q -- '--atomic --wait'
    printf '%s\n' "$*" | grep -q -- '--reset-values'
    if printf '%s\n' "$*" | grep -q -- '--create-namespace'; then exit 91; fi
    exit "${TEST_FAILURE:-0}"
    ;;
  status) echo 'Synthetic deployment succeeded' ;;
  *) exit 92 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/helm"
export PATH="$TEST_DIR/bin:$PATH"
export OPENSHIFT_SERVER=https://api.example.test:6443
export OPENSHIFT_TOKEN=synthetic-test-token
export KUBE_NAMESPACE=test-games
export HELM_RELEASE=verification
export HELM_VALUES_FILE="$TEST_DIR/values.yaml"
export OPENSHIFT_CA_FILE="$TEST_DIR/ca.pem"
export TEST_STATE="$TEST_DIR/state"
printf 'config: {}\n' > "$HELM_VALUES_FILE"
printf 'synthetic CA fixture\n' > "$OPENSHIFT_CA_FILE"
sh "$SCRIPT_DIR/deploy.sh" > "$TEST_DIR/output" 2>&1
test ! -e "$(cat "$TEST_STATE")"
if grep -q "$OPENSHIFT_TOKEN" "$TEST_DIR/output"; then exit 93; fi
export TEST_FAILURE=23
set +e
sh "$SCRIPT_DIR/deploy.sh" > "$TEST_DIR/output" 2>&1
RESULT=$?
set -e
test "$RESULT" = 23
test ! -e "$(cat "$TEST_STATE")"
if grep -q "$OPENSHIFT_TOKEN" "$TEST_DIR/output"; then exit 94; fi
echo 'Deployment script checks passed: private CA config, cleanup, atomic wait, failure propagation, no token logging.'
