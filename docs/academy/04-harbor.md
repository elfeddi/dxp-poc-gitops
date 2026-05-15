# Chapitre 04 — Harbor · Le registry d'images

> **Série :** DxP Academy · Stack 1 — DevOps CI/CD  
> **Niveau :** Débutant → Intermédiaire  
> **Durée de lecture :** ~10 minutes

---

## C'est quoi un registry d'images ?

Quand on construit une application avec Docker, le résultat est une **image** — une boîte autonome contenant l'application et tout ce dont elle a besoin.

Cette image doit être stockée quelque part pour que Kubernetes puisse la récupérer et la faire tourner. Ce "quelque part" s'appelle un **registry d'images**.

> Un registry d'images c'est comme une bibliothèque de livres — mais au lieu de livres, il stocke des images Docker. Chaque image a un nom et une version (tag). Kubernetes va "emprunter" l'image pour faire tourner l'application.

---

## Les registries du marché

| Registry | Type | Usage |
|----------|------|-------|
| Docker Hub | Public | Images publiques open source |
| GitHub Container Registry (ghcr.io) | Public/Privé | Images liées à un repo GitHub |
| Amazon ECR | Cloud | Images pour AWS |
| Google Artifact Registry | Cloud | Images pour GCP |
| **Harbor** | **Auto-hébergé** | **Registry privé on-premise** |

**Pourquoi pas Docker Hub ?**
- Limite de pull pour les comptes gratuits
- Images stockées chez un tiers — pas de souveraineté
- Pas de scan de sécurité intégré
- Pas de contrôle d'accès fin

---

## C'est quoi Harbor ?

**Harbor** est un registry d'images open source, auto-hébergé, développé par VMware et donné à la CNCF.

> Harbor c'est ton propre Docker Hub — mais dans ton infrastructure, avec tes règles, tes accès, et un scanner de sécurité intégré.

### Les fonctions clés de Harbor

| Fonction | Description |
|----------|-------------|
| **Registry privé** | Stocke tes images Docker en local |
| **Contrôle d'accès** | Projets, utilisateurs, robot accounts |
| **Scan CVE** | Trivy analyse chaque image à la recherche de vulnérabilités |
| **Signature d'images** | Cosign — garantit l'authenticité des images |
| **Réplication** | Synchronise avec d'autres registries (Docker Hub, ECR...) |
| **Webhooks** | Notifie un système externe quand une image est pushée |
| **Quotas** | Limite l'espace disque par projet |

---

## Les concepts Harbor

### Les projets

Harbor organise les images en **projets** — comme des dossiers :

```
Harbor
├── library/          ← projet public par défaut
│   └── nginx:alpine
└── dxp/             ← notre projet LiteDxP
    ├── mon-app:v1.0
    ├── mon-app:v1.1
    └── mon-api:v2.0
```

Un projet peut être **public** (tout le monde peut puller) ou **privé** (authentification requise).

### Les tags

Chaque image a un **tag** — une version :

```
localhost:30002/dxp/mon-app:v1.0
│               │    │        │
│               │    │        └── tag (version)
│               │    └── nom de l'image
│               └── projet Harbor
└── adresse du registry
```

### Les Robot Accounts

Pour que Tekton ou Kubernetes pulle des images automatiquement, on crée un **Robot Account** — un compte de service avec des permissions limitées (lecture seule, ou lecture + écriture sur un projet spécifique).

---

## Trivy — le scanner de sécurité

Harbor intègre **Trivy**, un scanner open source qui analyse chaque image pushée et détecte les **CVE** (Common Vulnerabilities and Exposures) — les failles de sécurité connues.

```
Image pushée vers Harbor
        ↓
Trivy scanne l'image
        ↓
Résultat : 0 critique · 3 moyennes · 12 faibles
        ↓
Harbor affiche le rapport
        ↓
(optionnel) Bloquer le déploiement si CVE critique détectée
```

C'est ce qu'on appelle un **quality gate de sécurité** — une image avec des failles critiques ne peut pas aller en production.

---

## Dans DxP, Harbor joue quel rôle ?

Harbor est le **maillon central de la chaîne CI/CD** de DxP.

```
Développeur
    │ git push
    ▼
GitHub
    │ déclenche
    ▼
Tekton (CI)
    │ build image
    │ scan Trivy
    │ push image
    ▼
Harbor ← stocke l'image scannée et signée
    │
    ▼
ArgoCD (CD)
    │ pull image depuis Harbor
    ▼
Kubernetes
    │ fait tourner le pod
    ▼
Application en production
```

### Ce que Harbor garantit dans DxP

- **Traçabilité** : chaque image est horodatée, taguée, et associée à un commit Git
- **Sécurité** : aucune image avec CVE critique ne passe en production
- **Souveraineté** : les images restent dans l'infrastructure DxP, jamais chez un tiers
- **Performance** : Kubernetes pulle depuis Harbor local — pas depuis internet

---

## Pousser une image vers Harbor

```bash
# 1. Builder l'image
docker build -t mon-app:v1.0 .

# 2. Tagger pour Harbor
docker tag mon-app:v1.0 localhost:30002/dxp/mon-app:v1.0

# 3. S'authentifier (si projet privé)
docker login localhost:30002 -u admin -p Harbor12345

# 4. Pousher
docker push localhost:30002/dxp/mon-app:v1.0

# 5. Kubernetes peut maintenant puller l'image
# Dans le deployment.yaml :
# image: localhost:30002/dxp/mon-app:v1.0
```

---

## Harbor dans LiteDxP

### Les pods Harbor

| Pod | Rôle |
|-----|------|
| `harbor-core` | API principale + logique métier |
| `harbor-portal` | Interface web |
| `harbor-nginx` | Reverse proxy — point d'entrée |
| `harbor-registry` | Stockage des layers d'images (2 conteneurs) |
| `harbor-database` | PostgreSQL — métadonnées |
| `harbor-redis` | Cache |
| `harbor-jobservice` | Jobs asynchrones (réplication, scan...) |
| `harbor-trivy` | Scanner CVE |

### Configuration LiteDxP

```yaml
# infrastructure/harbor/values.yaml
expose:
  type: nodePort
  tls:
    enabled: false     # HTTP simple pour le POC
  nodePort:
    ports:
      http:
        nodePort: 30002

externalURL: http://localhost:30002
persistence:
  enabled: false       # Pas de persistance pour le POC
```

### Accès

```
UI Web  : http://localhost:9091  (via port-forward)
Registry: localhost:30002        (via nodePort)
Login   : admin / Harbor12345
```

---

## Harbor vs alternatives

| Critère | Harbor | Docker Hub | ECR/GCR |
|---------|--------|------------|---------|
| Auto-hébergé | ✅ | ❌ | ❌ |
| Scan CVE intégré | ✅ Trivy | ✅ (payant) | ✅ |
| Signature images | ✅ Cosign | ✅ | ✅ |
| Souveraineté | ✅ Total | ❌ | ❌ |
| Air-gapped | ✅ | ❌ | ❌ |
| Coût | Gratuit | Limité gratuit | Pay-per-use |
| CNCF | ✅ Graduated | ❌ | ❌ |

---

## Commandes de référence

```bash
# Accès UI
kubectl port-forward -n harbor svc/harbor 9091:80

# Statut des pods
kubectl get pods -n harbor

# Voir les logs Harbor core
kubectl logs -n harbor deploy/harbor-core

# Lister les images dans un projet via l'API
curl http://localhost:9091/api/v2.0/projects/dxp/repositories \
  -u admin:Harbor12345 | jq .
```

---

## Résumé

> Harbor est le coffre-fort des images Docker de DxP. Toute image construite par Tekton y est stockée, scannée par Trivy, et signée avant d'être déployée par ArgoCD. Aucune image non vérifiée ne passe en production — Harbor est le gardien de la chaîne de confiance.

---

*DxP Academy · Chapitre 04 · Mai 2026*
