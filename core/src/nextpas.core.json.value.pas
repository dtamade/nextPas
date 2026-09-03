unit nextpas.core.json.value;
{ Zero-cost JSON value accessor. TJsonValue is an 8-byte record (pointer + index)
  that borrows into a TJsonDocument's node array. No heap allocation per access.

  Lifetime: valid as long as the owning TJsonDocument/IJsonDocument is alive.
  Invalid values (missing keys, out-of-bounds) return safe defaults (0, empty, false). }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.json.types,
  nextpas.core.json.parser;

type
  { canonical TJsonValue lives in json.types (L1 narrow boundary for js.intf);
    this unit provides rich accessors via helper for the canonical handle }
  TJsonValue = nextpas.core.json.types.TJsonValue;

  TJsonValueHelper = record helper for TJsonValue
  public
    class function Create(var ADoc: TJsonDocument; AIdx: UInt32): TJsonValue; static; inline;
    function IsValid: Boolean; inline;       { False for missing keys / out-of-bounds }
    function Kind: TJsonNodeKind; inline;     { jnkNull for invalid values }
    function IsNull: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsInt: Boolean; inline;
    function IsReal: Boolean; inline;
    { YAML/TOML-style alias for IsReal. }
    function IsFloat: Boolean; inline;
    function IsStr: Boolean; inline;
    function IsArray: Boolean; inline;
    function IsObject: Boolean; inline;
    function AsBool: Boolean;                { False if not bool }
    function AsInt: Int64;                   { 0 if not int; truncates float }
    function AsFloat: Double;               { 0.0 if not number; promotes int }
    function AsStr: TStringView;            { Empty if not string }
    function TryAsBool(out AValue: Boolean): Boolean;
    function TryAsInt(out AValue: Int64): Boolean;
    function TryAsFloat(out AValue: Double): Boolean;
    function TryAsStr(out AValue: TStringView): Boolean;
    function ArrayLen: UInt32;              { 0 if not array }
    function ArrayGet(AIndex: UInt32): TJsonValue;  { Invalid if out of bounds }
    function ObjectGet(const AKey: TStringView): TJsonValue; overload; { Invalid if missing }
    function ObjectGet(const AKey: string): TJsonValue; overload;
    { TOML/YAML-style alias for ObjectGet. }
    function Get(const AKey: TStringView): TJsonValue; overload; inline;
    function Get(const AKey: string): TJsonValue; overload; inline;
    function ObjectHas(const AKey: TStringView): Boolean; overload;
    function ObjectHas(const AKey: string): Boolean; overload;
    function ObjectLen: UInt32;             { Number of key-value pairs }
    function ObjectKeyAt(AIndex: UInt32): TStringView;   { Key at position }
    function ObjectValueAt(AIndex: UInt32): TJsonValue;  { Value at position }
    { RawSlice: zero-copy view into original input (no re-serialize). Empty if missing/invalid. }
    function RawSlice: TStringView; inline;
  end;

implementation

class function TJsonValueHelper.Create(var ADoc: TJsonDocument; AIdx: UInt32): TJsonValue;
begin
  Result.FDoc := @ADoc;
  Result.FIdx := AIdx;
end;

function TJsonValueHelper.IsValid: Boolean;
begin
  Result := FIdx <> JSON_NODE_NONE;
end;

function TJsonValueHelper.Kind: TJsonNodeKind;
begin
  if FIdx = JSON_NODE_NONE then
    Result := jnkNull
  else
    Result := PJsonDocument(FDoc)^.Node(FIdx)^.Kind;
end;

function TJsonValueHelper.IsNull: Boolean;
begin
  Result := Kind = jnkNull;
end;

function TJsonValueHelper.IsBool: Boolean;
begin
  Result := Kind = jnkBool;
end;

function TJsonValueHelper.IsInt: Boolean;
begin
  Result := Kind = jnkInt;
end;

function TJsonValueHelper.IsReal: Boolean;
begin
  Result := Kind = jnkReal;
end;

function TJsonValueHelper.IsFloat: Boolean;
begin
  Result := IsReal;
end;

function TJsonValueHelper.IsStr: Boolean;
begin
  Result := Kind = jnkString;
end;

function TJsonValueHelper.IsArray: Boolean;
begin
  Result := Kind = jnkArray;
end;

function TJsonValueHelper.IsObject: Boolean;
begin
  Result := Kind = jnkObject;
end;

function TJsonValueHelper.AsBool: Boolean;
begin
  if (FIdx = JSON_NODE_NONE) or (PJsonDocument(FDoc)^.Node(FIdx)^.Kind <> jnkBool) then Exit(False);
  Result := PJsonDocument(FDoc)^.Node(FIdx)^.BoolVal;
end;

function TJsonValueHelper.AsInt: Int64;
var LNode: PJsonNode;
begin
  if FIdx = JSON_NODE_NONE then Exit(0);
  LNode := PJsonDocument(FDoc)^.Node(FIdx);
  case LNode^.Kind of
    jnkInt: Result := LNode^.IntVal;
    jnkReal: Result := Int64(Trunc(LNode^.RealVal));
  else
    Result := 0;
  end;
end;

function TJsonValueHelper.AsFloat: Double;
var LNode: PJsonNode;
begin
  if FIdx = JSON_NODE_NONE then Exit(0.0);
  LNode := PJsonDocument(FDoc)^.Node(FIdx);
  case LNode^.Kind of
    jnkReal: Result := LNode^.RealVal;
    jnkInt: Result := Double(LNode^.IntVal);
  else
    Result := 0.0;
  end;
end;

function TJsonValueHelper.AsStr: TStringView;
begin
  if (FIdx = JSON_NODE_NONE) or (PJsonDocument(FDoc)^.Node(FIdx)^.Kind <> jnkString) then
    Exit(TStringView.Empty);
  Result := PJsonDocument(FDoc)^.Node(FIdx)^.Str;
end;

function TJsonValueHelper.TryAsBool(out AValue: Boolean): Boolean;
begin
  Result := IsBool;
  if Result then
    AValue := AsBool
  else
    AValue := False;
end;

function TJsonValueHelper.TryAsInt(out AValue: Int64): Boolean;
begin
  Result := IsInt;
  if Result then
    AValue := AsInt
  else
    AValue := 0;
end;

function TJsonValueHelper.TryAsFloat(out AValue: Double): Boolean;
begin
  Result := IsReal or IsInt;
  if Result then
    AValue := AsFloat
  else
    AValue := 0.0;
end;

function TJsonValueHelper.TryAsStr(out AValue: TStringView): Boolean;
begin
  Result := IsStr;
  if Result then
    AValue := AsStr
  else
    AValue := TStringView.Empty;
end;

function TJsonValueHelper.ArrayLen: UInt32;
begin
  if (FIdx = JSON_NODE_NONE) or (PJsonDocument(FDoc)^.Node(FIdx)^.Kind <> jnkArray) then
    Exit(0);
  Result := PJsonDocument(FDoc)^.Node(FIdx)^.Container.Count;
end;

function TJsonValueHelper.ArrayGet(AIndex: UInt32): TJsonValue;
var
  LNode: PJsonNode;
  LChild: UInt32;
  I: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := JSON_NODE_NONE;
  if (FIdx = JSON_NODE_NONE) or (PJsonDocument(FDoc)^.Node(FIdx)^.Kind <> jnkArray) then
    Exit;
  LNode := PJsonDocument(FDoc)^.Node(FIdx);
  if AIndex >= LNode^.Container.Count then Exit;
  LChild := LNode^.Container.FirstChild;
  I := 0;
  while I < AIndex do
  begin
    if LChild = JSON_NODE_NONE then Exit;
    LChild := PJsonDocument(FDoc)^.Node(LChild)^.Next;
    Inc(I);
  end;
  Result.FIdx := LChild;
end;

function TJsonValueHelper.ObjectGet(const AKey: TStringView): TJsonValue;
var
  LNode: PJsonNode;
  LCur: UInt32;
  LKeyNode: PJsonNode;
  LKeyIdx: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := JSON_NODE_NONE;
  if (FIdx = JSON_NODE_NONE) or (PJsonDocument(FDoc)^.Node(FIdx)^.Kind <> jnkObject) then
    Exit;
  LNode := PJsonDocument(FDoc)^.Node(FIdx);
  if LNode^.Container.Count > JSON_OBJECT_HASH_THRESHOLD then
  begin
    PJsonDocument(FDoc)^.EnsureObjectIndex(FIdx);
    LKeyIdx := PJsonDocument(FDoc)^.LookupObjectIndex(FIdx, AKey);
    if LKeyIdx <> JSON_NODE_NONE then
    begin
      Result.FIdx := PJsonDocument(FDoc)^.Node(LKeyIdx)^.Next;
      Exit;
    end;
  end;
  LCur := LNode^.Container.FirstChild;
  while LCur <> JSON_NODE_NONE do
  begin
    LKeyNode := PJsonDocument(FDoc)^.Node(LCur);
    if (LKeyNode^.Kind = jnkString) and AKey.Equals(LKeyNode^.Str) then
    begin
      if LKeyNode^.Next <> JSON_NODE_NONE then
        Result.FIdx := LKeyNode^.Next
      else
        Result.FIdx := JSON_NODE_NONE;
    end;
    if LKeyNode^.Next <> JSON_NODE_NONE then
      LCur := PJsonDocument(FDoc)^.Node(LKeyNode^.Next)^.Next
    else
      LCur := JSON_NODE_NONE;
  end;
end;

function TJsonValueHelper.ObjectHas(const AKey: TStringView): Boolean;
begin
  Result := ObjectGet(AKey).IsValid;
end;

function TJsonValueHelper.ObjectGet(const AKey: string): TJsonValue;
begin
  Result := ObjectGet(TStringView.FromStr(AKey));
end;

function TJsonValueHelper.Get(const AKey: TStringView): TJsonValue;
begin
  Result := ObjectGet(AKey);
end;

function TJsonValueHelper.Get(const AKey: string): TJsonValue;
begin
  Result := ObjectGet(AKey);
end;

function TJsonValueHelper.ObjectHas(const AKey: string): Boolean;
begin
  Result := ObjectGet(AKey).IsValid;
end;

function TJsonValueHelper.ObjectLen: UInt32;
begin
  if (FIdx = JSON_NODE_NONE) or (PJsonDocument(FDoc)^.Node(FIdx)^.Kind <> jnkObject) then
    Exit(0);
  Result := PJsonDocument(FDoc)^.Node(FIdx)^.Container.Count;
end;

function TJsonValueHelper.ObjectKeyAt(AIndex: UInt32): TStringView;
var
  LNode: PJsonNode;
  LCur: UInt32;
  I: UInt32;
begin
  Result := TStringView.Empty;
  if (FIdx = JSON_NODE_NONE) or (PJsonDocument(FDoc)^.Node(FIdx)^.Kind <> jnkObject) then
    Exit;
  LNode := PJsonDocument(FDoc)^.Node(FIdx);
  if AIndex >= LNode^.Container.Count then Exit;
  LCur := LNode^.Container.FirstChild;
  I := 0;
  while I < AIndex do
  begin
    if LCur = JSON_NODE_NONE then Exit;
    LCur := PJsonDocument(FDoc)^.Node(PJsonDocument(FDoc)^.Node(LCur)^.Next)^.Next;
    Inc(I);
  end;
  if LCur <> JSON_NODE_NONE then
    Result := PJsonDocument(FDoc)^.Node(LCur)^.Str;
end;

function TJsonValueHelper.ObjectValueAt(AIndex: UInt32): TJsonValue;
var
  LNode: PJsonNode;
  LCur: UInt32;
  I: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := JSON_NODE_NONE;
  if (FIdx = JSON_NODE_NONE) or (PJsonDocument(FDoc)^.Node(FIdx)^.Kind <> jnkObject) then
    Exit;
  LNode := PJsonDocument(FDoc)^.Node(FIdx);
  if AIndex >= LNode^.Container.Count then Exit;
  LCur := LNode^.Container.FirstChild;
  I := 0;
  while I < AIndex do
  begin
    if LCur = JSON_NODE_NONE then Exit;
    LCur := PJsonDocument(FDoc)^.Node(PJsonDocument(FDoc)^.Node(LCur)^.Next)^.Next;
    Inc(I);
  end;
  if LCur <> JSON_NODE_NONE then
    Result.FIdx := PJsonDocument(FDoc)^.Node(LCur)^.Next;
end;

function TJsonValueHelper.RawSlice: TStringView;
var
  LNode: PJsonNode;
  LInput: TStringView;
begin
  if FIdx = JSON_NODE_NONE then
    Exit(TStringView.Empty);
  LNode := PJsonDocument(FDoc)^.Node(FIdx);
  if LNode^.RawLen = 0 then
    Exit(TStringView.Empty);
  LInput := PJsonDocument(FDoc)^.Input();
  if (SizeUInt(LNode^.RawStart) + SizeUInt(LNode^.RawLen) > LInput.Len) then
    Exit(TStringView.Empty);
  Result := TStringView.Create(LInput.Data + LNode^.RawStart, LNode^.RawLen);
end;

end.
