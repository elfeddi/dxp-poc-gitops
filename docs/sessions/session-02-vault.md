# Session 02 — Vault
## 15 Mai 2026

### Objectif
Installer HashiCorp Vault comme gestionnaire de secrets centralisé de LiteDxP.

### Environnement
- Vault v1.21.2 · Helm chart v0.32.0
- Mode : dev (inmem, single node, unsealed automatiquement)
- Namespace : `vault`

### Ce qu'on a fait
1. Diagnostic ressources — GitLab consommait 4.6 GiB (60% RAM) → arrêté
2. Ajout du repo Helm HashiCorp
3. Identification des images nécessaires (vault:1.21.2 + vault-k8s:1.7.2)
4. Pre-pull des images + import dans k3d (procédure Zscaler)
5. Installation Vault via Helm en mode dev
6. Vérification du statut (Initialized + Unsealed)
7. Création du premier secret `secret/dxp/test`
8. Push du values.yaml dans le repo GitOps

### Décisions prises
- Mode dev pour le POC — pas de HA, storage inmem, token root fixe
- Namespace dédié `vault` — isolation des composants infrastructure
- Structure `infrastructure/` dans le repo GitOps — séparation apps vs infra

### Problèmes rencontrés
| Problème | Cause | Solution |
|----------|-------|----------|
| RAM insuffisante (~1.5 GiB libre) | GitLab tournait en arrière-plan | `docker stop gitlab gitlab-runner gitlab-runner-stable` |
| Aucun autre problème | Images sur Docker Hub — pas de Zscaler issue cette fois | Pre-pull systématique appliqué |

### Commandes clés

```bash
# Statut Vault
kubectl exec -n vault vault-0 -- vault status

# Login
kubectl exec -n vault vault-0 -- vault login root

# Écrire un secret
kubectl exec -n vault vault-0 -- vault kv put secret/dxp/test \
  username="dxp-admin" password="supersecret123"

# Lire un secret
kubectl exec -n vault vault-0 -- vault kv get secret/dxp/test
```

### État en fin de session
- ✅ Vault v1.21.2 Running (mode dev)
- ✅ Agent injector Running
- ✅ Premier secret créé et lu
- ✅ values.yaml versionnée dans GitOps
- ⚠️ Mode dev — données perdues au redémarrage du pod (normal pour le POC)

### Prochaine session
- Tekton (pipelines CI/CD)
- ou Harbor (registry images)
