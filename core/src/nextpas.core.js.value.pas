unit nextpas.core.js.value;
{** @desc JS Value single source is pure.value — this unit is REMOVED dual entry.
 *       Canonical owner is nextpas.core.js.pure.value (L2, pure.value single source, bytes.ops+mem.dynarray geometric single source, js.lifecycle 64B padded atomic, inline zero-copy via text.view/bytes.ops).
 *       Consumers import via pure.value or pure.base aggregated single entry; do NOT import js.value.
 *       Four-piece base←intf←impl←门面 single owner, L0-L3 kept, no threshold migration, pure.value permanent owner, CONTRACT §1为准.
 *       Kept as empty deprecated shim for one release to avoid hard break; no Heap/Value symbols here, no duplicate capability, no bytes.ops duplication.
 *       Perf: no logic, zero-copy via pure.value owner, resource try-finally in owner not lost.
 *}
{$I nextpas.core.settings.inc}
interface
implementation
end.
