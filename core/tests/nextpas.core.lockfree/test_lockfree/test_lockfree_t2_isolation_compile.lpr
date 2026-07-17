program test_lockfree_t2_isolation_compile;
{**
 * Compile-only smoke for T2 lockfree units that previously used SysUtils
 * symbols. Ensures dangling FreeAndNil / GetTickCount64 / IntToStr / Sleep
 * regressions fail the host fpc compile gate.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.lockfree.ttl_cache,
  nextpas.core.lockfree.timeseries_ringbuffer,
  nextpas.core.lockfree.hashmap.rtm,
  nextpas.core.lockfree.hashmap.numa,
  nextpas.core.lockfree.consistent_hashring,
  nextpas.core.lockfree.trie_hmt,
  nextpas.core.lockfree.ratelimit,
  nextpas.core.lockfree.leakybucket;

type
  TIntRtmMap = specialize TRtmHashMap<Integer, Integer>;
  TIntNumaMap = specialize TNumaShardedHashMap<Integer, Integer>;

var
  GTtl: TTTLCache;
  GTs: TTimeSeriesRingBuffer;
  GRtm: TIntRtmMap;
  GNuma: TIntNumaMap;
  GRing: TConsistentHashRing;
  GTrie: THashMappedTrie;
  GRate: TTokenBucketLimiter;
  GLeaky: TLeakyBucket;
  GV: Integer;

begin
  GTtl := TTTLCache.Create(16, 1000);
  try
    GTtl.Put('k', 'v');
  finally
    GTtl.Free;
  end;

  GTs := TTimeSeriesRingBuffer.Create(16, 1000);
  try
    GTs.Append('sample');
  finally
    GTs.Free;
  end;

  GRtm := TIntRtmMap.Create(16);
  try
    GRtm.Insert(1, 2);
    if GRtm.Find(1, GV) then
      ;
  finally
    GRtm.Free;
  end;

  GNuma := TIntNumaMap.Create(16);
  try
    GNuma.Insert(3, 4);
  finally
    GNuma.Free;
  end;

  GRing := TConsistentHashRing.Create(8);
  try
    GRing.AddNode('n1');
  finally
    GRing.Free;
  end;

  GTrie := THashMappedTrie.Create;
  try
    GTrie.Insert('a', 'b');
  finally
    GTrie.Free;
  end;

  GRate := TTokenBucketLimiter.Create(10.0, 10.0);
  try
    GRate.TryAcquire;
  finally
    GRate.Free;
  end;

  GLeaky := TLeakyBucket.Create(10.0, 10.0);
  try
    GLeaky.TryAdd;
  finally
    GLeaky.Free;
  end;

  WriteLn('lockfree-t2-isolation-compile-status=pass');
end.
