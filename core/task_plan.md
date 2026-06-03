# Task Plan: HTTP server runtime foundation implementation batch 2

## Goal

在已落地的 `nextpas.core.net.server` threaded foundation 上继续做 correctness
收口，优先补齐 runtime 稳定性与 public transport contract 的边角。

## Checklist

- [x] 用 focused RED 锁定 threaded runtime 的 handler 异常隔离语义。
- [x] 修复 detached worker / inline fallback 在 handler 异常下不会打穿 accept loop。
- [x] 让 `IHttpServerTransport` 的 ownership 类型/常量可经由 `nextpas.core.http`
  facade 直接消费，不必额外 `uses nextpas.core.net.server`。
- [x] 跑 changed-surface focused tests，并确认 heaptrc 无泄漏。
