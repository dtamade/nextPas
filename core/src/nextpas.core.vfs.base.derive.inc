{ Historical compatibility shim for VfsDeriveChildNames family — single source is now VfsEnumerateChildSpans in nextpas.core.vfs.base.
  This file is retained for historical compatibility only; new code delegates to VfsEnumerateChildSpans via typed getter/handler.

  Canonical algorithm (single source, bytes.ops inline zero-copy):
    LowerBound O(log n) + SpanStartsWith Early-Break O(k) + slash segment + SpanEqual dedup + 16x growth cap + Move
    where k = fan-out. All prefix/compare/equal via bytes.ops
    (SpanCompare / SpanStartsWith / SpanEqual map to MemEqual / CompareBytesOrdered, inline, zero-copy views).

  Performance (hot fan-out dedup):
    - Cached previous span via IsFirst flag: no per-iteration string addressing nor span construction from result array.
      Only unique child triggers Move materialization (single-copy). This eliminates the large-directory hot-path constant
      overhead present in the pre-fix template where each unique child paid a string address plus span construction.
    - Capacity 16-doubling capped at N (or N minus Lo) — no large pre-alloc; O(k) result.
    - Inline plus zero-copy evidence: getter builds zero-copy view directly from string storage or span array;
      hot loop (LowerBound plus prefix scan plus dedup) is inline-friendly and uses MemEqual / CompareBytesOrdered
      without intermediate allocation; Move is the sole copy on unique child.

  Stability:
    No heap alloc besides Result growth; SetLength caps at N; resource release not lost (caller holds Result, no owned handles).

  No macro pollution:
    No conditional define branching, no implicit outer locals, no include-time variable convention.
    Reuse is via explicit typed getter/handler and the single procedure VfsEnumerateChildSpans — single source, no macro template.

  If this file is still included via include directive, it is a no-op shim (comment-only) to keep legacy includes compiling.
  Canonical implementation lives in nextpas.core.vfs.base.VfsEnumerateChildSpans.

  Reference cache pattern (for audit):
    IsFirst := True; PrevSpan := TByteSpan.Empty;
    for I := Lo to ACount-1 do begin
      CurSpan := AGetter(I, AGetterData);
      // ... prefix / segment ...
      if not IsFirst then
        if SpanEqual(PrevSpan, ChildSpan) then Continue;
      AHandler(ChildSpan, CurSpan, I, AHandlerData);
      PrevSpan := ChildSpan;
      IsFirst := False;
    end;
}
