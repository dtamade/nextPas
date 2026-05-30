unit nextpas.core.collections.btree.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.treemap.base;

type
  generic IBTreeMap<K, V> = interface(specialize IGenericCollection<specialize TMapEntry<K, V>>)
  ['{B7E3A1D2-4F8C-4A9B-8D1E-6C2F5A3B7E9D}']

    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    function Add(const AKey: K; const AValue: V): Boolean;
    function AddOrAssign(const AKey: K; const AValue: V): Boolean;
    procedure Put(const AKey: K; const AValue: V);
    function Get(const AKey: K): V;
    function Remove(const AKey: K): Boolean;
    procedure Clear;

    function LowerBound(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function UpperBound(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function Floor(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function Min(out AKey: K; out AValue: V): Boolean;
    function Max(out AKey: K; out AValue: V): Boolean;
    function PopMin(out AKey: K; out AValue: V): Boolean;
    function PopMax(out AKey: K; out AValue: V): Boolean;

    function Rank(const AKey: K): SizeUInt;
    function Select(ARank: SizeUInt; out AKey: K; out AValue: V): Boolean;

    function GetCount: SizeUInt;
    function IsEmpty: Boolean;
    property Count: SizeUInt read GetCount;
  end;

  generic IBTreeSet<T> = interface(specialize IGenericCollection<T>)
  ['{C8F4B2E3-5A9D-4B0C-9E2F-7D3A6B4C8F1E}']

    function Add(const AItem: T): Boolean;
    function Contains(const AItem: T): Boolean;
    function Remove(const AItem: T): Boolean;
    procedure Clear;

    function Min(out AItem: T): Boolean;
    function Max(out AItem: T): Boolean;
    function PopMin(out AItem: T): Boolean;
    function PopMax(out AItem: T): Boolean;
    function LowerBound(const AItem: T; out AFound: T): Boolean;
    function UpperBound(const AItem: T; out AFound: T): Boolean;
    function Floor(const AItem: T; out AFound: T): Boolean;

    function GetCount: SizeUInt;
    function IsEmpty: Boolean;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
