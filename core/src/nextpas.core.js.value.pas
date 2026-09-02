unit nextpas.core.js.value deprecated 'REMOVED — delete this file; use nextpas.core.js.pure.value (L2 pure.value single source) or pure.base aggregated; do NOT import js.value (design-conventions §2 prohibits empty file to cobble four-piece, residual dual entry removed)';
{** @desc JS Value single source is pure.value — this unit is REMOVED and MUST BE DELETED from version control (no empty shim retained).
 *       Canonical owner is nextpas.core.js.pure.value (L2, pure.value single source, bytes.ops+mem.dynarray geometric single source, js.lifecycle 64B padded atomic, inline zero-copy via text.view/bytes.ops).
 *       Consumers import via pure.value or pure.base aggregated single entry; do NOT import js.value.
 *       Four-piece base←intf←impl←门面 single owner, L0-L3 kept, no threshold migration, pure.value permanent owner, CONTRACT §1为准.
 *       DELETED: no Heap/Value symbols here, no duplicate capability, no bytes.ops duplication; empty file prohibited per design-conventions §2 (禁止为凑四件套建空文件), residual dual entry removed — delete this file (rm core/src/nextpas.core.js.value.pas).
 *       Perf: no logic, zero-copy via pure.value owner, resource try-finally in owner not lost.
 *}
{$I nextpas.core.settings.inc}
interface
implementation
end.
