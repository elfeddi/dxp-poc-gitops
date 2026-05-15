# Chapitre 02 — GitOps & ArgoCD · Le moteur de déploiement

> **Série :** DxP Academy · Stack 0 — Control Plane  
> **Niveau :** Débutant → Intermédiaire  
> **Durée de lecture :** ~10 minutes

---

## Le problème du déploiement traditionnel

Dans la plupart des équipes, déployer une application ressemble à ça :

1. Un développeur finit une feature
2. Il envoie un email ou ouvre un ticket à l'équipe ops
3. L'ops se connecte au serveur en SSH
4. Il exécute des commandes à la main
5. Peut-être ça marche, peut-être pas
6. Si ça casse, on ne sait pas exactement ce qui a changé

**Les problèmes :**
- Pas de traçabilité — qui a déployé quoi, quand ?
- Pas de rollback facile — comment revenir en arrière ?
- Déploiements manuels = erreurs humaines
- L'état réel du serveur diverge de ce qui est documenté
- "Ça marche sur ma machine" → catastrophe en prod

---

## C'est quoi GitOps ?

**GitOps** est une approche où **Git est la source de vérité absolue** de l'infrastructure et des applications.

Le principe fondamental :
> Tout ce qui tourne en production doit être décrit dans Git. Si ce n'est pas dans Git, ça n'existe pas.

### Les 4 principes GitOps

| Principe | Description |
|----------|-------------|
| **Déclaratif** | On décrit l'état désiré, pas les étapes pour y arriver |
| **Versionné** | Tout est dans Git — historique complet, rollback trivial |
| **Automatique** | Un agent surveille Git et applique les changements |
| **Réconcilié** | L'agent corrige automatiquement les dérives |

### Déclaratif vs Impératif

**Impératif** (traditionnel) :
```bash
# Je dis COMMENT faire
ssh serveur
docker stop mon-app
docker pull mon-app:v2
docker run mon-app:v2
```

**Déclaratif** (GitOps) :
```yaml
# Je dis CE QUE je veux
# deployment.yaml
spec:
  replicas: 3
  image: mon-app:v2
```
→ Kubernetes se charge du "comment".

---

## C'est quoi ArgoCD ?

**ArgoCD** est l'agent GitOps pour Kubernetes. Il surveille un repo Git en continu et s'assure que le cluster correspond exactement à ce qui est décrit dans Git.

```
┌─────────────┐     surveille     ┌─────────────┐
│  Repo Git   │ ◄──────────────── │   ArgoCD    │
│  (GitHub)   │                   │   (agent)   │
└─────────────┘                   └──────┬──────┘
      │                                  │ applique
      │ push                             ▼
      │                          ┌─────────────┐
      └─────────────────────────►│  Kubernetes │
                                 │  (cluster)  │
                                 └─────────────┘
```

### Le cycle GitOps avec ArgoCD

```
1. Développeur : git push → GitHub
          ↓
2. ArgoCD détecte le changement (polling toutes les 3 min)
          ↓
3. ArgoCD compare : état Git ≠ état cluster
          ↓
4. ArgoCD applique les manifestes dans Kubernetes
          ↓
5. État cluster = état Git ✅
```

### Les états d'une application ArgoCD

| État | Signification |
|------|---------------|
| **Synced** ✅ | Cluster = Git. Tout est en ordre. |
| **OutOfSync** ⚠️ | Git a changé, cluster pas encore mis à jour |
| **Progressing** 🔄 | Synchronisation en cours |
| **Degraded** ❌ | Application déployée mais pods en erreur |
| **Missing** | Application définie dans ArgoCD mais absente du cluster |

---

## La structure du repo GitOps

Un repo GitOps bien structuré sépare les applications de l'infrastructure :

```
dxp-poc-gitops/
├── apps/                    ← applications métier
│   ├── nginx/
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── mon-app/
│       └── ...
└── infrastructure/          ← composants plateforme
    ├── vault/
    │   └── values.yaml
    ├── tekton/
    └── backstage/
```

### Les manifestes Kubernetes

Un manifeste c'est un fichier YAML qui décrit une ressource Kubernetes :

```yaml
# deployment.yaml — "je veux 1 pod nginx"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: dxp-demo
spec:
  replicas: 1                    # nombre de copies
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine      # l'image Docker à utiliser
        ports:
        - containerPort: 80
```

---

## Dans DxP, ArgoCD joue quel rôle ?

ArgoCD est le **moteur de déploiement GitOps** de DxP. Toute mise en production passe par lui — aucun déploiement manuel n'est autorisé.

### Le flux de déploiement DxP

```
Développeur
    │ git push
    ▼
GitHub (dxp-poc-gitops)
    │ ArgoCD surveille
    ▼
ArgoCD détecte le changement
    │ applique
    ▼
Kubernetes déploie
    │ notifie
    ▼
LGTM observe (Stack 2)
```

### Pourquoi c'est puissant

**Rollback en 30 secondes :**
```bash
# Git revient en arrière
git revert HEAD
git push
# ArgoCD détecte et rollback automatiquement
```

**Audit trail complet :**
Chaque déploiement = un commit Git. On sait exactement qui a déployé quoi, quand, et pourquoi (message de commit).

**Drift detection :**
Si quelqu'un modifie un pod à la main en production (via kubectl), ArgoCD le détecte et remet l'état conforme à Git. Git gagne toujours.

---

## ArgoCD dans LiteDxP

### Les pods ArgoCD

| Pod | Rôle |
|-----|------|
| `argocd-server` | UI web + API REST |
| `argocd-repo-server` | Clone et lit les repos Git |
| `argocd-application-controller` | Compare Git ↔ cluster et synchronise |
| `argocd-dex-server` | Authentification SSO |
| `argocd-redis` | Cache pour les états |
| `argocd-notifications-controller` | Envoie des alertes (Slack, email...) |

### Accès à l'UI

```bash
# Port-forward (ports 8080/8443 réservés par k3d)
kubectl port-forward svc/argocd-server -n argocd 9090:443

# Mot de passe admin
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

URL : `https://localhost:9090` · Login : `admin`

---

## Commandes de référence

```bash
# Voir toutes les applications ArgoCD
kubectl get applications -n argocd

# Forcer une synchronisation
kubectl exec -n argocd deploy/argocd-server -- \
  argocd app sync <nom-app>

# Voir l'historique de déploiement
kubectl exec -n argocd deploy/argocd-server -- \
  argocd app history <nom-app>

# Rollback vers une version précédente
kubectl exec -n argocd deploy/argocd-server -- \
  argocd app rollback <nom-app> <revision>
```

---

## GitOps vs CI/CD traditionnel

| Critère | CI/CD Push (Jenkins, GitLab CI) | GitOps Pull (ArgoCD) |
|---------|--------------------------------|----------------------|
| Déclenchement | Pipeline pousse vers le cluster | Agent tire depuis Git |
| Accès cluster | Pipeline a les credentials K8s | Seul ArgoCD a accès |
| Drift detection | Non | Oui — correction automatique |
| Rollback | Manuel ou script | `git revert` + push |
| Audit trail | Logs CI | Historique Git |
| Sécurité | Credentials exposés dans CI | Credentials centralisés |

**Dans DxP :** on combine les deux — Tekton (CI) construit et pousse les images, ArgoCD (CD) déploie depuis Git. C'est la séparation Continuous Integration / Continuous Deployment.

---

## Résumé

> ArgoCD est le gardien de la cohérence entre ce qui est écrit dans Git et ce qui tourne dans Kubernetes. Dans DxP, aucun déploiement ne se fait à la main — tout passe par Git, tout est tracé, tout est réversible. C'est ce qui transforme une infrastructure fragile et opaque en une infrastructure fiable et auditable.

---

*DxP Academy · Chapitre 02 · Mai 2026*
