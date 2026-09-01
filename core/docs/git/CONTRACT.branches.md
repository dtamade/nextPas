# nextpas.core.git — 分支契约（branches）

**模块路径**：`core/src/nextpas.core.git.native.{branch,tag,stash,notes}.pas` + `nextpas.core.git.native.branches.pas` 门面
**层级**：L2（L0-L1: base, bytes, text, fs）
**Owner**：git lane
**不变量域**：分支与协作元数据（branch / tag / stash / notes）

## 1. 范围与阈值
- 源聚合：4 单元 + 1 门面 shard（`native.branches`），单 shard <800 行；loose 递归 + packed-refs `^` peeled 归并去重排序。

## 2. 不变量
- Branch：`refs/heads/*` 列表/当前/创建/删除/重命名，`HEAD` symref 跟随，对齐 `git branch --list/create/delete/move`。
- Tag：`refs/tags/*` 列表/轻量/附注/删除/重命名，附注经 `TagBuilder` + 对象剥离，对齐 `git tag --list/create/delete`（peel 16 层）。
- Stash：`logs/refs/stash` reflog 列表反序 + `GitStashPush/Apply/Pop/Drop/Clear` 原生栈（push: index/working 树落盘→index/stash 提交→reflog append→refs/stash→检出回 HEAD；apply: checkout 目标树；pop=apply+drop），对齐 `git stash`。
- Notes：`refs/notes/*` `target-hex→blob` 映射，flat 写 + 递归 fanout 透明读，`core.notesRef` 默认 `commits`，对齐 `git notes`。

## 3. 性能契约
- 列表类按需惰性读，仅触 `refs` 目录与 `packed-refs`，零重复 `ReadFile`；归并去重 `bytes.ops` 单源比较。

## 4. 稳定性
- `stash push/pop` 经 `WriteAtomic` + `reflog` 精确重写，异常 `try..finally` 不丢 refs；`notes` 读写 `try..finally` 关文件句柄。

## 5. 与总约关系
- 本域权威：分支/标签/贮藏/笔记语义以本文件为准；跨域仍以总 CONTRACT 为准。
