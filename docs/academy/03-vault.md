# Chapitre 03 — Vault · Gestion des secrets

> **Série :** DxP Academy · Stack 3 — Security  
> **Niveau :** Débutant → Intermédiaire  
> **Durée de lecture :** ~10 minutes

---

## C'est quoi un secret ?

Dans une application, un **secret** c'est toute information sensible qui ne doit pas être lisible par n'importe qui :

- Un mot de passe de base de données
- Un token d'accès GitHub
- Une clé API (OpenAI, AWS, Stripe...)
- Un certificat TLS
- Une clé de chiffrement

Le problème universel : **où stocker ces secrets ?**

---

## Le problème sans Vault

Sans gestionnaire de secrets, les équipes font souvent ça :

```yaml
# deployment.yaml — MAUVAISE PRATIQUE ❌
env:
  - name: DB_PASSWORD
    value: "monsupermotdepasse123"
```

Ou pire, dans un fichier `.env` commité sur Git :
```
DB_PASSWORD=monsupermotdepasse123
API_KEY=sk-abc123xyz
```

**Les conséquences :**
- Le secret est visible dans Git — pour toujours, même après suppression
- Tout le monde dans l'équipe voit tous les secrets
- Impossible de savoir qui a accès à quoi
- Rotation des secrets = modifier des dizaines de fichiers à la main
- Un stagiaire part → il faut tout changer manuellement

---

## C'est quoi Vault ?

**HashiCorp Vault** est un coffre-fort numérique centralisé pour tous les secrets de votre infrastructure.

> Vault est à vos secrets ce qu'un coffre-fort de banque est à votre argent — centralisé, sécurisé, audité, avec des clés différentes pour chaque personne.

### Les 4 fonctions fondamentales de Vault

| Fonction | Description |
|----------|-------------|
| **Stockage sécurisé** | Les secrets sont chiffrés au repos (AES-256-GCM) |
| **Contrôle d'accès** | Policies granulaires — qui peut lire quoi |
| **Audit trail** | Chaque accès est loggué — qui a lu quel secret, quand |
| **Rotation dynamique** | Vault génère des credentials temporaires à la demande |

---

## Comment Vault fonctionne

### Le concept de "Seal/Unseal"

Vault démarre dans un état **Sealed** (verrouillé). Personne ne peut lire les secrets. Pour l'utiliser, il faut le **Unseal** (déverrouiller) avec une ou plusieurs clés maîtres.

```
Démarrage Vault
      │
      ▼
  [SEALED] ← chiffré, inaccessible
      │
  Unseal avec clé(s)
      │
      ▼
  [UNSEALED] ← opérationnel, secrets accessibles
```

En mode **dev** (notre POC) : Vault démarre automatiquement unsealed avec le token `root`. Simple, mais les données sont perdues au redémarrage.

En **production** : Vault démarre sealed. Il faut des clés (ou un HSM) pour l'unsealer — sécurité maximale.

### Les chemins de secrets (Secret Paths)

Vault organise les secrets comme un système de fichiers :

```
secret/
├── dxp/
│   ├── test          ← secret/dxp/test
│   ├── github-token  ← secret/dxp/github-token
│   └── harbor-creds  ← secret/dxp/harbor-creds
├── tekton/
│   └── registry      ← secret/tekton/registry
└── backstage/
    └── database      ← secret/backstage/database
```

### Le KV Store (Key-Value)

Le moteur le plus simple de Vault. On stocke des paires clé/valeur :

```bash
# Écrire
vault kv put secret/dxp/github token="ghp_xxx" username="elfeddi"

# Lire
vault kv get secret/dxp/github

# Résultat :
# Key      Value
# ---      -----
# token    ghp_xxx
# username elfeddi
```

Chaque écriture crée une nouvelle **version** — Vault conserve l'historique complet.

---

## Dans DxP, Vault joue quel rôle ?

Vault est la **fondation de sécurité** de toute la plateforme. Tous les autres composants viennent y chercher leurs secrets plutôt que de les stocker eux-mêmes.

```
┌─────────────────────────────────────────┐
│              HashiCorp Vault             │
│         (source de vérité secrets)       │
└──────┬──────┬──────┬──────┬─────────────┘
       │      │      │      │
    Tekton  Harbor Backstage LGTM
    (CI/CD) (registry) (portal) (observ.)
```

### Les secrets DxP stockés dans Vault

| Chemin | Contenu | Utilisé par |
|--------|---------|-------------|
| `secret/dxp/github` | Token GitHub | ArgoCD, Backstage |
| `secret/dxp/harbor` | Credentials registry | Tekton, K8s |
| `secret/dxp/backstage-db` | Password PostgreSQL | Backstage |
| `secret/dxp/lgtm` | Credentials Grafana | LGTM stack |
| `secret/dxp/llm-gateway` | Clés API LLM | LiteLLM |

### Le Vault Agent Injector

C'est le composant `vault-agent-injector` installé avec Vault. Il surveille les pods Kubernetes et **injecte automatiquement** les secrets Vault comme variables d'environnement ou fichiers montés.

```yaml
# Un pod annote sa demande de secret
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "dxp-app"
  vault.hashicorp.com/agent-inject-secret-config: "secret/dxp/github"
```

Le pod reçoit automatiquement le secret — sans jamais le voir en clair dans un YAML.

---

## Les deux modes de Vault dans DxP

### Mode dev (POC LiteDxP)
```
✅ Démarrage instantané
✅ Token root fixe — pas de gestion de clés
✅ Unseal automatique
❌ Données perdues au redémarrage
❌ Pas de persistance
❌ Ne jamais utiliser en production
```

### Mode production (VMs Nutanix)
```
✅ Stockage persistant (Raft ou etcd)
✅ HA — 3 ou 5 nœuds
✅ Unseal automatique via HSM ou AWS KMS
✅ Audit logs complets
✅ Rotation automatique des secrets
```

---

## Commandes de référence

```bash
# Statut de Vault
kubectl exec -n vault vault-0 -- vault status

# Login avec token root (mode dev)
kubectl exec -n vault vault-0 -- vault login root

# Écrire un secret
kubectl exec -n vault vault-0 -- vault kv put secret/chemin \
  cle1="valeur1" cle2="valeur2"

# Lire un secret
kubectl exec -n vault vault-0 -- vault kv get secret/chemin

# Lister les secrets d'un chemin
kubectl exec -n vault vault-0 -- vault kv list secret/dxp/

# Voir les versions d'un secret
kubectl exec -n vault vault-0 -- vault kv metadata get secret/chemin

# Supprimer un secret
kubectl exec -n vault vault-0 -- vault kv delete secret/chemin
```

---

## Pourquoi Vault et pas les Secrets Kubernetes natifs ?

Kubernetes a ses propres `Secrets` — mais ils ont des limitations importantes :

| Critère | K8s Secrets | Vault |
|---------|-------------|-------|
| Chiffrement au repos | Optionnel (base64 par défaut) | Toujours (AES-256) |
| Audit trail | Non | Oui — chaque accès loggué |
| Rotation automatique | Non | Oui |
| Multi-cluster | Non | Oui |
| Dynamic secrets | Non | Oui (DB, AWS, PKI...) |
| Policies granulaires | Basiques (RBAC) | Avancées |

**Dans DxP :** on utilise les deux — Vault comme source de vérité, et le Vault Agent Injector synchronise automatiquement vers les K8s Secrets quand les pods en ont besoin.

---

## Résumé

> Vault centralise tous les secrets de DxP dans un coffre-fort chiffré, audité et versionnée. Aucun secret n'est jamais écrit en clair dans un fichier YAML ou dans Git. Chaque composant de la plateforme vient chercher ses credentials dans Vault au démarrage — et Vault sait exactement qui a demandé quoi, et quand.

---

*DxP Academy · Chapitre 03 · Mai 2026*
