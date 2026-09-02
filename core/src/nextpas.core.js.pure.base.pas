unit nextpas.core.js.pure.base;
{ base: pure family shared type-carrier per four-piece (standard submodule base: nextpas.core.js.pure.base) }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value;
type
  { Host — canonical via pure.base }
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
  { Heap/Value — canonical via pure.base }
  TJsPureProp = record Name: string; Value: TJsValue; Hash: UInt32; end;
  generic TJsArray<T> = array of T;
  TJsPurePropArray = specialize TJsArray<TJsPureProp>;
  TJsPureObject = record Id: Int64; Props: TJsPurePropArray; PropsBuckets: array of Integer; PropsMask: UInt32; end;
  TJsPureHeap = specialize TJsArray<TJsPureObject>;
  TJsValueArray = array of TJsValue;
implementation
end.
