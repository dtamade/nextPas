# fafafa.ssl 文档中心

fafafa.ssl 是 Free Pascal 的高性能 SSL/TLS 库，支持 OpenSSL、WinSSL、FreePascal，以及可选的 MbedTLS / WolfSSL 后端。

---

## 快速开始

```pascal
uses
  SysUtils,
  fafafa.ssl,
  fafafa.ssl.context.builder;

var
  Ctx: ISSLContext;
  Stream: TSSLStream;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithSystemRoots
    .BuildClient;

  Stream := TSSLConnector.FromContext(Ctx)
    .ConnectSocket(YourSocket, 'example.com');
  try
    Stream.Write(Data, Length(Data));
    BytesRead := Stream.Read(Buffer, SizeOf(Buffer));
  finally
    Stream.Free;
  end;
end;
```

如果需要更低层的连接控制（手动 SNI、非阻塞等）：

```pascal
var
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
begin
  Conn := Ctx.CreateConnection(YourSocket);
  ClientConn := Conn as ISSLClientConnection;
  ClientConn.SetServerName('example.com');

  if Conn.Connect then
  begin
    Conn.Write(Data, Length(Data));
    BytesRead := Conn.Read(Buffer, SizeOf(Buffer));
  end;

  Conn.Shutdown;
end;
```

---

## 当前工程入口（post-release）

- 当前路线图：[ROADMAP.md](ROADMAP.md)
- 当前已发布 release-control plan：`plans/2026-05-12-release-v1.5.0-formalization.md`
- 当前已发布 release readiness：`test_reports/RELEASE_READINESS_V1.5.0.md`
- 演进计划：[plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md](plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md)
- 当前 workflow surface：`../.github/README.md`
- 当前构建命令：`python3 scripts/compile_all_modules.py`
- 当前最小门禁：`bash scripts/run_minimal_ci_gate.sh --fast-local`
- 当前 FreePascal TLS 1.3 focused gate：`bash scripts/run_freepascal_tls13_completeness_gate.sh --fast-local`
- 当前代码风格门禁：`python3 scripts/check_code_style.py src`
- Phase 2 入口探测：`bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local`
- Wave C closeout / 历史参考：`test_reports/WAVE_C_CLOSEOUT_STATUS_2026-03-18.md`、`test_reports/WAVE_C_LOCAL_FIRST_AND_PRE_CI_CHAIN_STATUS_2026-03-16.md`
- 历史参考：`test_reports/WAVE_C_B121_ONE_PAGE_RUNBOOK_2026-02-08.md`、`test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md`

---

## 文档导航

详见 [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)。

### 核心文档

| 文档 | 说明 |
|------|------|
| [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) | 框架集成指南 |
| [guides/USER_GUIDE.md](guides/USER_GUIDE.md) | 完整用户指南 |
| [reference/API_REFERENCE.md](reference/API_REFERENCE.md) | API 参考手册 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 架构概览 |
| [BACKEND_SELECTION_GUIDE.md](BACKEND_SELECTION_GUIDE.md) | 后端选择指南 |
| [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md) | 平台支持 |

---

## 构建与验证

```bash
python3 scripts/compile_all_modules.py
bash scripts/run_minimal_ci_gate.sh --fast-local
bash scripts/run_freepascal_tls13_completeness_gate.sh --fast-local
python3 scripts/check_code_style.py src
```

---

## 许可证

MIT License
