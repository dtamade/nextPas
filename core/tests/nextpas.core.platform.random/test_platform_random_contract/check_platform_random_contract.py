#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


TEST_DIR = Path(__file__).resolve().parent
REPO_ROOT = TEST_DIR.parents[3]
SOURCE = REPO_ROOT / "core" / "src" / "nextpas.core.platform.random.pas"


def read_source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def extract_ifdef_block(source: str, symbol: str) -> str:
    pattern = re.compile(rf"\{{\$IFDEF {re.escape(symbol)}\}}.*?\{{\$ENDIF\}}", re.S)
    blocks = pattern.findall(source)
    if not blocks:
        raise AssertionError(f"missing block for {symbol}")
    return "\n".join(blocks)


def check_linux_non_progress_contract(source: str) -> list[str]:
    errors: list[str] = []
    block = extract_ifdef_block(source, "NEXTPAS_LINUX")
    if "LRet = 0" not in block and "LRet <= 0" not in block:
        errors.append("Linux getrandom loop must treat zero-byte non-progress as failure")
    if "Inc(LDone, PtrUInt(LRet))" not in block:
        errors.append("Linux getrandom loop must advance only by returned byte count")
    return errors


def check_windows_chunk_contract(source: str) -> list[str]:
    errors: list[str] = []
    block = extract_ifdef_block(source, "NEXTPAS_WINDOWS")
    if "DWORD(ALen)" in block:
        errors.append("Windows RtlGenRandom must not cast full PtrUInt ALen to DWORD")
    if "High(DWORD)" not in block:
        errors.append("Windows RtlGenRandom must cap each chunk at High(DWORD)")
    if "LDone" not in block or "LChunk" not in block:
        errors.append("Windows RtlGenRandom must loop over large buffers in chunks")
    return errors


def main() -> int:
    source = read_source()
    errors: list[str] = []
    errors.extend(check_linux_non_progress_contract(source))
    errors.extend(check_windows_chunk_contract(source))
    if errors:
        print("platform.random source contract failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("platform.random source contract passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
