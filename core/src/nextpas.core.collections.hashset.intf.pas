unit nextpas.core.collections.hashset.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.intf;

type
  generic IHashSet<T> = interface(specialize IGenericCollection<T>)
  ['{4E6B9CD0-2D7E-4E7D-A7A7-7B0E9D6ABF1A}']
    function Add(const AValue: T): Boolean;
    function Remove(const AValue: T): Boolean;
    function GetCapacity: SizeUInt;
    procedure Reserve(aCapacity: SizeUInt);
    property Capacity: SizeUInt read GetCapacity;
  end;

implementation

end.
