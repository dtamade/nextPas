#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

EXPECTED_ARCH = {
    "neon": "arm64",
    "riscvv": "riscv64",
}
EXPECTED_LABEL = {
    "neon": "NEON",
    "riscvv": "RISCVV",
}
DIR_PATTERN = re.compile(r"^native-evidence-(neon|riscvv)-\d{8}-\d{6}$")
HEADER_PATTERN = re.compile(r"^# SIMD Non-X86 Native Evidence \((\d{8}-\d{6})\)$", re.MULTILINE)
SYNTHETIC_OUTPUT_ROOT_MARKER = "/tmp/simd-import-smoke"


@dataclass
class EvidenceResult:
    backend: str
    ok: bool
    directory: str
    summary: str
    environment: str
    host_arch: str = ""
    runner_kind: str = ""
    build_mode: str = ""
    detail: str = ""


def failed_result(backend: str, detail: str) -> EvidenceResult:
    return EvidenceResult(
        backend=backend,
        ok=False,
        directory="",
        summary="",
        environment="",
        detail=detail,
    )


def parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding='utf-8').splitlines():
        line = raw_line.strip()
        if not line or '=' not in line:
            continue
        key, value = line.split('=', 1)
        values[key.strip()] = value.strip()
    return values


def latest_evidence_dir(root: Path, backend: str) -> Path:
    matches = [
        candidate for candidate in root.iterdir()
        if candidate.is_dir() and DIR_PATTERN.match(candidate.name) and candidate.name.startswith(f'native-evidence-{backend}-')
    ]
    if not matches:
        raise FileNotFoundError(f'missing native evidence directory for backend={backend} under {root}')
    return sorted(matches, key=lambda item: item.name)[-1]


def require_contains(text: str, fragment: str, detail: str) -> None:
    if fragment not in text:
        raise AssertionError(detail)


def count_contains(text: str, fragment: str, minimum: int, detail: str) -> None:
    count = text.count(fragment)
    if count < minimum:
        raise AssertionError(f'{detail}; found={count}, need>={minimum}')


def require_summary_stamp_matches(summary: str, evidence_dir: Path) -> None:
    match = HEADER_PATTERN.search(summary)
    if not match:
        raise AssertionError('summary header stamp missing or invalid')
    summary_stamp = match.group(1)
    expected_stamp = evidence_dir.name.rsplit('-', 2)[1] + '-' + evidence_dir.name.rsplit('-', 1)[1]
    if summary_stamp != expected_stamp:
        raise AssertionError(f'summary stamp mismatch: header={summary_stamp}, directory={expected_stamp}')


def verify_backend(root: Path, backend: str) -> EvidenceResult:
    try:
        evidence_dir = latest_evidence_dir(root, backend)
    except FileNotFoundError as exc:
        raise FileNotFoundError(f'backend={backend} root={root}: {exc}') from exc
    summary_path = evidence_dir / 'summary.md'
    env_path = evidence_dir / 'environment.txt'

    try:
        if not summary_path.is_file():
            raise FileNotFoundError(f'missing summary.md in {evidence_dir}')
        if not env_path.is_file():
            raise FileNotFoundError(f'missing environment.txt in {evidence_dir}')

        summary = summary_path.read_text(encoding='utf-8')
        env = parse_env_file(env_path)

        expected_arch = EXPECTED_ARCH[backend]
        expected_label = EXPECTED_LABEL[backend]
        host_arch = env.get('host_arch', '')
        backend_value = env.get('backend', '')
        build_mode = env.get('fa_build_mode', '')
        runner_kind = env.get('runner_kind', '')

        require_contains(summary, '# SIMD Non-X86 Native Evidence', 'summary header missing')
        require_summary_stamp_matches(summary, evidence_dir)
        require_contains(summary, f'- Host Arch: {expected_arch}', 'summary host arch mismatch')
        require_contains(summary, f'- Backend: {expected_label}', 'summary backend label mismatch')
        require_contains(summary, '## list-suites', 'summary missing list-suites section')
        require_contains(summary, '## DispatchAPI + PublicAbi', 'summary missing dispatch/publicabi section')
        require_contains(
            summary,
            '## Runtime Parity (TTestCase_NonX86BackendParity,TTestCase_DataPlane)',
            'summary missing runtime parity section',
        )
        require_contains(
            summary,
            '--suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane',
            'summary missing runtime parity suite execution marker',
        )
        require_contains(summary, '[TEST] Running:', 'summary missing test execution marker')
        count_contains(summary, '[BUILD] OK', 2, 'summary missing build ok markers')
        count_contains(summary, '[TEST] OK', 3, 'summary missing test ok markers')
        count_contains(summary, '[LEAK] OK', 3, 'summary missing leak ok markers')
        if SYNTHETIC_OUTPUT_ROOT_MARKER in summary:
            raise AssertionError(f'synthetic import-smoke marker detected: {SYNTHETIC_OUTPUT_ROOT_MARKER}')

        if host_arch != expected_arch:
            raise AssertionError(f'host_arch mismatch: expect {expected_arch}, got {host_arch or "<empty>"}')
        if backend_value != backend:
            raise AssertionError(f'backend mismatch: expect {backend}, got {backend_value or "<empty>"}')
        if build_mode != 'Release':
            raise AssertionError(f'fa_build_mode mismatch: expect Release, got {build_mode or "<empty>"}')
        if runner_kind not in {'canonical', 'direct-fpc'}:
            raise AssertionError(f'runner_kind invalid: {runner_kind or "<empty>"}')
        if runner_kind == 'canonical':
            require_contains(summary, '## Implementation Audit', 'canonical summary missing implementation audit section')
            require_contains(summary, 'NONX86_IMPL_AUDIT_SUMMARY', 'canonical summary missing impl-audit summary line')
        else:
            require_contains(summary, '## Build Smoke', 'direct-fpc summary missing build smoke section')
    except (AssertionError, FileNotFoundError) as exc:
        raise type(exc)(
            f'backend={backend} directory={evidence_dir} summary={summary_path} environment={env_path}: {exc}'
        ) from exc

    return EvidenceResult(
        backend=backend,
        ok=True,
        directory=str(evidence_dir),
        summary=str(summary_path),
        environment=str(env_path),
        host_arch=host_arch,
        runner_kind=runner_kind,
        build_mode=build_mode,
        detail='ok',
    )


def render_summary(results: Iterable[EvidenceResult]) -> str:
    result_list = list(results)
    ok_count = sum(1 for item in result_list if item.ok)
    backend_part = ','.join(item.backend for item in result_list)
    status = 'ok' if ok_count == len(result_list) else 'fail'
    return (
        'NONX86_NATIVE_EVIDENCE_SUMMARY ' 
        f'backends={backend_part} ' 
        f'ok={ok_count} ' 
        f'total={len(result_list)} ' 
        f'status={status}'
    )


def main() -> int:
    parser = argparse.ArgumentParser(description='Verify native non-x86 evidence summaries/logs')
    parser.add_argument('--root', default='tests/nextpas.core.simd/logs')
    parser.add_argument('--backend', choices=['all', 'neon', 'riscvv'], default='all')
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--summary-line', action='store_true')
    args = parser.parse_args()

    root = Path(args.root).resolve()
    backends = ['neon', 'riscvv'] if args.backend == 'all' else [args.backend]
    results: list[EvidenceResult] = []

    try:
        for backend in backends:
            result = verify_backend(root, backend)
            results.append(result)
            if not args.json:
                print(f'[NATIVE-EVIDENCE] backend={backend}')
                print(f'  - directory:    {result.directory}')
                print(f'  - summary:      {result.summary}')
                print(f'  - environment:  {result.environment}')
                print(f'  - host_arch:    {result.host_arch}')
                print(f'  - runner_kind:  {result.runner_kind}')
                print(f'  - build_mode:   {result.build_mode}')
        if args.json:
            print(json.dumps([asdict(item) for item in results], ensure_ascii=False, sort_keys=True))
        else:
            print('[NATIVE-EVIDENCE] OK')
        if args.summary_line:
            print(render_summary(results))
        return 0
    except (AssertionError, FileNotFoundError) as exc:
        failed_results = list(results)
        if len(results) < len(backends):
            failed_results.append(failed_result(backends[len(results)], str(exc)))
        for backend in backends[len(failed_results):]:
            failed_results.append(failed_result(backend, 'not-run'))
        if args.json:
            print(json.dumps({
                'ok': False,
                'root': str(root),
                'backend': args.backend,
                'error': str(exc),
                'results': [asdict(item) for item in failed_results],
            }, ensure_ascii=False, sort_keys=True))
        else:
            print(f'[NATIVE-EVIDENCE] FAILED: {exc}')
        if args.summary_line:
            print(render_summary(failed_results))
        return 1


if __name__ == '__main__':
    sys.exit(main())
