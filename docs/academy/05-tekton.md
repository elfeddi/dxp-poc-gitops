# Chapitre 05 — Tekton · Le moteur CI/CD

> **Série :** DxP Academy · Stack 1 — DevOps CI/CD  
> **Niveau :** Intermédiaire  
> **Durée de lecture :** ~12 minutes

---

## Le problème sans pipeline CI

Sans automatisation, le cycle de livraison ressemble à ça :

1. Développeur finit sa feature
2. Il lance les tests à la main (ou pas)
3. Il build l'image Docker à la main
4. Il la pousse vers un registry à la main
5. Il modifie un fichier de config pour déployer
6. Peut-être il oublie un step. Peut-être les tests échouent silencieusement.

**Le résultat :** des livraisons irrégulières, des images non testées en production, des incidents évitables.

Un pipeline CI automatise ce cycle — chaque commit déclenche automatiquement la même séquence, sans oubli.

---

## C'est quoi Tekton ?

**Tekton** est un framework open source pour construire des pipelines CI/CD natifs Kubernetes. Développé par Google, donné à la CNCF.

> Tekton c'est une chaîne de montage automatisée. Chaque voiture (commit) qui entre sur la chaîne passe par les mêmes étapes dans le même ordre — contrôle qualité, assemblage, peinture, livraison. Aucune voiture ne sort sans avoir passé toutes les étapes.

### Pourquoi Tekton et pas Jenkins, GitLab CI, GitHub Actions ?

| Critère | Jenkins | GitLab CI / GitHub Actions | Tekton |
|---------|---------|---------------------------|--------|
| Natif Kubernetes | ❌ | Partiel | ✅ natif |
| Auto-hébergé | ✅ | ✅ | ✅ |
| Scalabilité | Limitée | Bonne | Excellente |
| Réutilisabilité des tâches | Plugins | Limitée | ✅ Tasks partagées |
| Souveraineté | ✅ | ✅ | ✅ |
| CNCF | ❌ | ❌ | ✅ Incubating |

**Tekton est natif Kubernetes** — chaque étape du pipeline tourne dans un pod K8s. Pas de serveur CI à maintenir, pas de plugins à gérer. Le pipeline utilise la même infrastructure que les applications.

---

## Les 4 concepts fondamentaux de Tekton

### 1. Task — une tâche atomique

Une `Task` est la plus petite unité de Tekton. Elle définit une séquence d'étapes (`Steps`) qui s'exécutent dans le même pod.

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: git-clone
spec:
  params:
    - name: url
      type: string
  steps:
    - name: clone
      image: alpine/git
      script: |
        git clone $(params.url) /workspace/source
```

Chaque `Step` tourne dans un conteneur différent **dans le même pod** — ils partagent le même espace de stockage.

### 2. Pipeline — orchestration de tâches

Un `Pipeline` enchaîne plusieurs `Tasks` dans un ordre défini :

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: dxp-ci
spec:
  tasks:
    - name: clone
      taskRef:
        name: git-clone
    - name: test
      taskRef:
        name: run-tests
      runAfter:
        - clone          # ← dépendance explicite
    - name: build
      taskRef:
        name: build-image
      runAfter:
        - test
```

`runAfter` définit les dépendances — Tekton exécute les tâches dans le bon ordre, en parallèle quand c'est possible.

### 3. PipelineRun — une exécution

Un `PipelineRun` est une instance d'exécution d'un `Pipeline`. C'est lui qui démarre le pipeline avec des paramètres concrets :

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: dxp-ci-run-001
spec:
  pipelineRef:
    name: dxp-ci
  params:
    - name: git-url
      value: https://github.com/elfeddi/dxp-poc-gitops
    - name: image-tag
      value: v1.2.3
```

Chaque PipelineRun crée ses propres pods — traçabilité complète, logs archivés.

### 4. Workspace — espace de stockage partagé

Les tâches d'un pipeline ont besoin de partager des fichiers (le code cloné, l'image buildée...). Les `Workspaces` sont des volumes partagés entre les tâches :

```yaml
workspaces:
  - name: source-code    # partagé entre clone, test, build
  - name: docker-config  # credentials Harbor
```

---

## Le pipeline CI DxP en détail

Voici les 7 étapes du pipeline DxP et ce qui se passe dans chacune :

### Étape 1 — Clone
```
Tâche : git-clone
Image : alpine/git
Input : URL du repo + commit SHA
Output : code source dans /workspace/source
```
Clone le code source du commit exact qui a déclenché le pipeline. Pas de "dernière version" — le commit exact, reproductible.

### Étape 2 — Test
```
Tâche : run-tests
Image : l'image de base de l'application (ex: python:3.12)
Input : /workspace/source
Output : rapport de tests + couverture
```
Exécute les tests unitaires. Si un test échoue → pipeline bloqué, aucune image ne sera produite.

### Étape 3 — Build image
```
Tâche : kaniko-build (ou buildah)
Image : gcr.io/kaniko-project/executor
Input : /workspace/source + Dockerfile
Output : image OCI dans /workspace/image
```
Build l'image Docker **sans Docker** — Kaniko build en mode rootless, sécurisé dans Kubernetes.

### Étape 4 — Scan CVE
```
Tâche : trivy-scan
Image : aquasec/trivy
Input : image buildée
Output : rapport de vulnérabilités
Gate : bloque si CVE critique détectée
```
Scanne l'image avant qu'elle ne soit pushée. Une CVE de sévérité CRITICAL → pipeline arrêté, image rejetée.

### Étape 5 — Push Harbor
```
Tâche : push-image
Image : gcr.io/kaniko-project/executor
Input : image + credentials Harbor (depuis Vault)
Output : image dans harbor/dxp/mon-app:v1.2.3
```
Pousse l'image vers Harbor avec le bon tag. Les credentials viennent de Vault — jamais en clair.

### Étape 6 — Sign Cosign
```
Tâche : cosign-sign
Image : gcr.io/projectsigstore/cosign
Input : image pushée + clé privée (depuis Vault)
Output : signature attachée à l'image dans Harbor
```
Signe cryptographiquement l'image. Kubernetes peut ensuite vérifier que l'image vient bien de notre pipeline — pas d'une source externe.

### Étape 7 — Update GitOps
```
Tâche : update-manifest
Image : alpine/git
Input : nouveau tag de l'image
Output : commit dans dxp-poc-gitops avec le nouveau tag
```
Met à jour le fichier `deployment.yaml` dans le repo GitOps avec le nouveau tag d'image. ArgoCD détecte le changement et déploie automatiquement.

---

## Dans DxP, Tekton joue quel rôle ?

Tekton est la **chaîne CI** de DxP. Il transforme un `git push` en une image prête pour la production.

```
git push
    │
    ▼ (webhook GitHub → Tekton Triggers)
PipelineRun créé
    │
    ▼
Clone → Test → Build → Scan → Push → Sign → Update GitOps
                                                    │
                                                    ▼
                                              ArgoCD déploie
```

### La séparation CI / CD dans DxP

| Responsabilité | Outil | Ce qu'il fait |
|----------------|-------|---------------|
| CI (Continuous Integration) | Tekton | Build, test, scan, push image |
| CD (Continuous Deployment) | ArgoCD | Déploie depuis Git vers K8s |

C'est la séparation classique et recommandée — Tekton ne déploie jamais directement dans Kubernetes. Il met à jour Git, ArgoCD fait le reste.

---

## Les CRDs Tekton installées

Quand on installe Tekton, il crée ces Custom Resource Definitions dans Kubernetes :

| CRD | Usage |
|-----|-------|
| `Task` | Définition d'une tâche réutilisable |
| `TaskRun` | Instance d'exécution d'une Task |
| `Pipeline` | Orchestration de Tasks |
| `PipelineRun` | Instance d'exécution d'un Pipeline |
| `StepAction` | Action réutilisable dans une Step |
| `CustomRun` | Extension personnalisée |

```bash
# Voir toutes les CRDs Tekton
kubectl get crd | grep tekton.dev
```

---

## Tekton Hub — bibliothèque de tâches

Tekton Hub (`hub.tekton.dev`) est une bibliothèque de tâches prêtes à l'emploi — git-clone, kaniko, trivy, cosign, helm-upgrade... Plutôt que d'écrire ses propres tâches, on les importe depuis le Hub :

```bash
# Installer la tâche git-clone depuis Tekton Hub
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/git-clone/0.9/raw
```

---

## Commandes de référence

```bash
# Statut des pods Tekton
kubectl get pods -n tekton-pipelines
kubectl get pods -n tekton-pipelines-resolvers

# Voir les tâches définies
kubectl get tasks -A

# Voir les pipelines définis
kubectl get pipelines -A

# Voir les exécutions de pipeline
kubectl get pipelineruns -A

# Logs d'une exécution
kubectl logs -n <namespace> -l tekton.dev/pipelineRun=<nom-run>

# Lancer manuellement un pipeline
kubectl create -f my-pipeline-run.yaml

# Voir le détail d'une exécution
kubectl describe pipelinerun <nom-run>
```

---

## Installation dans LiteDxP

Tekton s'installe via son manifest officiel (pas via Helm) :

```bash
# Installation avec suppression des digests (nécessaire avec Zscaler + k3d)
curl -sL https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml \
  | sed 's/@sha256:[a-f0-9]*//' \
  | kubectl apply -f -
```

Le `sed` supprime les digests `@sha256:` du manifest — sans ça, Kubernetes tente de vérifier le digest en ligne même si l'image est présente localement, ce qui échoue derrière Zscaler.

---

## Résumé

> Tekton transforme chaque `git push` en une séquence automatisée et reproductible : clone, test, build, scan sécurité, push Harbor, signature Cosign, mise à jour GitOps. Aucune image non testée et non signée ne peut atteindre la production. C'est la chaîne de confiance CI de DxP.

---

*DxP Academy · Chapitre 05 · Mai 2026*
