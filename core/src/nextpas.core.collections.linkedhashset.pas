unit nextpas.core.collections.linkedhashset;

{$I nextpas.core.settings.inc}
{$WARN 5024 OFF}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.linkedhashset.intf,
  nextpas.core.collections.linkedhashmap;

type
  generic TLinkedHashSet<T> = class(TInterfacedObject, specialize ILinkedHashSet<T>)
  private
    type
      TInternalMap = specialize TLinkedHashMap<T, Boolean>;
      TPairType = specialize TPair<T, Boolean>;
  private
    FMap: TInternalMap;
  public
    constructor Create;
    destructor Destroy; override;

    function Add(const aElement: T): Boolean;
    function Remove(const aElement: T): Boolean;
    function Contains(const aElement: T): Boolean;
    procedure Clear;
    function First: T;
    function Last: T;
    function TryGetFirst(var aElement: T): Boolean;
    function TryGetLast(var aElement: T): Boolean;
    function IsEmpty: Boolean;
    function GetCount: SizeUInt;
  end;

  generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>;

implementation

{ TLinkedHashSet<T> }

constructor TLinkedHashSet.Create;
begin
  inherited Create;
  FMap := TInternalMap.Create;
end;

destructor TLinkedHashSet.Destroy;
begin
  FMap.Free;
  inherited Destroy;
end;

function TLinkedHashSet.Add(const aElement: T): Boolean;
begin
  if FMap.ContainsKey(aElement) then
    Exit(False);
  FMap.Add(aElement, True);
  Result := True;
end;

function TLinkedHashSet.Remove(const aElement: T): Boolean;
begin
  Result := FMap.Remove(aElement);
end;

function TLinkedHashSet.Contains(const aElement: T): Boolean;
begin
  Result := FMap.ContainsKey(aElement);
end;

procedure TLinkedHashSet.Clear;
begin
  FMap.Clear;
end;

function TLinkedHashSet.First: T;
var
  LPair: TPairType;
begin
  LPair := FMap.First;
  Result := LPair.Key;
end;

function TLinkedHashSet.Last: T;
var
  LPair: TPairType;
begin
  LPair := FMap.Last;
  Result := LPair.Key;
end;

function TLinkedHashSet.TryGetFirst(var aElement: T): Boolean;
var
  LPair: TPairType;
begin
  Result := FMap.TryGetFirst(LPair);
  if Result then
    aElement := LPair.Key;
end;

function TLinkedHashSet.TryGetLast(var aElement: T): Boolean;
var
  LPair: TPairType;
begin
  Result := FMap.TryGetLast(LPair);
  if Result then
    aElement := LPair.Key;
end;

function TLinkedHashSet.IsEmpty: Boolean;
begin
  Result := FMap.IsEmpty;
end;

function TLinkedHashSet.GetCount: SizeUInt;
begin
  Result := FMap.GetCount;
end;

{ Factory }

generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>;
type
  TImpl = specialize TLinkedHashSet<T>;
begin
  Result := TImpl.Create;
end;

end.
