unit nextpas.core.js.pure.base;
{ base: pure family shared type-carrier per four-piece (standard submodule base: nextpas.core.js.pure.base)
  single source via base canonical types (host/heap/value owners converge via impl), no mutable globals, zero logic
  single responsibility = type-carrier per four-piece base←intf←impl←门面, luxury thin — pure type-carrier only, base zero dependency per design-conventions (no same-module uses), host/value/eval/lifecycle via owner pure.host/pure.value/js.eval/js.lifecycle single source, threshold 16 via pure.hash single source, sentinels via js.eval single source, bytes.ops geometric 0→64→2×
  preferred entry = TJsPureHostState unified (via pure.host), no legacy shim, luxury thin
  inline zero-copy via bytes.ops/text.view single source (BytesCopy/SpanEqual), L0-L3 kept, wc -l ~45 <800, CONTRACT §1 }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value;
type
  { Host types — canonical single source, owner pure.base (host impl aliases this, no base→host cycle) }
  TJsPureHostRec = record
    Name: string;
    Func: TJsHostFunction;
    Method: TJsHostMethod;
    Proc: TJsHostProc;
    Kind: Integer;
    Hash: UInt32;
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
  { Heap/Value types — canonical single source, owner pure.base (value impl aliases this) }
  TJsPureProp = record Name: string; Value: TJsValue; Hash: UInt32; end;
  generic TJsArray<T> = array of T;
  TJsPurePropArray = specialize TJsArray<TJsPureProp>;
  TJsPureObject = record Id: Int64; Props: TJsPurePropArray; PropsBuckets: array of Integer; PropsMask: UInt32; end;
  TJsPureHeap = specialize TJsArray<TJsPureObject>;
  TJsValueArray = array of TJsValue;
  // single source notes: threshold via pure.hash JS_PURE_HASH_THRESHOLD, sentinels 5× via js.eval single source (no duplication)
implementation
end.
