unit nextpas.core.json.value;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.json.types,
  nextpas.core.json.parser;

type
  TJsonValue = record
  private
    FDoc: ^TJsonDocument;
    FIdx: UInt32;
  public
    class function Create(var ADoc: TJsonDocument; AIdx: UInt32): TJsonValue; static; inline;
    function IsValid: Boolean; inline;
    function Kind: TJsonNodeKind; inline;
    function IsNull: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsInt: Boolean; inline;
    function IsReal: Boolean; inline;
    function IsStr: Boolean; inline;
    function IsArray: Boolean; inline;
    function IsObject: Boolean; inline;
    function AsBool: Boolean;
    function AsInt: Int64;
    function AsFloat: Double;
    function AsStr: TStringView;
    function ArrayLen: UInt32;
    function ArrayGet(AIndex: UInt32): TJsonValue;
    function ObjectGet(const AKey: TStringView): TJsonValue;
    function ObjectHas(const AKey: TStringView): Boolean;
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
  if FIdx = JSON_NODE_NONE then Exit(False);
  Result := FDoc^.Node(FIdx)^.BoolVal;
end;

function TJsonValue.AsInt: Int64;
begin
  if FIdx = JSON_NODE_NONE then Exit(0);
  if FDoc^.Node(FIdx)^.Kind = jnkReal then
    Exit(Int64(Trunc(FDoc^.Node(FIdx)^.RealVal)));
  Result := FDoc^.Node(FIdx)^.IntVal;
end;

function TJsonValue.AsFloat: Double;
begin
  if FIdx = JSON_NODE_NONE then Exit(0.0);
  if FDoc^.Node(FIdx)^.Kind = jnkInt then
    Exit(Double(FDoc^.Node(FIdx)^.IntVal));
  Result := FDoc^.Node(FIdx)^.RealVal;
end;

function TJsonValue.AsStr: TStringView;
begin
  if FIdx = JSON_NODE_NONE then Exit(TStringView.Empty);
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
begin
  Result.FDoc := FDoc;
  Result.FIdx := JSON_NODE_NONE;
  if (FIdx = JSON_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> jnkObject) then
    Exit;
  LNode := FDoc^.Node(FIdx);
  LCur := LNode^.Container.FirstChild;
  while LCur <> JSON_NODE_NONE do
  begin
    LKeyNode := FDoc^.Node(LCur);
    if (LKeyNode^.Kind = jnkString) and AKey.Equals(LKeyNode^.Str) then
    begin
      Result.FIdx := LKeyNode^.Next;
      Exit;
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

end.
