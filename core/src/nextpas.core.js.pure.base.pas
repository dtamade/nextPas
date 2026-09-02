unit nextpas.core.js.pure.base;
{ base: pure family shared type-carrier per four-piece, L2 base, pure type carrier, handler storage owned by pure.host via typed single source (bytes.ops geometric 0→64→2× via owner single source, mem.dynarray Exactly-Once poke amortized O(1) inline zero-copy, resource Finalize via pure.host幂等不丢), threshold via pure.hash 16, sentinels via js.eval single source, bytes.ops single source where owner forwards }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.collections.base;
type
  { Host — canonical via pure.base minimal carrier (Name/Kind/Hash only), handlers owned by pure.host single source via js.intf (base zero-dep, base←intf单向, bytes.ops pool via pure.host, inline zero-copy, resource Finalize via pure.host managed fields幂等不丢) }
  TJsPureHostRec = record
    Name: string;
    Kind: Integer;
    Hash: UInt32;
  end;
  TJsPureHostArray = specialize TGenericArray<TJsPureHostRec>;
  TJsPureHostBuckets = record
    Buckets: array of Integer;
    Mask: UInt32;
    Count: Integer;
  end;
  TJsPureHostState = record
    Hosts: TJsPureHostArray;
    Buckets: TJsPureHostBuckets;
  end;
  { Heap/Value — canonical via pure.base, value stored as raw string+kind to keep base zero-dep (no TJsValue), owner pure.value converts via TJsValue single source, bytes.ops geometric via BytesNextCapacity single source, inline zero-copy }
  TJsPureProp = record
    Name: string;
    Hash: UInt32;
    Raw: string;
    Kind: Integer;
  end;
  TJsPurePropArray = specialize TGenericArray<TJsPureProp>;
  TJsPureObject = record
    Id: Int64;
    Props: TJsPurePropArray;
    PropsBuckets: array of Integer;
    PropsMask: UInt32;
  end;
  TJsPureHeap = specialize TGenericArray<TJsPureObject>;
  TJsValueArray = array of string;
implementation
end.
