#!/bin/sh
set -eu
askpass="$(mktemp)"
trap 'rm -f "$askpass"' EXIT
cat > "$askpass" <<'SH'
#!/bin/sh
case "$1" in *Username*) printf '%s\n' "$GIT_USER" ;; *) printf '%s\n' "$GIT_PASS" ;; esac
SH
chmod 700 "$askpass"
export GIT_ASKPASS="$askpass" GIT_TERMINAL_PROMPT=0
git config user.name 'sk304-jenkins'
git config user.email 'sk304@users.noreply.github.com'
git fetch origin gitops 2>/dev/null || true
if git show-ref --verify --quiet refs/remotes/origin/gitops; then
  git checkout -B gitops origin/gitops
else
  git checkout -b gitops
fi
(cd kustomize/overlays/dev && kustomize edit set image "$IMAGE_BASE=$IMAGE_REF")
python3 - <<'PY'
from pathlib import Path
import os,re
p=Path('k8s/deploy.yaml')
p.write_text(re.sub(r'(image: )\S+', lambda m:m.group(1)+os.environ['IMAGE_REF'], p.read_text()))
PY
git add kustomize/overlays/dev/kustomization.yaml k8s/deploy.yaml
if ! git diff --cached --quiet; then
  git commit -m "[CI] $IMAGE_REF"
  git push origin gitops
fi
