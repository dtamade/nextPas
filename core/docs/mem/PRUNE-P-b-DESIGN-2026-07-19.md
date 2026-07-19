# P-b Tier-3 prune（EXECUTED）

**日期**: 2026-07-19
**动作**: **EXECUTED** — 15 个无 prod consumer 的 Tier-3 `allocator.*` + 对应 test 目录
**保留**: `blockpool.growable`（`blockpool.sharded` + `test_growing_block_pool` 依赖）
**前序**: [PRUNE-P-a-DESIGN-2026-07-19.md](PRUNE-P-a-DESIGN-2026-07-19.md) · [FACADES-SURFACE.md](FACADES-SURFACE.md)

## 删除清单

| 单元 | 测试目录 |
|------|----------|
| prediction | test_prediction, test_prediction_allocator |
| numa | test_numa |
| replay | test_replay |
| huge_page | test_huge_page, test_huge_page_allocator |
| watermark | test_watermark |
| sliding | test_sliding |
| mapped_file | test_mapped_file |
| bitmap | test_bitmap, test_bitmap_allocator |
| cascade | test_cascade, test_cascade_allocator |
| coalesce | test_coalesce |
| compact | test_compact |
| cow | test_cow, test_cow_allocator |
| group | test_group |
| pool2 | test_pool2 |
| prefix | test_prefix, test_prefix_allocator |

**证据**: 重扫 `core/src` 非 mem **0** 引用；门面无 re-export。

## 规模

| | 约计 |
|--|------|
| mem 源单元 | 97 → **82**（P-a 后 97，本批 −15） |
| mem test_* 目录 | 135 → **114**（约 −21） |
| allocator.* 子单元 | 46 → **31** |

## 不做

- 删 `blockpool.growable`
- 门面 Tier-1/2 收紧（P-d）
- 复活任何 P-a/P-b 名
