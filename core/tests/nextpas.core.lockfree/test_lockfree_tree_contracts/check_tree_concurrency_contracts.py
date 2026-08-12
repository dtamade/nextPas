#!/usr/bin/env python3

from pathlib import Path
import re
import sys


CORE_ROOT = Path(__file__).resolve().parents[3]
SOURCE_ROOT = CORE_ROOT / "src"
TREE_LOCK_UNITS = (
    "bplus",
    "rbtree",
    "treap",
    "scapegoat",
    "skiplist_map",
    "trie_map",
    "trie_hmt",
    "radix",
    "sortedset",
    "fenwick",
)


def normalized_source(unit_name: str) -> str:
    source_path = SOURCE_ROOT / f"nextpas.core.lockfree.{unit_name}.pas"
    return re.sub(r"\s+", " ", source_path.read_text(encoding="utf-8"))


def check_tree_lock_cas_order() -> list[str]:
    failures: list[str] = []
    correct_call = re.compile(
        r"atomic_compare_exchange_strong\s*\(\s*FLock\s*,\s*LCasExpected\s*,\s*1\b"
    )
    reversed_call = re.compile(
        r"atomic_compare_exchange_strong\s*\(\s*FLock\s*,\s*1\s*,\s*LCasExpected\b"
    )

    for unit_name in TREE_LOCK_UNITS:
        source = normalized_source(unit_name)
        if reversed_call.search(source):
            failures.append(
                f"{unit_name}: tree lock CAS uses expected=1, desired=0"
            )
        elif not correct_call.search(source):
            failures.append(
                f"{unit_name}: tree lock CAS expected=0, desired=1 not found"
            )

    return failures


def check_btree_global_locking() -> list[str]:
    source = normalized_source("btree")
    required_tokens = (
        "procedure TConcurrentBTreeImpl.GlobalReadLock",
        "procedure TConcurrentBTreeImpl.GlobalWriteLock",
        "GlobalReadLock;",
        "GlobalWriteLock;",
    )
    failures = [
        f"btree: missing instance-wide lock contract token: {token}"
        for token in required_tokens
        if token not in source
    ]
    if "NodeWriteLock(LOldRoot^)" in source:
        failures.append("btree: writer serialization still depends on captured root")
    return failures


def main() -> int:
    failures = check_tree_lock_cas_order()
    failures.extend(check_btree_global_locking())
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        print(f"tree-concurrency-contracts=fail count={len(failures)}")
        return 1

    print(f"tree-concurrency-contracts=pass units={len(TREE_LOCK_UNITS)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
