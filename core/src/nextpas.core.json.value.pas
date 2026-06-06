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
  { Borrowed view into a JSON document node. 8 bytes, zero allocation.
    Chain calls: Doc.Root.ObjectGet('user').ObjectGet('name').AsStr.ToString }
  TJsonValue = record
  public
    FDoc: ^TJsonDocument;
    FIdx: UInt32;
  public
    class function Create(var ADoc: TJsonDocument; AIdx: UInt32): TJsonValue; static; inline;
    function IsValid: Boolean; inline;       { False for missing keys / out-of-bounds }
    function Kind: TJsonNodeKind; inline;     { jnkNull for invalid values }
    function IsNull: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsInt: Boolean; inline;
    function IsReal: Boolean; inline;
    function IsStr: Boolean; inline;
    function IsArray: Boolean; inline;
    function IsObject: Boolean; inline;
    function AsBool: Boolean;                { False if not bool }
    function AsInt: Int64;                   { 0 if not int; truncates float }
    function AsFloat: Double;               { 0.0 if not number; promotes int }
    function AsStr: TStringView;            { Empty if not string }
    function ArrayLen: UInt32;              { 0 if not array }
    function ArrayGet(AIndex: UInt32): TJsonValue;  { Invalid if out of bounds }
    function ObjectGet(const AKey: TStringView): TJsonValue; overload; { Invalid if missing }
    function ObjectGet(const AKey: string): TJsonValue; overload;
    function ObjectHas(const AKey: TStringView): Boolean; overload;
    function ObjectHas(const AKey: string): Boolean; overload;
    function ObjectLen: UInt32;             { Number of key-value pairs }
    function ObjectKeyAt(AIndex: UInt32): TStringView;   { Key at position }
    function ObjectValueAt(AIndex: UInt32): TJsonValue;  { Value at position }
  end;

implementation

class function TJsonValue.Create(var ADoc: TJsonDocument; AIdx: UInt32): TJsonValue;
begin
  Result.FDoc := @ADoc;
  Result.FIdx := AIdx;
end;

function TJsonValue.IsValid: Boolean;
begin
  Result := FIdx <> JSON_NODE_NONE;
end;

function TJsonValue.Kind: TJsonNodeKind;
begin
  if FIdx = JSON_NODE_NONE then
    Result := jnkNull
  else
    Result := FDoc^.Node(FIdx)^.Kind;
end;

function TJsonValue.IsNull: Boolean;
begin
  Result := Kind = jnkNull;
end;

function TJsonValue.IsBool: Boolean;
begin
  Result := Kind = jnkBool;
end;

function TJsonValue.IsInt: Boolean;
begin
  Result := Kind = jnkInt;
end;

function TJsonValue.IsReal: Boolean;
begin
  Result := Kind = jnkReal;
end;

function TJsonValue.IsStr: Boolean;
begin
  Result := Kind = jnkString;
end;

function TJsonValue.IsArray: Boolean;
begin
  Result := Kind = jnkArray;
end;

function TJsonValue.IsObject: Boolean;
begin
  Result := Kind = jnkObject;
end;

function TJsonValue.AsBool: Boolean;
begin
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkBool) then Exit(False);
  Result := FDoc^.Node(FIdx)^.BoolVal;
end;

function TJsonValue.AsInt: Int64;
var LNode: PJsonNode;
begin
  if FIdx = JSON_NODE_NONE then Exit(0);
  LNode := FDoc^.Node(FIdx);
  case LNode^.Kind of
    jnkInt: Result := LNode^.IntVal;
    jnkReal: Result := Int64(Trunc(LNode^.RealVal));
  else
    Result := 0;
  end;
end;

function TJsonValue.AsFloat: Double;
var LNode: PJsonNode;
begin
  if FIdx = JSON_NODE_NONE then Exit(0.0);
  LNode := FDoc^.Node(FIdx);
  case LNode^.Kind of
    jnkReal: Result := LNode^.RealVal;
    jnkInt: Result := Double(LNode^.IntVal);
  else
    Result := 0.0;
  end;
end;

function TJsonValue.AsStr: TStringView;
begin
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkString) then
    Exit(TStringView.Empty);
  Result := FDoc^.Node(FIdx)^.Str;
end;

function TJsonValue.ArrayLen: UInt32;
begin
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkArray) then
    Exit(0);
  Result := FDoc^.Node(FIdx)^.Container.Count;
end;

function TJsonValue.ArrayGet(AIndex: UInt32): TJsonValue;
var
  LNode: PJsonNode;
  LChild: UInt32;
  I: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := JSON_NODE_NONE;
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkArray) then
    Exit;
  LNode := FDoc^.Node(FIdx);
  if AIndex >= LNode^.Container.Count then Exit;
  LChild := LNode^.Container.FirstChild;
  I := 0;
  while I < AIndex do
  begin
    if LChild = JSON_NODE_NONE then Exit;
    LChild := FDoc^.Node(LChild)^.Next;
    Inc(I);
  end;
  Result.FIdx := LChild;
end;

function TJsonValue.ObjectGet(const AKey: TStringView): TJsonValue;
var
  LNode: PJsonNode;
  LCur: UInt32;
  LKeyNode: PJsonNode;
  LKeyIdx: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := JSON_NODE_NONE;
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkObject) then
    Exit;
  LNode := FDoc^.Node(FIdx);
  if LNode^.Container.Count > JSON_OBJECT_HASH_THRESHOLD then
  begin
    FDoc^.EnsureObjectIndex(FIdx);
    LKeyIdx := FDoc^.LookupObjectIndex(FIdx, AKey);
    if LKeyIdx <> JSON_NODE_NONE then
      Result.FIdx := FDoc^.Node(LKeyIdx)^.Next;
    Exit;
  end;
  LCur := LNode^.Container.FirstChild;
  while LCur <> JSON_NODE_NONE do
  begin
    LKeyNode := FDoc^.Node(LCur);
    if (LKeyNode^.Kind = jnkString) and AKey.Equals(LKeyNode^.Str) then
    begin
      if LKeyNode^.Next <> JSON_NODE_NONE then
        Result.FIdx := LKeyNode^.Next
      else
        Result.FIdx := JSON_NODE_NONE;
    end;
    if LKeyNode^.Next <> JSON_NODE_NONE then
      LCur := FDoc^.Node(LKeyNode^.Next)^.Next
    else
      LCur := JSON_NODE_NONE;
  end;
end;

function TJsonValue.ObjectHas(const AKey: TStringView): Boolean;
begin
  Result := ObjectGet(AKey).IsValid;
end;

function TJsonValue.ObjectGet(const AKey: string): TJsonValue;
begin
  Result := ObjectGet(TStringView.FromStr(AKey));
end;

function TJsonValue.ObjectHas(const AKey: string): Boolean;
begin
  Result := ObjectGet(AKey).IsValid;
end;

function TJsonValue.ObjectLen: UInt32;
begin
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkObject) then
    Exit(0);
  Result := FDoc^.Node(FIdx)^.Container.Count;
end;

function TJsonValue.ObjectKeyAt(AIndex: UInt32): TStringView;
var
  LNode: PJsonNode;
  LCur: UInt32;
  I: UInt32;
begin
  Result := TStringView.Empty;
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkObject) then
    Exit;
  LNode := FDoc^.Node(FIdx);
  if AIndex >= LNode^.Container.Count then Exit;
  LCur := LNode^.Container.FirstChild;
  I := 0;
  while I < AIndex do
  begin
    if LCur = JSON_NODE_NONE then Exit;
    LCur := FDoc^.Node(FDoc^.Node(LCur)^.Next)^.Next;
    Inc(I);
  end;
  if LCur <> JSON_NODE_NONE then
    Result := FDoc^.Node(LCur)^.Str;
end;

function TJsonValue.ObjectValueAt(AIndex: UInt32): TJsonValue;
var
  LNode: PJsonNode;
  LCur: UInt32;
  I: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := JSON_NODE_NONE;
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkObject) then
    Exit;
  LNode := FDoc^.Node(FIdx);
  if AIndex >= LNode^.Container.Count then Exit;
  LCur := LNode^.Container.FirstChild;
  I := 0;
  while I < AIndex do
  begin
    if LCur = JSON_NODE_NONE then Exit;
    LCur := FDoc^.Node(FDoc^.Node(LCur)^.Next)^.Next;
    Inc(I);
  end;
  if LCur <> JSON_NODE_NONE then
    Result.FIdx := FDoc^.Node(LCur)^.Next;
end;

end.
