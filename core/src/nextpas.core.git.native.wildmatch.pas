unit nextpas.core.git.native.wildmatch;

{$I nextpas.core.settings.inc}

{ REMOVED — owner converged to L1 `nextpas.core.text.wildmatch` single source.
  This shim previously forwarded wildmatch via inline to `text.wildmatch`
  (bytes.ops GrowArrayCapacity single source, inline hot path, zero-copy range
  scan, no alloc, zero SysUtils). The unit has been deleted; new code must
  `uses nextpas.core.text.wildmatch` directly. File kept as zero-symbol
  tombstone to preserve history; unit contains no code and will be pruned
  from the build tree. }

interface

implementation

end.
