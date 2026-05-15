# Session 01 — k3d + ArgoCD
## 15 Mai 2026

### Objectif
Poser les deux fondations du POC DxP : cluster Kubernetes local (k3d) et moteur GitOps (ArgoCD).

### Environnement
- Poste : Windows 11 · WSL2 Ubuntu 22.04
- Docker Engine natif dans WSL2
- Réseau : proxy Zscaler avec TLS inspection active
- k3d v5.7.4 · k3s v1.30.4 · ArgoCD v3.4.2

### Ce qu'on a fait
1. Création du cluster k3d `dxp-poc` (1 server + 2 agents)
2. Résolution du problème Zscaler (injection CA Root + Intermediate)
3. Pull des images ArgoCD + import dans k3d
4. Installation ArgoCD dans le namespace `argocd`
5. Exposition UI sur `https://localhost:9090`
6. Création du repo GitHub `dxp-poc-gitops`
7. Déploiement de l'app de test nginx via ArgoCD
8. Validation de la boucle GitOps end-to-end

### Décisions prises
- Docker Engine natif WSL2 (pas Docker Desktop) — plus simple pour les certs corporate
- Port-forward sur 9090 (8080 et 8443 réservés par k3d load balancer)
- Images pré-pullées et importées dans k3d pour contourner Zscaler
- Script `~/dxp-poc-prepull.sh` en dehors du repo (outil local, pas un manifeste)
- Documentation incrémentale : journal de session + guide de référence

### Problèmes rencontrés
| Problème | Cause | Solution |
|----------|-------|----------|
| `x509: certificate signed by unknown authority` | Zscaler TLS inspection | Injection CA Root + Intermediate dans WSL2 et Docker |
| Intermediate CA manquant | Chaîne Zscaler à 3 niveaux | Extraction via `openssl s_client` sur quay.io |
| Redis mauvaise version | ArgoCD v3.4.2 utilise `8.2.3-alpine` pas `7.0.15` | Vérification via le manifest install.yaml |
| `dex-idp` vs `dexidp` | Typo dans le namespace ghcr.io | Namespace correct : `dexidp` |
| Ports 8080/8443 occupés | Réservés par k3d load balancer | Port-forward sur 9090 |
| `ImagePullBackOff` sur nginx | Zscaler bloque le pull depuis le cluster | Pre-pull + `k3d image import` |

### État en fin de session
- ✅ Cluster k3d 3 nœuds Running
- ✅ ArgoCD v3.4.2 opérationnel
- ✅ Repo GitHub `dxp-poc-gitops` connecté
- ✅ App nginx déployée via GitOps
- ⚠️ `argocd-applicationset-controller` en CrashLoopBackOff (non bloquant)

### Prochaine session
- Backstage (Developer Portal)
- ou pipeline CI/CD
