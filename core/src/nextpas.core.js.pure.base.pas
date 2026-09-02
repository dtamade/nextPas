unit nextpas.core.js.pure.base;
{ base: pure family shared type-carrier per four-piece, zero-dependency, L2 base, pure type carrier without same-module uses, threshold via pure.hash 16, sentinels via js.eval single source, bytes.ops geometric 0→64→2× via owner single source, inline zero-copy via BytesCopy single source where owner forwards }
{$I nextpas.core.settings.inc}
interface
type
  { Host — canonical via pure.base, handlers owned separately via pure.host to keep base zero-dep, only Name/Kind/Hash here, func storage via owner pure.host parallel arrays, inline zero-copy via bytes.ops BytesCopy single source in owner }
  TJsPureHostRec = record
    Name: string;
    Kind: Integer;
    Hash: UInt32;
    // opaque handler pointers to keep base zero-dep (no js.intf), owner pure.host manages typed handlers via heap alloc, inline zero-copy via bytes.ops single source in owner, resource not lost via try-finally
    FuncPtr: Pointer;
    MethodPtr: Pointer;
    ProcPtr: Pointer;
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
