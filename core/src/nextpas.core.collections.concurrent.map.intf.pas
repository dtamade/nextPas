unit nextpas.core.collections.concurrent.map.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  generic IConcurrentMap<K, V> = interface
  ['{D9A5C3F1-6B0E-4C1D-AF3B-8E4D7F2A5C9B}']

    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    procedure Put(const AKey: K; const AValue: V);
    function PutIfAbsent(const AKey: K; const AValue: V): Boolean;
    function Remove(const AKey: K): Boolean;
    function GetOrInsert(const AKey: K; const ADefault: V): V;
    function IsEmpty: Boolean;
    procedure Clear;

    function GetCount: SizeUInt;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
