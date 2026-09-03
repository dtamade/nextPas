{ nextpas.core.bytes.ops.single_source.inc — bytes.ops single source compile-time gate (owner=bytes.ops, L0 single source).
  Single-point abstraction for 15+ family sentinels (factory/bulk/pool/sqlite/...).
  Include after `const MY_UNIT_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;` — zero runtime cost, compile-time drift detection.
  Replaces copy-pasted {$IF not BYTES_OPS_SINGLE_SOURCE} {$FATAL ...} boilerplate; high-level single source inline/zero-copy. }
{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: must reuse bytes.ops (owner=bytes.ops)'}
{$IFEND}
