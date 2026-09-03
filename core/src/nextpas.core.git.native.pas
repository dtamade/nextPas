unit nextpas.core.git.native;

{$I nextpas.core.settings.inc}

{**
 * @deprecated Use `nextpas.core.git.native.objects` directly — object-layer duplicate collapsed.
 *  Owner boundary: `nextpas.core.git.native.objects` is the single source for
 *  object-layer (oid/zlib/loose/pack/refs/objmodel/write); `native` is a collapsed
 *  BC shim with zero type/const/function re-exports to avoid double thin gateway
 *  and I-Cache duplication (fan-in = 1: objects → owners). New code must use
 *  `nextpas.core.git.native.objects` directly for all object-layer types/consts/functions.
 *  Extended domains are shard facades (staging/history/branches/transport/extensions)
 *  and must be used directly (`uses nextpas.core.git.native.staging` etc.);
 *  legacy `uses nextpas.core.git.native` for any domain is deprecated and will be removed.
 *  Perf: object-layer `inline` + zero-copy (Move/PByte+Len/TByteSpan via bytes.ops
 *  single source) lives single-sourced in `native.objects`; this shim holds zero
 *  inline forwards and zero type aliases to avoid I-Cache duplication and fan-in dilution.
 *  Stability: TPackFile owns IMappedFile (refcounted, auto released on Free);
 *  TBytes refcounted, exception-safe (no manual free leak).
 *}

interface

{ Collapsed BC shim — zero re-exports. Use nextpas.core.git.native.objects directly.
  Intentionally empty to collapse double thin gateway and converge fan-in to objects→owners. }

implementation

end.
