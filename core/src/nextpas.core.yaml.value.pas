unit nextpas.core.yaml.value;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml.parser;

type
  TYamlValue = record
  private
    FDoc: ^TYamlDocument;
    FIdx: UInt32;
    function GetNode: PYamlNode; inline;
  public
    class function Create(var ADoc: TYamlDocument; AIdx: UInt32): TYamlValue; static; inline;
    function IsValid: Boolean; inline;
    function Kind: TYamlNodeKind; inline;
    function IsNull: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsInt: Boolean; inline;
    function IsFloat: Boolean; inline;
    function IsStr: Boolean; inline;
    function IsSeq: Boolean; inline;
    function IsMap: Boolean; inline;
    function AsBool: Boolean;
    function AsInt: Int64;
    function AsFloat: Double;
    function AsStr: TStringView;
    function TryAsBool(out AValue: Boolean): Boolean;
    function TryAsInt(out AValue: Int64): Boolean;
    function TryAsFloat(out AValue: Double): Boolean;
    function TryAsStr(out AValue: TStringView): Boolean;
    function SeqLen: UInt32;
    function SeqGet(AIndex: UInt32): TYamlValue;
    { O(1) sibling walk for linear iteration. Seq: FirstChild is the first
      element. Map: FirstChild is the first key; NextSibling of a key is its
      value, NextSibling of a value is the next key. NextSibling uses this
      node's own link (not the alias-resolved target). }
    function FirstChild: TYamlValue;
    function NextSibling: TYamlValue;
    function MapGet(const AKey: TStringView): TYamlValue; overload;
    function MapGet(const AKey: string): TYamlValue; overload;
    { Get is a TOML-style alias for MapGet (same lookup semantics). }
    function Get(const AKey: TStringView): TYamlValue; overload; inline;
    function Get(const AKey: string): TYamlValue; overload; inline;
    function MapHas(const AKey: TStringView): Boolean; overload;
    function MapHas(const AKey: string): Boolean; overload;
    function MapLen: UInt32;
    function MapKeyAt(AIndex: UInt32): TStringView;
    function MapValueAt(AIndex: UInt32): TYamlValue;
  end;

implementation

class function TYamlValue.Create(var ADoc: TYamlDocument; AIdx: UInt32): TYamlValue;
begin
  Result.FDoc := @ADoc;
  Result.FIdx := AIdx;
end;

function TYamlValue.GetNode: PYamlNode;
var
  LIdx: UInt32;
  LDepth: Int32;
begin
  if (FDoc = nil) or (FIdx >= FDoc^.NodeCount()) then
  begin
    Result := nil;
    Exit;
  end;
  LIdx := FIdx;
  LDepth := 0;
  while (LIdx < FDoc^.NodeCount()) and
    (FDoc^.Node(LIdx)^.Kind = ynkAlias) and
    (LDepth < YAML_ALIAS_RESOLUTION_DEPTH_LIMIT) do
  begin
    LIdx := FDoc^.Node(LIdx)^.AliasTarget;
    Inc(LDepth);
  end;
  if LIdx < FDoc^.NodeCount() then
    Result := FDoc^.Node(LIdx)
  else
    Result := nil;
end;

function TYamlValue.IsValid: Boolean;
begin
  Result := GetNode <> nil;
end;

function TYamlValue.Kind: TYamlNodeKind;
var
  LN: PYamlNode;
begin
  LN := GetNode;
  if LN <> nil then
    Result := LN^.Kind
  else
    Result := ynkNull;
end;

function TYamlValue.IsNull: Boolean;
begin Result := Kind = ynkNull; end;

function TYamlValue.IsBool: Boolean;
begin Result := Kind = ynkBool; end;

function TYamlValue.IsInt: Boolean;
begin Result := Kind = ynkInt; end;

function TYamlValue.IsFloat: Boolean;
begin Result := Kind = ynkFloat; end;

function TYamlValue.IsStr: Boolean;
begin Result := Kind = ynkString; end;

function TYamlValue.IsSeq: Boolean;
begin Result := Kind = ynkSequence; end;

function TYamlValue.IsMap: Boolean;
begin Result := Kind = ynkMapping; end;

function TYamlValue.AsBool: Boolean;
var LN: PYamlNode;
begin
  LN := GetNode;
  if (LN <> nil) and (LN^.Kind = ynkBool) then
    Result := LN^.BoolVal
  else
    Result := False;
end;

function TYamlValue.AsInt: Int64;
var LN: PYamlNode;
begin
  LN := GetNode;
  if LN = nil then Exit(0);
  case LN^.Kind of
    ynkInt: Result := LN^.IntVal;
    ynkFloat: Result := Trunc(LN^.RealVal);
  else
    Result := 0;
  end;
end;

function TYamlValue.TryAsBool(out AValue: Boolean): Boolean;
begin
  Result := IsBool;
  if Result then
    AValue := AsBool
  else
    AValue := False;
end;

function TYamlValue.TryAsInt(out AValue: Int64): Boolean;
begin
  Result := IsInt;
  if Result then
    AValue := AsInt
  else
    AValue := 0;
end;

function TYamlValue.TryAsFloat(out AValue: Double): Boolean;
begin
  Result := IsFloat or IsInt;
  if Result then
    AValue := AsFloat
  else
    AValue := 0.0;
end;

function TYamlValue.TryAsStr(out AValue: TStringView): Boolean;
begin
  Result := IsStr;
  if Result then
    AValue := AsStr
  else
    AValue := TStringView.Empty;
end;

function TYamlValue.AsFloat: Double;
var LN: PYamlNode;
begin
  LN := GetNode;
  if LN = nil then Exit(0.0);
  case LN^.Kind of
    ynkFloat: Result := LN^.RealVal;
    ynkInt: Result := LN^.IntVal;
  else
    Result := 0.0;
  end;
end;

function TYamlValue.AsStr: TStringView;
var LN: PYamlNode;
begin
  LN := GetNode;
  if (LN <> nil) and (LN^.Kind = ynkString) then
    Result := LN^.Str
  else
    Result := TStringView.Empty;
end;

function TYamlValue.SeqLen: UInt32;
var LN: PYamlNode;
begin
  LN := GetNode;
  if (LN <> nil) and (LN^.Kind = ynkSequence) then
    Result := LN^.Container.Count
  else
    Result := 0;
end;

function TYamlValue.FirstChild: TYamlValue;
var
  LN: PYamlNode;
  LIdx: UInt32;
begin
  LN := GetNode;
  if (LN = nil) or ((LN^.Kind <> ynkSequence) and (LN^.Kind <> ynkMapping)) then
  begin
    Result.FDoc := FDoc;
    Result.FIdx := YAML_NODE_NONE;
    Exit;
  end;
  LIdx := LN^.Container.FirstChild;
  if (LIdx = YAML_NODE_NONE) or (FDoc = nil) or (LIdx >= FDoc^.NodeCount()) then
  begin
    Result.FDoc := FDoc;
    Result.FIdx := YAML_NODE_NONE;
    Exit;
  end;
  Result := TYamlValue.Create(FDoc^, LIdx);
end;

function TYamlValue.NextSibling: TYamlValue;
var
  LN: PYamlNode;
  LIdx: UInt32;
begin
  if (FDoc = nil) or (FIdx >= FDoc^.NodeCount()) then
  begin
    Result.FDoc := FDoc;
    Result.FIdx := YAML_NODE_NONE;
    Exit;
  end;
  LN := FDoc^.Node(FIdx);
  LIdx := LN^.Next;
  if (LIdx = YAML_NODE_NONE) or (LIdx >= FDoc^.NodeCount()) then
  begin
    Result.FDoc := FDoc;
    Result.FIdx := YAML_NODE_NONE;
    Exit;
  end;
  Result := TYamlValue.Create(FDoc^, LIdx);
end;

function TYamlValue.SeqGet(AIndex: UInt32): TYamlValue;
var
  LN: PYamlNode;
  LCur: UInt32;
  LI: UInt32;
begin
  LN := GetNode;
  if (LN = nil) or (LN^.Kind <> ynkSequence) or (AIndex >= LN^.Container.Count) then
  begin
    Result.FDoc := FDoc;
    Result.FIdx := YAML_NODE_NONE;
    Exit;
  end;
  LCur := LN^.Container.FirstChild;
  for LI := 1 to AIndex do
  begin
    if LCur = YAML_NODE_NONE then begin Result.FDoc := FDoc; Result.FIdx := YAML_NODE_NONE; Exit; end;
    LCur := FDoc^.Node(LCur)^.Next;
  end;
  Result := TYamlValue.Create(FDoc^, LCur);
end;

function TYamlValue.MapLen: UInt32;
var LN: PYamlNode;
begin
  LN := GetNode;
  if (LN <> nil) and (LN^.Kind = ynkMapping) then
    Result := LN^.Container.Count
  else
    Result := 0;
end;

function TYamlValue.MapGet(const AKey: TStringView): TYamlValue;
var
  LN: PYamlNode;
  LCur: UInt32;
  LI: UInt32;
  LKeyNode: PYamlNode;
begin
  LN := GetNode;
  if (LN = nil) or (LN^.Kind <> ynkMapping) then
  begin
    Result.FDoc := FDoc;
    Result.FIdx := YAML_NODE_NONE;
    Exit;
  end;
  LCur := LN^.Container.FirstChild;
  for LI := 0 to LN^.Container.Count - 1 do
  begin
    LKeyNode := FDoc^.Node(LCur);
    if (LKeyNode^.Kind = ynkString) and LKeyNode^.Str.Equals(AKey) then
    begin
      Result := TYamlValue.Create(FDoc^, LKeyNode^.Next);
      Exit;
    end;
    if LKeyNode^.Next = YAML_NODE_NONE then Break;
    LCur := FDoc^.Node(LKeyNode^.Next)^.Next;
  end;
  Result.FDoc := FDoc;
  Result.FIdx := YAML_NODE_NONE;
end;

function TYamlValue.MapGet(const AKey: string): TYamlValue;
begin
  Result := MapGet(TStringView.FromStr(AKey));
end;

function TYamlValue.Get(const AKey: TStringView): TYamlValue;
begin
  Result := MapGet(AKey);
end;

function TYamlValue.Get(const AKey: string): TYamlValue;
begin
  Result := MapGet(AKey);
end;

function TYamlValue.MapHas(const AKey: TStringView): Boolean;
begin
  Result := MapGet(AKey).IsValid;
end;

function TYamlValue.MapHas(const AKey: string): Boolean;
begin
  Result := MapGet(AKey).IsValid;
end;

function TYamlValue.MapKeyAt(AIndex: UInt32): TStringView;
var
  LN: PYamlNode;
  LCur: UInt32;
  LI: UInt32;
begin
  LN := GetNode;
  if (LN = nil) or (LN^.Kind <> ynkMapping) or (AIndex >= LN^.Container.Count) then
  begin
    Result := TStringView.Empty;
    Exit;
  end;
  LCur := LN^.Container.FirstChild;
  for LI := 1 to AIndex do
  begin
    if LCur = YAML_NODE_NONE then Exit(TStringView.Empty);
    LCur := FDoc^.Node(LCur)^.Next;
    if LCur = YAML_NODE_NONE then Exit(TStringView.Empty);
    LCur := FDoc^.Node(LCur)^.Next;
  end;
  if LCur = YAML_NODE_NONE then Exit(TStringView.Empty);
  Result := FDoc^.Node(LCur)^.Str;
end;

function TYamlValue.MapValueAt(AIndex: UInt32): TYamlValue;
var
  LN: PYamlNode;
  LCur: UInt32;
  LI: UInt32;
begin
  LN := GetNode;
  if (LN = nil) or (LN^.Kind <> ynkMapping) or (AIndex >= LN^.Container.Count) then
  begin
    Result.FDoc := FDoc;
    Result.FIdx := YAML_NODE_NONE;
    Exit;
  end;
  LCur := LN^.Container.FirstChild;
  for LI := 1 to AIndex do
  begin
    if LCur = YAML_NODE_NONE then begin Result.FDoc := FDoc; Result.FIdx := YAML_NODE_NONE; Exit; end;
    LCur := FDoc^.Node(LCur)^.Next;
    if LCur = YAML_NODE_NONE then begin Result.FDoc := FDoc; Result.FIdx := YAML_NODE_NONE; Exit; end;
    LCur := FDoc^.Node(LCur)^.Next;
  end;
  if LCur = YAML_NODE_NONE then begin Result.FDoc := FDoc; Result.FIdx := YAML_NODE_NONE; Exit; end;
  Result := TYamlValue.Create(FDoc^, FDoc^.Node(LCur)^.Next);
end;

end.
