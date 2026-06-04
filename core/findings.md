# Findings: http direct-error live safe-close proof

## Scope

- 本轮继续 HTTP Server correctness 收口，不改生产逻辑。
- 目标是把 `standalone direct-error` 在 real-socket/backpressure 尝试下的外部语义直接钉在 security 层。

## Confirmed truths

### 1. direct-error 现在有了 live-socket safe-close 代表性证据

- `test_http_security` 新增 threaded / epoll 两条 live proof，覆盖：
  - malformed request direct `400`
  - unsupported transfer-coding direct `501`
- 新用例直接锁定 peer 视角：
  - 连接会在观察窗口内关闭
  - wire 上最多只暴露一个原始 status line / prefix
  - 不会出现 synthetic `500`
  - 非法请求不会误走成功 `200`

### 2. 这批 proof 补的是 external envelope，不是内部 timeout 机理替代

- `test_http_server` 已经有 poll-driven seam / write-timeout focused proof，说明 direct-error path 会 arm deadline、partial-timeout 不会追加第二个 status line。
- 本轮新增的是 real-socket 侧的安全边界证据：即使不把“必须观测到 partial-timeout”当成硬条件，外部 peer 看到的仍然只会是原始 direct-error 或安全关闭。

### 3. 本轮没有暴露生产缺口

- 新增 4 条 live proof 在当前实现上直接通过，说明当前 threaded / epoll runtime 已经满足这条安全 envelope。
- 因此本轮保持为 coverage-expansion；没有新增生产代码，也没有调整 transport 行为。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security test`
  - `115/115 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是 representative direct-error live envelope，不是完整 direct-error matrix 的全部 live duplication。
- 下一步更值的方向仍应在：
  - facade helper boundary audit
  - 或 HTTP Server correctness 阶段结束条件的再审查
