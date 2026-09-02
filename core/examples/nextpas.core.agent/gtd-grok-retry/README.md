# gtd-grok-retry

Six-dimensional completeness demo: provider chain assembly, retry, throttle, timeouts, loop, transcript.

Chain: `NewGrokProvider("grok-4") → WithRetry(TRetryPolicy.Default.WithOnAttempt) → NewThrottledProvider(NewTokenBucketGate)` with triple timeout split `Connect=10s / Total=60s / ReadIdle=60s` (`AI_TOTAL_TIMEOUT_MS=60000`).

Shows `TAgentLoop.Run(userText)` and transcript handling. Offline via `FakeProvider` fallback if no API key, so always runnable. Pattern mirrors `task888/src/gtd888.tui.ai.pas` `NewGrokProvider→Stream→Fold`.

## Build & Run

```bash
make -C core/examples/nextpas.core.agent/gtd-grok-retry build
make -C core/examples/nextpas.core.agent/gtd-grok-retry run
make -C core/examples/nextpas.core.agent/gtd-grok-retry clean test
# direct fpc:
fpc -Fu../../../src -Fi../../../src -MObjFPC -Sh -O2 gtd_grok_retry.lpr
```

## Env Vars

| Var | Purpose | Default |
|-----|---------|---------|
| `NEXTPAS_AGENT_GROK_API_KEY` | xAI API key (if unset → FakeProvider) | — |
| `NEXTPAS_AGENT_GROK_MODEL` | model name | `grok-4` |
| `NEXTPAS_AGENT_GROK_BASE_URL` | override api base | `https://api.x.ai` |

Offline: `NEXTPAS_AGENT_GROK_API_KEY` unset runs `CSCRIPT` fake deltas, no network.
