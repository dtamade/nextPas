# Findings: Header name normalization fast path

## Scope

本轮是 internal performance refactor，不改 public headers API，不改 HTTP parser/server 语义。目标是降低
`THttpHeaders.Add` / `Set_` 在 lowercase header-name hot path 上的重复扫描与字符串复制。

## Confirmed truths

### 1. Old hot path scanned lowercase names twice

旧实现：

- `ValidateName(AName)` 扫描 name，检查空值、非法字符、冒号。
- `Normalize(AName)` 再扫描并复制 string，即使 name 已经是 lowercase。

对 parser callback 来说，header field 已由 llhttp adapter 以 lowercase 累积；因此 `Add` 的常见路径是
valid lowercase name，重复 scan/copy 是纯成本。

### 2. Validation contract is now directly guarded

新增 focused guard：

- `Add('', 'value')` 抛 `EHttpError`。
- `Set_('Bad:Name', 'value')` 抛 `EHttpError`。
- `Add('x-good', 'bad'#13'value')` 抛 `EHttpError`。
- `Set_('x-good', 'bad'#0'value')` 抛 `EHttpError`。

这条 guard 在生产优化前已通过，用作 refactor safety proof。

### 3. Combined validation + uppercase detection preserves behavior

`THttpHeaders` 现在使用 `ValidateNameAndNeedsNormalize`：

- 同一轮 scan 完成 name validation 和 uppercase detection。
- lowercase valid name 直接复用 `AName`。
- uppercase/mixed-case public input 仍调用 `Normalize`，继续 canonical lowercase storage。
- `Del` 也改用 `NormalizeIfNeeded`，lowercase delete 不再复制。

### 4. Benchmark projection

Baseline：

```sh
make -C benchmarks/nextpas.core.http/bench_headers clean run
```

| workload | before ns/op |
| --- | ---: |
| Set+Get 5 headers | 828.2 |
| Set+Get 15 headers | 2665.1 |
| Add 15 headers | 1783.5 |

Confirmation：

```sh
make -C benchmarks/nextpas.core.http/bench_headers run
```

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| Set+Get 5 headers | 828.2 | 784.3 |
| Set+Get 15 headers | 2665.1 | 2516.8 |
| Add 15 headers | 1783.5 | 1635.8 |

`bench_h1parser` projection:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| workload | ns/op |
| --- | ---: |
| llhttp adapter simple GET | 622.7 |
| llhttp adapter 10 headers | 3324.8 |
| llhttp adapter POST 1KB | 1429.5 |
| llhttp adapter pipeline | 6280.6 |

The direct headers benchmark shows clear improvement on the intended rows. Parser projection is smaller/noisier because
URL/header callback string materialization and TE validation still dominate the full adapter path.

## Remaining gaps / risks

- `bench_headers` is still a small local microbenchmark; use it as directional evidence, not as a permanent ranking.
- Header value validation still scans separately. That is intentional: value bytes are independent from name normalization,
  and removing it would weaken injection protection.
- Full parser still spends material cost in callback string append, header Add, and later metadata parsing.

## Next optimization target

1. Add parser/server request metadata cache for `Content-Length`, `Transfer-Encoding`, `Connection`, and `Expect`, reducing
   repeated `GetAll` / `LowerCase` / `TextSplit` work.
2. Alternatively, split header callback materialization further: field/value string append capacity or direct lowercase field storage.
3. Keep C llhttp comparator as a separate proof track; current high-value work remains adapter materialization.
