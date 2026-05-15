# Session 04 — Tekton
## 15 Mai 2026

### Objectif
Installer Tekton Pipelines comme moteur CI de LiteDxP.

### Environnement
- Tekton Pipelines v1.6.0 (latest au moment de l'install)
- Namespaces : `tekton-pipelines` + `tekton-pipelines-resolvers`
- Installation via manifest officiel (pas Helm)

### Ce qu'on a fait
1. Identification du repo officiel Tekton (pas Helm — manifests directs)
2. Récupération des 4 images via le manifest `latest`
3. Pull des images depuis ghcr.io + import dans k3d (une par une)
4. Premier `kubectl apply` — échec à cause des digests `@sha256:`
5. Solution : `sed 's/@sha256:[a-f0-9]*//'` pour supprimer les digests
6. Réinstallation propre — tous les pods Running en 10 secondes
7. Script `install.sh` versionné dans le repo GitOps

### Décisions prises
- Installation via manifest officiel (pas Helm) — Tekton ne publie pas de chart officiel
- Suppression des digests `@sha256:` — nécessaire pour utiliser les images locales k3d
- Import des images une par une — limite tarball k3d (~3 images max)
- Script `install.sh` dans le repo — reproductible à chaque nouvelle session

### Problèmes rencontrés
| Problème | Cause | Solution |
|----------|-------|----------|
| Repo Helm `tekton` incorrect | openshift/charts ≠ Tekton officiel | Installation via manifest GCS |
| `ErrImagePull` malgré images importées | Digest `@sha256:` force un pull réseau | `sed` pour supprimer les digests avant apply |
| Import silencieux vide sur 4 images | Tarball k3d trop lourd | Import une image à la fois |

### Commandes clés

```bash
# Installation (avec suppression digests)
curl -sL https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml \
  | sed 's/@sha256:[a-f0-9]*//' \
  | kubectl apply -f -

# Statut
kubectl get pods -n tekton-pipelines
kubectl get pods -n tekton-pipelines-resolvers

# Voir les CRDs Tekton installées
kubectl get crd | grep tekton

# Lister les tâches définies
kubectl get tasks -A

# Lister les pipelines définis
kubectl get pipelines -A
```

### État en fin de session
- ✅ Tekton Pipelines v1.6.0 Running (3 pods)
- ✅ Tekton Remote Resolvers Running (1 pod)
- ✅ CRDs installées : Task, Pipeline, PipelineRun, TaskRun...
- ✅ Script install.sh versionné dans GitOps
- ⏳ Aucun pipeline défini encore — prochaine étape

### Prochaine session
- Créer le premier pipeline Tekton : clone → test → build → push Harbor
- Installer Tekton Dashboard (UI)
- Connecter Tekton à Harbor via secret credentials
