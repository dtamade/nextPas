unit nextpas.core.collections.prefixrouter.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.view;

type
  generic IPrefixRouter<V> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function Add(const AKey: string; const AValue: V): Boolean;
    function TryGet(const AKey: string; out AValue: V): Boolean;
    function TryGetLongestPrefix(const AKey: string; out AValue: V): Boolean;
    function TryGetLongestPrefixView(const AView: TStringView; out AValue: V): Boolean;
    procedure Clear;
    function GetCount: SizeUInt;
    function IsEmpty: Boolean;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
