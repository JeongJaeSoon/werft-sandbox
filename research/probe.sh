#!/bin/bash
# Codex 0.167.0's bubblewrap sandbox in a hardened container on this host,
# under several seccomp/AppArmor combinations.
set -u
cd "$(dirname "$0")"
echo "kernel: $(uname -r)"
grep PRETTY_NAME /etc/os-release
echo "docker: $(docker version --format '{{.Server.Version}}')"
echo "apparmor_restrict_unprivileged_userns=$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns)"
echo "unprivileged_userns_clone=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo n/a)"

docker build -q -t codex-probe - <<'EOF' >/dev/null
FROM node:22-bookworm-slim
RUN npm install -g @openai/codex@0.167.0 >/dev/null 2>&1 && codex --version
USER node
EOF
docker run --rm codex-probe codex --version

INNER='mkdir -p /tmp/work && cd /tmp/work &&
codex sandbox -c default_permissions="werft" -c "permissions.werft={extends=\":workspace\",network={enabled=true}}" -- sh -c "echo inside-ok; echo x > /tmp/work/f && echo wrote-cwd"
echo "exit=$?"'
HARD=(--cap-drop ALL --security-opt no-new-privileges --read-only
  --tmpfs /tmp:rw,nosuid,nodev,uid=1000,gid=1000
  --tmpfs /home/node:rw,nosuid,nodev,uid=1000,gid=1000)
run() {
  echo
  echo "=== $1"
  shift
  docker run --rm "${HARD[@]}" "$@" -e CODEX_HOME=/tmp/ch codex-probe bash -c "mkdir -p /tmp/ch; $INNER" 2>&1 | grep -v ' WARN ' | head -12
}
mark() { sudo dmesg | wc -l; }
log_since() { sudo dmesg | tail -n +"$(($1 + 1))" | grep -iE 'apparmor|audit' | head -6; }

n=$(mark); run "1 default seccomp + docker-default AppArmor"; log_since "$n"
n=$(mark); run "2 werft seccomp + docker-default AppArmor" --security-opt seccomp=werft-codex-seccomp.json; log_since "$n"
n=$(mark); run "3 werft seccomp + apparmor=unconfined" --security-opt seccomp=werft-codex-seccomp.json --security-opt apparmor=unconfined; log_since "$n"

sudo apparmor_parser -r -W werft-codex.apparmor && echo "loaded werft-codex"
n=$(mark); run "4 werft seccomp + werft-codex AppArmor (docker-default + userns, deny mount)" --security-opt seccomp=werft-codex-seccomp.json --security-opt apparmor=werft-codex; log_since "$n"

sed -e 's/^  deny mount,/  mount,\n  pivot_root,/' -e 's/profile werft-codex /profile werft-codex-mount /' -e 's/peer=werft-codex,/peer=werft-codex-mount,/g' werft-codex.apparmor > werft-codex-mount.apparmor
sudo apparmor_parser -r -W werft-codex-mount.apparmor && echo "loaded werft-codex-mount"
n=$(mark); run "5 werft seccomp + werft-codex-mount AppArmor (userns + mount + pivot_root)" --security-opt seccomp=werft-codex-seccomp.json --security-opt apparmor=werft-codex-mount; log_since "$n"

sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
n=$(mark); run "6 sysctl 0: werft seccomp + docker-default AppArmor" --security-opt seccomp=werft-codex-seccomp.json; log_since "$n"
n=$(mark); run "7 sysctl 0: default seccomp + docker-default AppArmor"; log_since "$n"
