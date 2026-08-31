#!/usr/bin/env bash
# e2e_ssh_live 编排器 —— 对真实 OpenSSH 服务器的互操作测试 (opt-in).
#
# 模式：
#   NEXTPAS_SSH_E2E_LOCAL=1   本地 Docker 夹具 (alpine + openssh-server,
#                             一次性密钥、随机高端口, 全封闭可重复)
#   NEXTPAS_SSH_E2E_REMOTE=1  真实服务器;需提供：
#                               NEXTPAS_SSH_E2E_HOST / _USER / _KEYFILE
#                               (_PORT 可选, 默认 22)
#   两者都不设置              SKIP (exit 0), 不进默认 gate 的 opt-in 语义.
#
# 扩展：
#   NEXTPAS_SSH_E2E_ASYNC=1   本地/远程额外跑 async 二进制 (test_ssh_e2e_async)
#   NEXTPAS_SSH_E2E_ASYNC_JUMP=1 本地 dual-container Async ProxyJump 夹具
#                               (target 不映射端口, jump 映射; HOST=target)
#
# 已知_hosts：未显式提供 NEXTPAS_SSH_E2E_KNOWN_HOSTS 时用 ssh-keyscan 做 TOFU。
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$(cd "$DIR/../../.." && pwd)/build/projects/nextpas.core.ssh/e2e_ssh_live/test_ssh_e2e"
BIN_ASYNC="$(cd "$DIR/../../.." && pwd)/build/projects/nextpas.core.ssh/e2e_ssh_live/test_ssh_e2e_async"
IMAGE="np/ssh-e2e:latest"

fail() { echo "[e2e] FAILED: $*" >&2; exit 1; }

need_env_remote() {
  for v in NEXTPAS_SSH_E2E_HOST NEXTPAS_SSH_E2E_USER NEXTPAS_SSH_E2E_KEYFILE; do
    [ -n "${!v:-}" ] || fail "remote 模式需要 $v"
  done
}

# ---- 运行被测二进制 (heaptrc 泄漏门禁与 common.mk 同语义) ----
run_binary() {
  local bin="$1" label="$2" dump rc=0
  dump="$TMP/heaptrc-${label}.log"
  rm -f "$dump"
  HEAPTRC="haltonnotreleased,log=$dump" "$bin"; rc=$?
  if [ -f "$dump" ]; then
    grep -q '^Heap dump by heaptrc unit' "$dump" || fail "no heaptrc dump ($label)"
    grep -q '^0 unfreed memory blocks : 0$' "$dump" || { cat "$dump"; fail "unfreed blocks ($label)"; }
    echo "[e2e] heaptrc OK $label (0 unfreed)"
  fi
  return $rc
}

# ---- remote 模式：直连真实服务器 ----
run_remote() {
  need_env_remote
  TMP="$(mktemp -d /tmp/np-ssh-e2e.XXXXXX)"
  trap 'rm -rf "$TMP"' EXIT
  if [ -z "${NEXTPAS_SSH_E2E_KNOWN_HOSTS:-}" ]; then
    echo "[e2e] known_hosts 未提供, ssh-keyscan TOFU…"
    ssh-keyscan -T 5 -t ed25519,rsa -p "${NEXTPAS_SSH_E2E_PORT:-22}" \
      "$NEXTPAS_SSH_E2E_HOST" > "$TMP/known_hosts" 2>/dev/null
    grep -qv '^#' "$TMP/known_hosts" || fail "ssh-keyscan 无结果"
    export NEXTPAS_SSH_E2E_KNOWN_HOSTS="$TMP/known_hosts"
  fi
  echo "[e2e] target=$NEXTPAS_SSH_E2E_USER@${NEXTPAS_SSH_E2E_HOST}:${NEXTPAS_SSH_E2E_PORT:-22}"
  run_binary "$BIN" "sync" || exit $?
  if [ -x "$BIN_ASYNC" ] && [ "${NEXTPAS_SSH_E2E_ASYNC:-}" = "1" ]; then
    echo "[e2e] running async binary…"
    run_binary "$BIN_ASYNC" "async" || exit $?
  fi
  if [ -n "${NEXTPAS_SSH_E2E_JUMP_HOST:-}" ] && [ -x "$BIN_ASYNC" ]; then
    echo "[e2e] JUMP_HOST 已设, async via jump 已在 async 二进制内覆盖"
  fi
}

# ---- docker 模式：一次性 OpenSSH 容器夹具 ----
run_docker() {
  command -v docker >/dev/null 2>&1 || fail "docker 不可用 (NEXTPAS_SSH_E2E_LOCAL=1 已显式要求)"
  docker ps >/dev/null 2>&1 || fail "docker daemon 不可访问"
  [ "$(id -u)" = 0 ] || true
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "[e2e] building fixture image $IMAGE …"
    docker build -q -t "$IMAGE" -f "$DIR/Dockerfile.e2e" "$DIR" >/dev/null \
      || fail "fixture image build failed"
  fi
  TMP="$(mktemp -d /tmp/np-ssh-e2e.XXXXXX)"
  CNAME="np-ssh-e2e-$$"
  cleanup() { docker rm -f "$CNAME" >/dev/null 2>&1; rm -rf "$TMP"; }
  trap cleanup EXIT INT TERM
  ssh-keygen -q -t ed25519 -N '' -f "$TMP/host_ed25519"      || fail "host keygen"
  ssh-keygen -q -t ed25519 -N '' -f "$TMP/client_key"        || fail "client keygen"
  ssh-keygen -q -t rsa -b 2048 -N '' -f "$TMP/client_rsa_key" || fail "rsa client keygen"
  ssh-keygen -q -t ed25519 -N 'enc-pass-88' -f "$TMP/client_enc_key" || fail "enc client keygen"
  cp "$TMP/client_key.pub" "$TMP/authorized_keys"
  cat "$TMP/client_rsa_key.pub" >> "$TMP/authorized_keys"
  cat "$TMP/client_enc_key.pub" >> "$TMP/authorized_keys"
  cp "$DIR/sshd_e2e_config" "$TMP/sshd_config"
  mkdir -p "$TMP/stage"
  mv "$TMP/sshd_config" "$TMP/host_ed25519" "$TMP/authorized_keys" "$TMP/stage/"
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
  export NEXTPAS_SSH_E2E_RSA_KEYFILE="$TMP/client_rsa_key"
  export NEXTPAS_SSH_E2E_ENC_KEYFILE="$TMP/client_enc_key"
  export NEXTPAS_SSH_E2E_ENC_PASSPHRASE='enc-pass-88'
  export NEXTPAS_SSH_E2E_KNOWN_HOSTS="$TMP/known_hosts"
  echo "[e2e] docker fixture ready: root@127.0.0.1:$PORT (container $CNAME)"
  rc=0
  run_binary "$BIN" "sync" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "[e2e] ---- sshd 日志 (完整) ----"
    docker exec "$CNAME" cat /config/sshd.log 2>/dev/null
    exit "$rc"
  fi
  if [ -x "$BIN_ASYNC" ]; then
    echo "[e2e] running async binary on same fixture…"
    run_binary "$BIN_ASYNC" "async" || rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "[e2e] ---- sshd 日志 (完整) ----"
      docker exec "$CNAME" cat /config/sshd.log 2>/dev/null
      exit "$rc"
    fi
  fi
  # 若要求 dual-container jump 额外验证, 复用同一 TMP 密钥但另起 network
  if [ "${NEXTPAS_SSH_E2E_ASYNC_JUMP:-}" = "1" ] && [ -x "$BIN_ASYNC" ]; then
    echo "[e2e] async jump dual-container fixture requested — running…"
    # cleanup 当前单容器后再起 dual; 保留 TMP
    docker rm -f "$CNAME" >/dev/null 2>&1
    trap - EXIT; trap - INT; trap - TERM
    run_docker_dual || exit $?
  fi
  # 正常结束由 trap 清理
  docker rm -f "$CNAME" >/dev/null 2>&1
  trap - EXIT; trap - INT; trap - TERM
  rm -rf "$TMP"
  exit 0
}

run_docker_dual() {
  # dual: target 不映射端口 + jump 映射, 通过 docker network 直连
  local NET="np-ssh-e2e-net-$$"
  local C_TGT="np-ssh-e2e-tgt-$$" C_JUMP="np-ssh-e2e-jump-$$"
  local JPORT="" ok="" i rc=0
  docker network create "$NET" >/dev/null || fail "docker network create"
  cleanup_dual() { docker rm -f "$C_JUMP" "$C_TGT" >/dev/null 2>&1; docker network rm "$NET" >/dev/null 2>&1; rm -rf "$TMP"; }
  trap cleanup_dual EXIT INT TERM
  # 复用已有 TMP/keys, 为 target/jump 各准备 stage
  ssh-keygen -q -t ed25519 -N '' -f "$TMP/host_target"  || fail "target host keygen"
  ssh-keygen -q -t ed25519 -N '' -f "$TMP/host_jump"    || fail "jump host keygen"
  mkdir -p "$TMP/stage_tgt" "$TMP/stage_jump"
  cp "$DIR/sshd_e2e_config" "$TMP/stage_tgt/sshd_config"
  cp "$DIR/sshd_e2e_config" "$TMP/stage_jump/sshd_config"
  cp "$TMP/host_target" "$TMP/stage_tgt/host_ed25519"
  cp "$TMP/host_jump" "$TMP/stage_jump/host_ed25519"
  cp "$TMP/authorized_keys" "$TMP/stage_tgt/authorized_keys"
  cp "$TMP/authorized_keys" "$TMP/stage_jump/authorized_keys"
  # target: 仅内网, alias target
  docker run -d --name "$C_TGT" --network "$NET" --network-alias target \
    --entrypoint sleep "$IMAGE" 600 >/dev/null || fail "docker run target"
  docker cp "$TMP/stage_tgt" "$C_TGT":/np-in || fail "docker cp target"
  docker exec "$C_TGT" sh -c 'mkdir -p /config && mv /np-in/sshd_config /config/sshd_config && mv /np-in/host_ed25519 /config/host_ed25519 && mv /np-in/authorized_keys /config/authorized_keys && chown -R root:root /config && chmod 700 /config && chmod 600 /config/host_ed25519 && chmod 644 /config/authorized_keys && rm -rf /np-in' || fail "prep target"
  docker exec -d "$C_TGT" /usr/sbin/sshd -f /config/sshd_config -E /config/sshd.log || fail "start target sshd"
  # jump: 映射外网端口, 同网络
  docker run -d --name "$C_JUMP" --network "$NET" -p 127.0.0.1::22 --entrypoint sleep "$IMAGE" 600 >/dev/null || fail "docker run jump"
  docker cp "$TMP/stage_jump" "$C_JUMP":/np-in || fail "docker cp jump"
  docker exec "$C_JUMP" sh -c 'mkdir -p /config && mv /np-in/sshd_config /config/sshd_config && mv /np-in/host_ed25519 /config/host_ed25519 && mv /np-in/authorized_keys /config/authorized_keys && chown -R root:root /config && chmod 700 /config && chmod 600 /config/host_ed25519 && chmod 644 /config/authorized_keys && rm -rf /np-in' || fail "prep jump"
  docker exec -d "$C_JUMP" /usr/sbin/sshd -f /config/sshd_config -E /config/sshd.log || fail "start jump sshd"
  JPORT="$(docker port "$C_JUMP" 22 | head -1 | sed 's/^.*://')"
  [ -n "$JPORT" ] || fail "no jump mapped port"
  for i in $(seq 1 40); do
    if docker exec "$C_TGT" sh -c 'ss -tlnp 2>/dev/null | grep -q :22 || netstat -tlnp 2>/dev/null | grep -q :22 || sleep 0.2; cat /config/sshd.log 2>/dev/null | grep -q "Server listening"' 2>/dev/null; then ok=1; break; fi
    sleep 0.2
  done
  sleep 1
  # 收集 jump known_hosts (外网端口) + target known_hosts (内网 hostname 从 host_target.pub 构造)
  ssh-keyscan -T 2 -t ed25519 -p "$JPORT" 127.0.0.1 2>/dev/null | grep -v '^#' | grep -v '^$' > "$TMP/known_hosts_jump" || true
  [ -s "$TMP/known_hosts_jump" ] || fail "jump ssh-keyscan empty"
  # target 的 known_hosts 条目：由 host_target.pub 直接构造 (target 主机名)
  local TPUB
  TPUB="$(cut -d' ' -f1-2 "$TMP/host_target.pub")"
  echo "target $TPUB" > "$TMP/known_hosts_target"
  cat "$TMP/known_hosts_jump" "$TMP/known_hosts_target" > "$TMP/known_hosts"
  export NEXTPAS_SSH_E2E_HOST=target
  export NEXTPAS_SSH_E2E_PORT=22
  export NEXTPAS_SSH_E2E_JUMP_HOST=127.0.0.1
  export NEXTPAS_SSH_E2E_JUMP_PORT="$JPORT"
  export NEXTPAS_SSH_E2E_JUMP_KNOWN_HOSTS="$TMP/known_hosts_jump"
  # 为 async 二进制, HOST 侧的 known_hosts 需包含两条; 单独复用
  export NEXTPAS_SSH_E2E_KNOWN_HOSTS="$TMP/known_hosts"
  export NEXTPAS_SSH_E2E_USER=root
  export NEXTPAS_SSH_E2E_JUMP_USER=root
  export NEXTPAS_SSH_E2E_KEYFILE="$TMP/client_key"
  export NEXTPAS_SSH_E2E_JUMP_KEYFILE="$TMP/client_key"
  export NEXTPAS_SSH_E2E_KNOWN_HOSTS="$TMP/known_hosts"
  echo "[e2e-dual] jump=127.0.0.1:$JPORT target=target:22 net=$NET"
  run_binary "$BIN_ASYNC" "async-dual" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "[e2e-dual] ---- jump sshd log ----"; docker exec "$C_JUMP" cat /config/sshd.log 2>/dev/null
    echo "[e2e-dual] ---- target sshd log ----"; docker exec "$C_TGT" cat /config/sshd.log 2>/dev/null
    exit "$rc"
  fi
  echo "[e2e-dual] PASS"
  docker rm -f "$C_JUMP" "$C_TGT" >/dev/null 2>&1
  docker network rm "$NET" >/dev/null 2>&1
  trap - EXIT; trap - INT; trap - TERM
  rm -rf "$TMP"
}

# ---- 主入口 ----
if [ ! -x "$BIN" ]; then
  echo "[e2e] binary missing, building first…" >&2
  make -C "$DIR" build >&2                                   || fail "build"
fi
if [ ! -x "$BIN_ASYNC" ]; then
  echo "[e2e] async binary missing, building…" >&2
  make -C "$DIR" build >&2 || fail "build async"
fi

if [ "${NEXTPAS_SSH_E2E_REMOTE:-}" = "1" ]; then
  run_remote
elif [ "${NEXTPAS_SSH_E2E_LOCAL:-}" = "1" ]; then
  run_docker
else
  echo "[e2e] SKIP: 设置 NEXTPAS_SSH_E2E_LOCAL=1 (Docker 夹具) 或" \
       "NEXTPAS_SSH_E2E_REMOTE=1 (真实服务器) 后运行 (opt-in 门控)"
  exit 0
fi
