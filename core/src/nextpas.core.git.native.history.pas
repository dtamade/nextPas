unit nextpas.core.git.native.history;

{$I nextpas.core.settings.inc}

{**
 * @desc History umbrella — thin index (deprecated full aggregation)
 *   3 shards (traversal/query/ops) <260 lines each, umbrella <80 lines,
 *   total history facade <650 lines incl. shards (umbrella itself <380 per
 *   CONTRACT). New code must use shards directly for fan-in:
 *     `uses nextpas.core.git.native.history.traversal` (revwalk/commitgraph/rev-parse)
 *     `uses nextpas.core.git.native.history.query`     (log/diff/blame/mergebase/show)
 *     `uses nextpas.core.git.native.history.ops`        (shortlog/catfile/cherry/revert)
 *   Umbrella keeps only shared TGitOid alias for BC; 46 inline forwards
 *   removed to restore thin-gateway aesthetic and constrain reuse degree.
 * Perf: shards are `inline` thin forwards; zero-copy via bytes.ops single
 *   source (TGitOid 20B Move, TByteSpan, PByte+Len) + owner single-parse/cached.
 * Stability: ownership in owners (TCommitGraph/TPackFile IMappedFile refcounted,
 *   revwalk queues try..finally, cherrypick/revert checkout try..finally index);
 *   umbrella zero alloc/zero leak.
 *}

interface

uses
  nextpas.core.git.native.base,
  nextpas.core.git.native.history.traversal,
  nextpas.core.git.native.history.query,
  nextpas.core.git.native.history.ops;

type
  TGitOid = nextpas.core.git.native.base.TGitOid deprecated 'Use shard directly: traversal/query/ops';

implementation

end.
