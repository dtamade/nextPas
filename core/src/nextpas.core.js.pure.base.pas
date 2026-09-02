unit nextpas.core.js.pure.base;
{ base: pure family shared type-carrier per four-piece, L2 base, pure type carrier, handler inline via Hosts dynarray pool (bytes.ops geometric 0→64→2× via owner single source, mem.dynarray Exactly-Once poke amortized O(1) inline zero-copy, no per-host New/Dispose heap fragmentation, resource Finalize幂等不丢), threshold via pure.hash 16, sentinels via js.eval single source, bytes.ops single source where owner forwards }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.intf;
type
  { Host — canonical via pure.base, handlers inline via Hosts dynarray pool (bytes.ops geometric + mem.dynarray single source, no per-host New/Dispose, inline zero-copy, resource Finalize幂等不丢) — base now carries typed handlers via js.intf single source,守四件套与 L0-L3,反哺 owner能力(缺 inline 存储池能力先反哺 base) }
  TJsPureHostRec = record
    Name: string;
    Kind: Integer;
    Hash: UInt32;
    // inline handler storage via Hosts dynarray pool — no heap per-host New/Dispose, thousand hosts geometric via bytes.ops BytesDynEnsureLength single source, mem.dynarray Exactly-Once poke, inline zero-copy, resource Finalize via managed fields (func refcount)幂等不丢
    Func: TJsHostFunction;
    Method: TJsHostMethod;
    Proc: TJsHostProc;
  end;
  TJsPureHostArray = array of TJsPureHostRec;
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
  generic TJsArray<T> = array of T;
  TJsPurePropArray = specialize TJsArray<TJsPureProp>;
  TJsPureObject = record
    Id: Int64;
    Props: TJsPurePropArray;
    PropsBuckets: array of Integer;
    PropsMask: UInt32;
  end;
  TJsPureHeap = specialize TJsArray<TJsPureObject>;
  TJsValueArray = array of string;
implementation
end.
