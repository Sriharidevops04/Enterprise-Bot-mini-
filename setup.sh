#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="demo"
NAMESPACE="demo"
RELEASE="demo"
IMAGE_NAME="eb-service"
IMAGE_TAG="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "==> [1/5] kind cluster '${CLUSTER_NAME}'"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "    cluster already exists, reusing it"
else
  KIND_CONFIG="$(mktemp)"
  cat > "${KIND_CONFIG}" <<'KIND_EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
KIND_EOF
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
  rm -f "${KIND_CONFIG}"
fi

kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

echo "==> [2/5] ingress-nginx controller"
if kubectl get ns ingress-nginx >/dev/null 2>&1 && \
   kubectl -n ingress-nginx get deploy ingress-nginx-controller >/dev/null 2>&1; then
  echo "    already installed, skipping re-apply (its admission Jobs are immutable on re-apply)"
else
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
fi

echo "    waiting for the controller Deployment to roll out..."
# NOTE: we deliberately wait on the Deployment's rollout status, not on a pod
# selector. `kubectl wait --selector=... pod` only matches pods that already
# exist at the moment it's called — right after `apply`, the Deployment
# object exists but its Pod hasn't been created yet, so a selector-based wait
# fails immediately with "no matching resources found" instead of polling.
# The Deployment object exists synchronously after apply, so rollout status
# has something to watch from the first instant and genuinely blocks until
# the pods underneath it are ready.
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s

echo "==> [3/5] building the service image"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" ./service

echo "==> [4/5] loading the image into the kind cluster"
kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "${CLUSTER_NAME}"

echo "==> [5/5] installing the chart as release '${RELEASE}' in namespace '${NAMESPACE}'"
helm upgrade --install "${RELEASE}" ./chart \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set image.repository="${IMAGE_NAME}" \
  --set image.tag="${IMAGE_TAG}" \
  --set ingress.host=demo.local \
  --wait --timeout=180s

echo ""
echo "==> done."
echo ""
echo "Verify (one-time): echo '127.0.0.1 demo.local' | sudo tee -a /etc/hosts"
echo "Then:"
echo "  curl http://demo.local/"
echo "  curl http://demo.local/healthz"
