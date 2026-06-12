"""Canonical SIMD public-API facade source files for tooling.

Keep public-API analyzers on one shared file list so facade-unit drift does
not need to be fixed in multiple scripts.
"""

from __future__ import annotations

from pathlib import Path


PUBLIC_API_INTERFACE_FILES: tuple[str, ...] = (
    "src/nextpas.core.simd.pas",
)


def resolve_public_api_interface_files(a_repo_root: Path) -> list[Path]:
    return [a_repo_root / l_rel for l_rel in PUBLIC_API_INTERFACE_FILES]


def render_public_api_interface_files() -> str:
    return " and ".join(f"`{l_rel}`" for l_rel in PUBLIC_API_INTERFACE_FILES)
