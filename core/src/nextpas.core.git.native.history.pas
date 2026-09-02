unit nextpas.core.git.native.history;

{$I nextpas.core.settings.inc}

{**
 * @desc History umbrella — thin index (zero aggregation)
 *   3 shards (traversal/query/ops) <260 lines each, umbrella <30 lines,
 *   total history facade <650 lines incl. shards (umbrella itself <380 per
 *   CONTRACT). New code must use shards directly for fan-in:
 *     `uses nextpas.core.git.native.history.traversal` (revwalk/commitgraph/rev-parse)
 *     `uses nextpas.core.git.native.history.query`     (log/diff/blame/mergebase/show)
 *     `uses nextpas.core.git.native.history.ops`        (shortlog/catfile/cherry/revert)
 *   Umbrella is zero-alias / zero-forward thin gateway; TGitOid via
 *   `nextpas.core.git.native.base` or shard direct (bytes.ops single source,
 *   20B Move, TByteSpan, PByte+Len, inline ≤80 ns/op).
 * Perf: shards are `inline` thin forwards; zero-copy via bytes.ops single
 *   source (TGitOid 20B Move, TByteSpan, PByte+Len) + owner single-parse/cached.
 * Stability: ownership in owners (TCommitGraph/TPackFile IMappedFile refcounted,
 *   revwalk queues try..finally, cherrypick/revert checkout try..finally index);
 *   umbrella zero alloc/zero leak (no alias/forwards, no resource to release).
 *}

interface

implementation

end.
