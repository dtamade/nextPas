unit nextpas.core.js.host deprecated 'use nextpas.core.js.pure.host - canonical Host owner pure.host L2';
{** @desc JS Host single source is pure.host — this unit is REMOVED dual entry.
 *       Canonical owner is nextpas.core.js.pure.host (L2, pure.host single source, bytes.ops FNV1a+BytesCopy single source, text.view zero-copy, per-Context buckets instance-isolated, js.lifecycle 64B padded atomic).
 *       Consumers import via pure.host or pure.base aggregated single entry; do NOT import js.host.
 *       Four-piece base<-intf<-impl<-门面 single owner, L0-L3 kept, no threshold migration, pure.host permanent owner, CONTRACT §1为准.
 *       Kept as empty deprecated shim for one release to avoid hard break; no Host symbols here, no duplicate capability, no bytes.ops duplication.
 *       Perf: no logic, zero-copy via pure.host owner, resource try-finally in owner not lost.
 *}
{$I nextpas.core.settings.inc}
interface
implementation
end.
