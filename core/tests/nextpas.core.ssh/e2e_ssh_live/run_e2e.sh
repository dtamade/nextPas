#!/usr/bin/env bash
# e2e_ssh_live 编排器 —— 对真实 OpenSSH 服务器的互操作测试（opt-in）。
#
# 模式：
#   NEXTPAS_SSH_E2E_LOCAL=1   本地 Docker 夹具（alpine + openssh-server，
#                             一次性密钥、随机高端口，全封闭可重复）
#   NEXTPAS_SSH_E2E_REMOTE=1  真实服务器；需提供：
#                               NEXTPAS_SSH_E2E_HOST / _USER / _KEYFILE
#                               （_PORT 可选，默认 22）
#   两者都不设置              SKIP（exit 0），不进默认 gate 的 opt-in 语义。
#
# 已知_hosts：未显式提供 NEXTPAS_SSH_E2E_KNOWN_HOSTS 时用 ssh-keyscan 做 TOFU。
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$(cd "$DIR/../../.." && pwd)/build/projects/nextpas.core.ssh/e2e_ssh_live/test_ssh_e2e"
IMAGE="np/ssh-e2e:latest"

fail() { echo "[e2e] FAILED: $*" >&2; exit 1; }
need_env_remote() {
  for v in NEXTPAS_SSH_E2E_HOST NEXTPAS_SSH_E2E_USER NEXTPAS_SSH_E2E_KEYFILE; do
    [ -n "${!v:-}" ] || fail "remote 模式需要 $v"
  done
}

# ---- 运行被测二进制（heaptrc 泄漏门禁与 common.mk 同语义） ----
run_binary() {
  local dump="$TMP/heaptrc.log" rc=0
  rm -f "$dump"
  HEAPTRC="haltonnotreleased,log=$dump" "$BIN"; rc=$?
  if [ -f "$dump" ]; then
    grep -q '^Heap dump by heaptrc unit' "$dump" || fail "no heaptrc dump written"
    grep -q '^0 unfreed memory blocks : 0$' "$dump" || { cat "$dump"; fail "unfreed blocks"; }
    echo "[e2e] heaptrc OK (0 unfreed)"
  fi
  return $rc
}

# ---- remote 模式：直连真实服务器 ----
run_remote() {
  need_env_remote
  TMP="$(mktemp -d /tmp/np-ssh-e2e.XXXXXX)"
  trap 'rm -rf "$TMP"' EXIT

  if [ -z "${NEXTPAS_SSH_E2E_KNOWN_HOSTS:-}" ]; then
    echo "[e2e] known_hosts 未提供，ssh-keyscan TOFU…"
    ssh-keyscan -T 5 -t ed25519,rsa -p "${NEXTPAS_SSH_E2E_PORT:-22}" \
      "$NEXTPAS_SSH_E2E_HOST" > "$TMP/known_hosts" 2>/dev/null
    grep -qv '^#' "$TMP/known_hosts" || fail "ssh-keyscan 无结果"
    export NEXTPAS_SSH_E2E_KNOWN_HOSTS="$TMP/known_hosts"
  fi
  echo "[e2e] target=$NEXTPAS_SSH_E2E_USER@${NEXTPAS_SSH_E2E_HOST}:${NEXTPAS_SSH_E2E_PORT:-22}"
  run_binary || exit $?
}

# ---- docker 模式：一次性 OpenSSH 容器夹具 ----
run_docker() {
  command -v docker >/dev/null 2>&1 || fail "docker 不可用（NEXTPAS_SSH_E2E_LOCAL=1 已显式要求）"
  docker ps >/dev/null 2>&1 || fail "docker daemon 不可访问"
  [ "$(id -u)" = 0 ] || true   # 容器内 root，无需宿主 root

  # 镜像按需构建一次并复用
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "[e2e] building fixture image $IMAGE …"
    docker build -q -t "$IMAGE" -f "$DIR/Dockerfile.e2e" "$DIR" >/dev/null \
      || fail "fixture image build failed"
  fi

  TMP="$(mktemp -d /tmp/np-ssh-e2e.XXXXXX)"
  CNAME="np-ssh-e2e-$$"
  cleanup() { docker rm -f "$CNAME" >/dev/null 2>&1; rm -rf "$TMP"; }
  trap cleanup EXIT INT TERM

  # 一次性密钥三件套：sshd host key / 客户端密钥 / authorized_keys
  ssh-keygen -q -t ed25519 -N '' -f "$TMP/host_ed25519"      || fail "host keygen"
  ssh-keygen -q -t ed25519 -N '' -f "$TMP/client_key"        || fail "client keygen"
  cp "$TMP/client_key.pub" "$TMP/authorized_keys"
  cp "$DIR/sshd_e2e_config" "$TMP/sshd_config"
  mkdir -p "$TMP/stage"
  mv "$TMP/sshd_config" "$TMP/host_ed25519" "$TMP/authorized_keys" "$TMP/stage/"

  # sleep 起容器 → 注入文件（规避 bind-mount uid 不匹配）→ 容器内拉起 sshd
  docker run -d --name "$CNAME" --entrypoint sleep \
    -p 127.0.0.1::22 "$IMAGE" 600 >/dev/null                 || fail "docker run"
  docker cp "$TMP/stage" "$CNAME":/np-in                      || fail "docker cp"
  docker exec "$CNAME" sh -c '
    mkdir -p /config &&
    mv /np-in/sshd_config /config/sshd_config &&
    mv /np-in/host_ed25519 /config/host_ed25519 &&
    mv /np-in/authorized_keys /config/authorized_keys &&
    chown -R root:root /config && chmod 700 /config &&
    chmod 600 /config/host_ed25519 && chmod 644 /config/authorized_keys &&
    rm -rf /np-in'                                           || fail "container prep"
  docker exec -d "$CNAME" /usr/sbin/sshd -f /config/sshd_config \
    -E /config/sshd.log                                     || fail "start sshd"
  PORT="$(docker port "$CNAME" 22 | head -1 | sed 's/^.*://')"
  [ -n "$PORT" ]                                             || fail "no mapped port"

  # 就绪等待 + TOFU 采集 known_hosts（非 22 端口须为 [127.0.0.1]:port 形式）
  local ok="" i
  for i in $(seq 1 40); do
    if ssh-keyscan -T 2 -t ed25519 -p "$PORT" 127.0.0.1 2>/dev/null \
         | grep -v '^#' | grep -v '^$' > "$TMP/known_hosts"; then
      [ -s "$TMP/known_hosts" ] && { ok=1; break; }
    fi
    sleep 0.5
  done
  [ -n "$ok" ]                                               || fail "sshd not ready"

  export NEXTPAS_SSH_E2E_HOST=127.0.0.1
  export NEXTPAS_SSH_E2E_PORT="$PORT"
  export NEXTPAS_SSH_E2E_USER=root
  export NEXTPAS_SSH_E2E_KEYFILE="$TMP/client_key"
  export NEXTPAS_SSH_E2E_KNOWN_HOSTS="$TMP/known_hosts"
  echo "[e2e] docker fixture ready: root@127.0.0.1:$PORT (container $CNAME)"
  rc=0
  run_binary || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "[e2e] ---- sshd 日志（完整）----"
    docker exec "$CNAME" cat /config/sshd.log 2>/dev/null
  fi
  exit "$rc"
}

# ---- 主入口 ----
if [ ! -x "$BIN" ]; then
  echo "[e2e] binary missing, building first…" >&2
  make -C "$DIR" build >&2                                   || fail "build"
fi

if [ "${NEXTPAS_SSH_E2E_REMOTE:-}" = "1" ]; then
  run_remote
elif [ "${NEXTPAS_SSH_E2E_LOCAL:-}" = "1" ]; then
  run_docker
else
  echo "[e2e] SKIP: 设置 NEXTPAS_SSH_E2E_LOCAL=1（Docker 夹具）或" \
       "NEXTPAS_SSH_E2E_REMOTE=1（真实服务器）后运行（opt-in 门控）"
  exit 0
fi
