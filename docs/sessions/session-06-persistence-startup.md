# Session 06 — Persistence Harbor + Script de démarrage
## 15 Mai 2026

### Objectif
Rendre LiteDxP redémarrable sans friction — Harbor persistent + script `dxp-start.sh`.

### Résultat
✅ Harbor avec persistence activée — données survivent au redémarrage
✅ Script `dxp-start.sh` — LiteDxP redémarre en une commande

### Ce qu'on a fait
1. Réinstallation Harbor avec `persistence.enabled=true`
2. Création du projet `dxp` et push de Kaniko
3. Mise à jour du `registries.yaml` avec la nouvelle IP Harbor
4. Création du script `dxp-start.sh` — automatise tout le démarrage
5. Test stop/start — script validé end-to-end

### Le script dxp-start.sh

```bash
k3d cluster start dxp-poc && ~/dxp-poc-gitops/infrastructure/dxp-start.sh
```

Ce que fait le script automatiquement :
- Démarre le cluster k3d
- Attend que les nœuds soient Ready
- Récupère l'IP dynamique de Harbor
- Met à jour `registries.yaml` sur les 3 nœuds
- Importe Kaniko depuis Harbor dans containerd
- Met à jour la Task Tekton avec la bonne IP
- Affiche les URLs d'accès

### Commandes DxP — résumé opérationnel

```bash
# Arrêter LiteDxP
k3d cluster stop dxp-poc

# Démarrer LiteDxP
k3d cluster start dxp-poc && ~/dxp-poc-gitops/infrastructure/dxp-start.sh

# Accès ArgoCD
kubectl port-forward svc/argocd-server -n argocd 9090:443
# → https://localhost:9090 · admin / (kubectl get secret argocd-initial-admin-secret...)

# Accès Harbor
kubectl port-forward -n harbor svc/harbor 9091:80
# → http://localhost:9091 · admin / Harbor12345

# Accès Vault
kubectl exec -n vault vault-0 -- vault status

# Lancer le pipeline CI
kubectl apply -f /tmp/pipeline-run-v3.yaml
kubectl get pods -w
```

### État en fin de session
- ✅ Harbor persistent — données survivent au redémarrage
- ✅ Script dxp-start.sh opérationnel
- ✅ LiteDxP stop/start validé
- ✅ Pipeline CI toujours fonctionnel après redémarrage

### Pourquoi la persistence est critique
Sans persistence, à chaque redémarrage :
- Harbor DB réinitialisée → projet dxp perdu → Kaniko perdu → pipeline cassé
- Vault secrets perdus
- Tout le travail de configuration perdu

Avec persistence (PVC k3s local) :
- Harbor garde ses projets, images, utilisateurs
- Un seul `dxp-start.sh` suffit pour tout remettre en ordre

### Prochaine session
- Backstage (Developer Portal)
- Ou rendre Vault persistent également
