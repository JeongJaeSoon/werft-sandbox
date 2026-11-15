#!/bin/bash
# Which AppArmor rules Codex's bubblewrap sandbox needs, with and without the
# userns restriction. Round 2 of probe.sh.
set -u
cd "$(dirname "$0")"
docker build -q -t codex-probe - <<'EOF' >/dev/null
FROM node:22-bookworm-slim
RUN npm install -g @openai/codex@0.167.0 >/dev/null 2>&1 && codex --version
USER node
EOF

INNER='mkdir -p /tmp/work /tmp/ch && cd /tmp/work &&
codex sandbox -c default_permissions="werft" -c "permissions.werft={extends=\":workspace\",network={enabled=true}}" -- sh -c "echo inside-ok; echo x > /tmp/work/f && echo wrote-cwd; echo y > /home/node/h 2>/dev/null && echo wrote-home || echo home-denied"
echo "exit=$?"'
HARD=(--cap-drop ALL --security-opt no-new-privileges --read-only
  --tmpfs /tmp:rw,nosuid,nodev,uid=1000,gid=1000
  --tmpfs /home/node:rw,nosuid,nodev,uid=1000,gid=1000
  --security-opt seccomp=werft-codex-seccomp.json -e CODEX_HOME=/tmp/ch)
run() {
  echo
  echo "=== $1 (restrict_unprivileged_userns=$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns))"
  shift
  docker run --rm "${HARD[@]}" "$@" codex-probe bash -c "$INNER" 2>&1 | grep -v -e ' WARN ' -e 'PATH aliases' | head -8
}
# variant <name> <rules to add, one per line> ; built from werft-codex.apparmor minus userns/deny mount
variant() {
  local name=$1 rules=$2
  sed -e '/^  userns,$/d' -e '/^  deny mount,$/d' -e "s/werft-codex/$name/g" werft-codex.apparmor |
    awk -v r="$rules" '{print} /^  umount,$/ {n=split(r, a, ";"); for (i=1;i<=n;i++) print "  " a[i] ","}' > "$name.apparmor"
  sudo apparmor_parser -r -W "$name.apparmor" && echo "loaded $name: $rules"
}
variant aa-userns-mount "userns;mount"
variant aa-userns-mount-pivot "userns;mount;pivot_root"
variant aa-mount-pivot "mount;pivot_root"
grep -n -e userns -e mount -e pivot aa-userns-mount-pivot.apparmor

run "A userns+mount" --security-opt apparmor=aa-userns-mount
run "B userns+mount+pivot_root" --security-opt apparmor=aa-userns-mount-pivot
run "C mount+pivot_root, no userns" --security-opt apparmor=aa-mount-pivot

sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
run "D mount+pivot_root, no userns" --security-opt apparmor=aa-mount-pivot
run "E apparmor=unconfined" --security-opt apparmor=unconfined
run "F docker-default"

echo
echo "=== containerd's default AppArmor template"
curl -fsSL https://raw.githubusercontent.com/containerd/containerd/v2.1.4/contrib/apparmor/template.go | grep -n -e 'mount' -e 'userns' -e 'pivot'
