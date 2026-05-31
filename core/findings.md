## 2026-05-31 HTTP 模块第二轮审查

### Key Findings
- `THttpRouter.ServeHTTP` 现在会把 path params 回填进请求对象，但实现依赖 `(AReq as THttpRequest)` 强转；只要调用方传入别的 `IHttpRequest` 实现，就会在命中参数路由时抛 `EInvalidCast`。
- 路由树在插入参数段时只按 `nkParam` 复用节点，不校验参数名；`/users/:id/profile` 和 `/users/:name/posts` 这类兄弟路由会共享第一个参数名，后注册路由命中时拿到错误 key。
- `TH1ResponseWriter` 仍按“单次 `IWriter.Write` 必定写满”假设输出状态行、header 和 body；在 short-write writer 上会静默截断响应。
- `TUrl.Parse` 修了 authority / IPv6 / 端口越界后，仍会把 `http://host:abc/path`、`http://[::1]:abc/path` 这类非法端口静默当成 `Port = 0`。
- 现有回归测试覆盖了上一轮修复的 happy path，但还没覆盖“非 `THttpRequest` 请求对象进入 router”、“同层不同参数名 sibling routes”、“short write writer”、“非法非数字端口”等高价值边界。

### Verification
- `test_http_base`, `test_http_headers`, `test_http_url`, `test_http_router`,
  `test_http_message`, `test_http_middleware`, `test_http_h1writer`,
  `test_http_integration` 全部通过，且 `heaptrc` clean。
- 临时探针复现：
  - `servehttp-cast:EInvalidCast:Invalid type cast: TMockRequest is not a THttpRequest`
  - `param-alias:id=alice`

# Core 模块 Benchmark 对照报告 (2026-05-31, 最终更新)

## text.conv vs SysUtils (优化后)

| 函数 | text.conv | SysUtils | 比率 |
|------|-----------|----------|------|
| IntToStr | 64.9 ns | 64.0 ns | ~1.0x (持平) |
| Trim | 22.0 ns | 23.2 ns | **1.05x 快** |
| LowerCase 44B | 97.9 ns | 199.4 ns | **2.04x 快** |
| Format (3 args) | 460.4 ns | 656.0 ns | **1.42x 快** |
| TryStrToInt | 55.4 ns | 42.8 ns (Val) | 0.77x (含 trim) |

## text.number (专用算法)

| 函数 | nextPas | FPC RTL | 比率 |
|------|---------|---------|------|
| FloatToBuffer (Schubfach) | 136 ns | 490 ns | **3.6x 快** |
| ParseDouble | 56 ns | 180 ns | **3.2x 快** |
| StringBuilder 10x | 279 ns | 698 ns (concat) | **2.5x 快** |

## Collections — SwissTable vs Go/Rust (N=100K, 最终优化后)

| 操作 | nextPas Swiss | Go map | Rust HashMap | vs Go | vs Rust |
|------|--------------|--------|--------------|-------|---------|
| Put | 6.50 ms | 20.79 ms | 5.82 ms | 3.2x 快 | 0.89x |
| Put+prealloc | 3.76 ms | 12.78 ms | 2.79 ms | 3.4x 快 | 0.74x |
| Get(hit) | 2.49 ms | 4.36 ms | 2.82 ms | 1.8x 快 | **1.13x 快** |
| Get(miss) | 1.98 ms | 3.36 ms | 2.00 ms | 1.7x 快 | **0.99x ≈持平** |
| Remove | 7.36 ms | 17.73 ms | 6.76 ms | 2.4x 快 | 0.92x |

## Collections — Sort (N=10K)

| 场景 | nextPas | Go | Rust | vs Go | vs Rust |
|------|---------|-----|------|-------|---------|
| random | 222 μs | 1407 μs | 180 μs | **6.3x 快** | 0.81x |
| sorted | 9.7 μs | 57.5 μs | 7.2 μs | **5.9x 快** | 0.74x |

## Regex — nextPas vs Go/Rust

| 操作 | nextPas | Go | Rust | vs Go | vs Rust |
|------|---------|-----|------|-------|---------|
| Compile (date) | 2.9 μs | 9.4 μs | 583 μs | **3.2x 快** | **202x 快** |
| Digit Find (\d+) | 7.7 μs | 53.9 μs | 11.0 μs | **7.0x 快** | **1.43x 快** |
| FindAll (\w+) | 124 μs | 499 μs | 83 μs | **4.0x 快** | 0.67x |
| ReplaceAll | 49.5 μs | 361 μs | 27.4 μs | **7.3x 快** | 0.55x |
| Alternation (4) | 57 μs | 646 μs | 1.8 μs | **11.3x 快** | 0.03x |

## Encoding — nextPas vs Go/Rust

| 操作 | nextPas | Go | Rust | vs Go | vs Rust |
|------|---------|-----|------|-------|---------|
| Hex.Encode | 14.1 μs | 44.6 μs | 35.0 μs | **3.2x 快** | **2.5x 快** |
| Hex.Decode | 19.3 μs | 42.2 μs | — | **2.2x 快** | — |
| Base64.Encode | 34.7 μs | 31.1 μs | 39.1 μs | 0.90x | **1.13x 快** |
| Base64.Decode | 32.0 μs | 35.5 μs | — | **1.11x 快** | — |

## Log — nextPas vs Go slog

| 场景 | nextPas | Go slog | 比率 |
|------|---------|---------|------|
| Disabled | 83 ns | 14 ns | 0.17x |
| Simple Msg | 155 ns | 996 ns | **6.4x 快** |
| WithAttrs | 473 ns | 1493 ns | **3.2x 快** |
| File handler | 2379 ns | 3289 ns | **1.38x 快** |

## 总结

**优势领域（超越 Go + 接近/超越 Rust）：**
- Float 格式化/解析：3.2-3.6x 快于 FPC RTL
- Log 框架：3-6x 快于 Go slog
- Sort：6x 快于 Go，接近 Rust (81%)
- HashMap Get(hit)：超越 Rust
- LowerCase/Format：2x/1.4x 快于 SysUtils

**待优化领域：**
- HashMap Get(miss)/Remove：比 Rust 慢 40-50%
- Sort random：比 Rust 慢 20%
- Disabled log path：比 Go 慢（atomic check vs function call）
