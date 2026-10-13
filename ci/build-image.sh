#!/bin/sh
set -eu
export DOCKER_CONFIG="$(mktemp -d)"
trap 'rm -rf "$DOCKER_CONFIG"' EXIT
python3 - <<'PY'
import base64, json, os
auth = base64.b64encode((os.environ['REG_USER'] + ':' + os.environ['REG_PASS']).encode()).decode()
with open(os.environ['DOCKER_CONFIG'] + '/config.json', 'w') as f:
    json.dump({'auths': {os.environ['IMAGE_REGISTRY_URL']: {'auth': auth}}}, f)
PY
case "$BUILDER" in
  docker)
    docker buildx build --platform linux/amd64 --tag "$IMAGE_REF" --push .
    ;;
  buildah)
    sudo buildah --storage-driver=vfs bud --isolation=chroot --platform linux/amd64 --authfile "$DOCKER_CONFIG/config.json" --tag "$IMAGE_REF" .
    sudo buildah --storage-driver=vfs push --authfile "$DOCKER_CONFIG/config.json" "$IMAGE_REF"
    sudo buildah --storage-driver=vfs rmi "$IMAGE_REF"
    ;;
  buildkit)
    export BUILDKITD_FLAGS="--oci-worker-snapshotter=native"
    buildctl-daemonless.sh build --frontend dockerfile.v0 --local context=. --local dockerfile=. --opt platform=linux/amd64 --output "type=image,name=$IMAGE_REF,push=true"
    ;;
  *) echo "Unknown builder: $BUILDER" >&2; exit 1 ;;
esac
