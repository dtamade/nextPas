#!/usr/bin/env bash
set -euo pipefail

DOC="docs/BACKEND_SELECTION_GUIDE.md"

python3 - "$DOC" <<'PY'
from pathlib import Path
import sys

doc = Path(sys.argv[1]).read_text(encoding="utf-8")

def require(cond: bool, msg: str) -> None:
    if not cond:
        print(f"[FAIL] {msg}")
        raise SystemExit(1)

require(
    "**版本**: v1.5.0" in doc,
    "backend selection guide must refresh the active version header",
)
require(
    "**更新日期**: 2026-05-21" in doc,
    "backend selection guide must refresh the active update date",
)
require(
    "当前入口说明：这页聚焦 backend auto-selection / builder integration / direct selector API。" in doc,
    "backend selection guide must state its specialized scope",
)
require(
    "如果你只是普通客户端/服务端 TLS 建立，请优先回到 `docs/guides/GETTING_STARTED.md` 里的 `TSSLContextBuilder` / `TSSLConnector` / `TSSLAcceptor` / `TSSLStream` 主路径。" in doc,
    "backend selection guide must route ordinary TLS bootstrap flows back to GETTING_STARTED",
)

try:
    builder = doc.split("### 方式 1: 使用 Builder（推荐）", 1)[1].split("### 方式 2: 直接使用选择器", 1)[0]
except IndexError:
    require(False, "backend selection guide quickstart headings changed unexpectedly")

require("  fafafa.ssl," in builder, "builder quickstart must use the current public facade import")
require("  nextpas.core.tls.context.builder;" in builder, "builder quickstart must keep the builder unit import")
require("  Ctx: ISSLContext;" in builder, "builder quickstart must keep the current facade-exposed ISSLContext type")
require("nextpas.core.tls.base," not in builder, "builder quickstart must stop teaching direct base-unit imports")

print("[PASS] backend selection guide current public import truth contract passed")
PY
