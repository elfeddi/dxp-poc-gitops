#!/bin/bash
# DxP LiteDxP — Script de démarrage
# Usage : ./dxp-start.sh

set -e

echo "🚀 Démarrage LiteDxP..."

# 1. Démarrer le cluster
k3d cluster start dxp-poc
echo "✅ Cluster démarré"

# 2. Attendre que les nœuds soient Ready
kubectl wait --for=condition=Ready nodes --all --timeout=60s
echo "✅ Nœuds Ready"

# 3. Récupérer l'IP Harbor
HARBOR_IP=$(kubectl get svc -n harbor harbor -o jsonpath='{.spec.clusterIP}')
echo "📦 Harbor IP: $HARBOR_IP"

# 4. Mettre à jour registries.yaml avec la bonne IP
for node in k3d-dxp-poc-server-0 k3d-dxp-poc-agent-0 k3d-dxp-poc-agent-1; do
  docker exec $node sh -c "cat > /etc/rancher/k3s/registries.yaml << YAML
mirrors:
  cgr.dev:
    endpoint:
      - \"https://cgr.dev\"
  gcr.io:
    endpoint:
      - \"https://gcr.io\"
  $HARBOR_IP:
    endpoint:
      - \"http://$HARBOR_IP\"
  harbor.harbor.svc.cluster.local:
    endpoint:
      - \"http://$HARBOR_IP\"
configs:
  \"cgr.dev\":
    tls:
      insecure_skip_verify: true
  \"gcr.io\":
    tls:
      insecure_skip_verify: true
  \"$HARBOR_IP\":
    tls:
      insecure_skip_verify: true
  \"harbor.harbor.svc.cluster.local\":
    tls:
      insecure_skip_verify: true
YAML"
done
echo "✅ registries.yaml mis à jour"

# 5. Importer Kaniko depuis Harbor dans containerd
for node in k3d-dxp-poc-server-0 k3d-dxp-poc-agent-0 k3d-dxp-poc-agent-1; do
  docker exec $node ctr images pull --plain-http $HARBOR_IP/dxp/kaniko:latest 2>/dev/null || true
done
echo "✅ Kaniko importé"

# 6. Mettre à jour la Task Tekton
kubectl patch task kaniko-build-push --type=json -p="[
  {\"op\":\"replace\",\"path\":\"/spec/steps/0/image\",\"value\":\"$HARBOR_IP/dxp/kaniko:latest\"}
]" 2>/dev/null || true
echo "✅ Task Tekton mise à jour"

echo ""
echo "🎉 LiteDxP est prêt !"
echo "   ArgoCD  → https://localhost:9090 (kubectl port-forward svc/argocd-server -n argocd 9090:443)"
echo "   Harbor  → http://localhost:9091  (kubectl port-forward -n harbor svc/harbor 9091:80)"
echo "   Vault   → kubectl exec -n vault vault-0 -- vault status"

# 7. Lancer les port-forwards
kubectl port-forward svc/argocd-server -n argocd 9090:443 &>/dev/null &
kubectl port-forward -n harbor svc/harbor 9091:80 &>/dev/null &

echo "🌐 Interfaces accessibles :"
echo "   ArgoCD → https://localhost:9090"
echo "   Harbor → http://localhost:9091"
