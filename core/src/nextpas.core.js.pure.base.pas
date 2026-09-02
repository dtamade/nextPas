unit nextpas.core.js.pure.base;
{ base: pure family shared type-carrier per four-piece (standard submodule base: nextpas.core.js.pure.base)
  single source via base canonical types (host/heap/value owners converge via impl), no mutable globals, zero logic
  single responsibility = type-carrier per four-piece base←intf←impl←门面, luxury thin — pure type-carrier only
  base zero dependency — standard submodule exception per design-conventions §2 / CONTRACT §1: uses narrow to parent contract (js.base/js.intf) + L1/L2 owners (text.view/json) for type reference only, no same-module pure.host/pure.value/js.eval/js.lifecycle (lifecycle/Host/Heap/Value/IO 均 via owner pure.host/pure.value/js.eval/js.lifecycle single source, no thin-forward debt), threshold 16 via pure.hash single source, sentinels 5× via js.eval single source, bytes.ops geometric 0→64→2× single source BytesNextCapacity, inline zero-copy via bytes.ops/text.view (BytesCopy/SpanEqual/TStringView.Equals) single source, L0-L3 kept, wc -l ~45 <800, resource by pure.impl Close+hostStateClear+valueStateClear 幂等不丢, CONTRACT §1 anchored }
  // CONTRACT §1 anchored: base zero dependency = no same-module uses (pure.host/value/eval/lifecycle forbidden, via owner single source); parent js.base/js.intf + text.view/json narrow type-carrier exception, L0-L3 single source via bytes.ops/text.view, no FFI/platform.dl, 零逻辑純载体
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base, // CONTRACT §1 exception: parent contract type-carrier (js.base), base zero dependency standard submodule — no same-module pure.*,
  nextpas.core.js.intf, // CONTRACT §1 exception: TJsValue/TJsHostFunction narrow (js.intf), base zero dependency — lifecycle/host/value/eval via owner single source
  nextpas.core.text.view, // L1 owner text.view zero-copy TStringView.Equals/BytesCopy single source via bytes.ops
  nextpas.core.json, // L2 owner json narrow (json.types via json), base zero dependency exception, no FFI/platform.dl
  nextpas.core.json.value; // L2 owner json.value — TJsonValue narrow, via json owner single source
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
