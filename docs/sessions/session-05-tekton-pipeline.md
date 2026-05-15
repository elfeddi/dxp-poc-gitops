# Session 05 — Premier pipeline Tekton end-to-end
## 15 Mai 2026

### Objectif
Faire tourner le premier pipeline CI/CD complet : clone → build Kaniko → push Harbor.

### Résultat
✅ **Pipeline Succeeded** — `dxp-ci-run-003` · Clone + Build-Push Completed

### Ce qu'on a fait
1. Création du Dockerfile et index.html pour nginx-app
2. Création du secret Harbor pour Kubernetes
3. Création des Tasks Tekton (git-clone, kaniko-build-push) et du Pipeline dxp-ci
4. Résolution du problème Zscaler sur les images internes Tekton (entrypoint, busybox)
5. Résolution du problème containerd / registries.yaml pour Harbor HTTP
6. Push de Kaniko dans Harbor via port-forward
7. Import de Kaniko dans containerd via IP ClusterIP
8. Correction du Dockerfile path (nginx-app non pushé dans le repo)
9. Correction des credentials Harbor pour Kaniko
10. **Pipeline Succeeded** — image nginx-app:v1.0.0 dans Harbor

### Décisions prises
- PersistentVolumeClaim pour partager le workspace entre clone et build-push
- Image Kaniko stockée dans Harbor local (pas gcr.io) — contournement Zscaler
- IP ClusterIP Harbor dans registries.yaml — évite les problèmes DNS k3d
- Secret `harbor-push-secret` dédié pour Kaniko — séparé du secret K8s générique
- Args Kaniko hardcodés dans la Task (path absolu) — plus fiable que les paramètres

### Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|----------|-------|----------|
| `ErrImagePull` sur entrypoint Tekton | Image interne Tekton avec digest | Pull + import via `docker save/cp/ctr import` |
| `ErrImagePull` sur cgr.dev/chainguard/busybox | Zscaler bloque cgr.dev | Même méthode + registries.yaml |
| `PodCreationFailed` sur gcr.io/kaniko | Tekton vérifie l'image avant de créer le pod | Stocker Kaniko dans Harbor local |
| DNS `harbor.harbor.svc.cluster.local` introuvable depuis ctr | containerd n'a pas accès au DNS K8s | Utiliser l'IP ClusterIP directement |
| Harbor 502 via port-forward | Port-forward sur mauvais port | Port-forward `svc/harbor` → port 9091 |
| Harbor core CrashLoop après redémarrage | Persistence désactivée — DB réinitialisée | Réinstallation Harbor complète |
| IP ClusterIP Harbor change | Pas de persistence → réinstallation | Mettre à jour registries.yaml après chaque réinstallation |
| Dockerfile not found | `apps/nginx-app/` non pushé dans le repo | `git add apps/nginx-app && git push` |
| `UNAUTHORIZED` sur Harbor push | Secret docker-registry pointait sur mauvais serveur | Nouveau secret avec IP ClusterIP Harbor |
| Workspace non partagé entre pods | `emptyDir` par pod = volumes séparés | PersistentVolumeClaim partagé |

### Commandes clés

```bash
# Méthode fiable pour importer une image dans k3d (contournement bug tarball)
docker save IMAGE:TAG -o /tmp/image.tar
for node in k3d-dxp-poc-server-0 k3d-dxp-poc-agent-0 k3d-dxp-poc-agent-1; do
  docker cp /tmp/image.tar $node:/tmp/image.tar
  docker exec $node ctr images import /tmp/image.tar
done

# Importer depuis un registry HTTP interne
docker exec NODE ctr images pull --plain-http IP/projet/image:tag

# Lancer un pipeline
kubectl apply -f pipeline-run.yaml

# Suivre l'exécution
kubectl get pods -w
kubectl get pipelinerun NOM
kubectl logs POD --all-containers

# Vérifier une image dans Harbor
curl -u admin:Harbor12345 \
  http://localhost:9091/api/v2.0/projects/dxp/repositories/IMAGE/artifacts
```

### registries.yaml k3s final

```yaml
mirrors:
  cgr.dev:
    endpoint:
      - "https://cgr.dev"
  gcr.io:
    endpoint:
      - "https://gcr.io"
  10.43.183.106:
    endpoint:
      - "http://10.43.183.106"
  harbor.harbor.svc.cluster.local:
    endpoint:
      - "http://10.43.183.106"
configs:
  "cgr.dev":
    tls:
      insecure_skip_verify: true
  "gcr.io":
    tls:
      insecure_skip_verify: true
  "10.43.183.106":
    tls:
      insecure_skip_verify: true
  "harbor.harbor.svc.cluster.local":
    tls:
      insecure_skip_verify: true
```

> ⚠️ L'IP ClusterIP Harbor change à chaque réinstallation. Mettre à jour registries.yaml si Harbor est réinstallé.

### État en fin de session
- ✅ Pipeline dxp-ci Succeeded (clone + build-push)
- ✅ Image nginx-app:v1.0.0 dans Harbor
- ✅ Kaniko stocké dans Harbor/dxp/kaniko:latest
- ✅ PVC partagé entre les tasks du pipeline
- ✅ registries.yaml configuré pour Harbor HTTP + gcr.io + cgr.dev
- ⚠️ Harbor persistence désactivée — réinstallation nécessaire après redémarrage cluster

### Stack 1 — Statut
- ✅ Harbor v2.15.0
- ✅ Tekton Pipelines v1.6.0
- ✅ Pipeline CI clone → build → push
- ⏳ Backstage (Developer Portal) — prochaine session
- ⏳ Cosign (signature images)

### Prochaine session
- Backstage — Developer Portal
- Ou rendre Harbor persistent (PVC)
