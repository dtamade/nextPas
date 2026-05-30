unit nextpas.core.toml.value;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.toml.base,
  nextpas.core.toml.parser;

type
  TTomlValue = record
  public
    FDoc: ^TTomlDocument;
    FIdx: UInt32;
  public
    class function Create(var ADoc: TTomlDocument; AIdx: UInt32): TTomlValue; static; inline;
    function IsValid: Boolean; inline;
    function Kind: TTomlNodeKind; inline;
    function IsStr: Boolean; inline;
    function IsInt: Boolean; inline;
    function IsFloat: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsDateTime: Boolean; inline;
    function IsArray: Boolean; inline;
    function IsTable: Boolean; inline;
    function AsStr: TStringView;
    function AsInt: Int64;
    function AsFloat: Double;
    function AsBool: Boolean;
    function AsDateTime: TTomlDateTime;
    function Get(const AKey: TStringView): TTomlValue; overload;
    function Get(const AKey: string): TTomlValue; overload;
    function Has(const AKey: TStringView): Boolean; overload;
    function Has(const AKey: string): Boolean; overload;
    function TableLen: UInt32;
    function TableKeyAt(AIndex: UInt32): TStringView;
    function TableValueAt(AIndex: UInt32): TTomlValue;
    function ArrayLen: UInt32;
    function ArrayGet(AIndex: UInt32): TTomlValue;
  end;

implementation

class function TTomlValue.Create(var ADoc: TTomlDocument; AIdx: UInt32): TTomlValue;
begin
  Result.FDoc := @ADoc;
  Result.FIdx := AIdx;
end;

function TTomlValue.IsValid: Boolean;
begin
  Result := FIdx <> TOML_NODE_NONE;
end;

function TTomlValue.Kind: TTomlNodeKind;
begin
  if FIdx = TOML_NODE_NONE then
    Result := tnkTable
  else
    Result := FDoc^.Node(FIdx)^.Kind;
end;

function TTomlValue.IsStr: Boolean;
begin
  Result := IsValid and (FDoc^.Node(FIdx)^.Kind = tnkString);
end;

function TTomlValue.IsInt: Boolean;
begin
  Result := IsValid and (FDoc^.Node(FIdx)^.Kind = tnkInt);
end;

function TTomlValue.IsFloat: Boolean;
begin
  Result := IsValid and (FDoc^.Node(FIdx)^.Kind = tnkFloat);
end;

function TTomlValue.IsBool: Boolean;
begin
  Result := IsValid and (FDoc^.Node(FIdx)^.Kind = tnkBool);
end;

function TTomlValue.IsDateTime: Boolean;
begin
  Result := IsValid and (FDoc^.Node(FIdx)^.Kind = tnkDateTime);
end;

function TTomlValue.IsArray: Boolean;
begin
  Result := IsValid and (FDoc^.Node(FIdx)^.Kind = tnkArray);
end;

function TTomlValue.IsTable: Boolean;
begin
  Result := IsValid and (FDoc^.Node(FIdx)^.Kind = tnkTable);
end;

function TTomlValue.AsStr: TStringView;
begin
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkString) then
    Exit(TStringView.Empty);
  Result := FDoc^.Node(FIdx)^.Str;
end;

function TTomlValue.AsInt: Int64;
begin
  if FIdx = TOML_NODE_NONE then Exit(0);
  if FDoc^.Node(FIdx)^.Kind = tnkFloat then
    Exit(Int64(Trunc(FDoc^.Node(FIdx)^.FloatVal)));
  if FDoc^.Node(FIdx)^.Kind <> tnkInt then Exit(0);
  Result := FDoc^.Node(FIdx)^.IntVal;
end;

function TTomlValue.AsFloat: Double;
begin
  if FIdx = TOML_NODE_NONE then Exit(0.0);
  if FDoc^.Node(FIdx)^.Kind = tnkInt then
    Exit(Double(FDoc^.Node(FIdx)^.IntVal));
  if FDoc^.Node(FIdx)^.Kind <> tnkFloat then Exit(0.0);
  Result := FDoc^.Node(FIdx)^.FloatVal;
end;

function TTomlValue.AsBool: Boolean;
begin
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkBool) then
    Exit(False);
  Result := FDoc^.Node(FIdx)^.BoolVal;
end;

function TTomlValue.AsDateTime: TTomlDateTime;
begin
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkDateTime) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;
  Result := FDoc^.Node(FIdx)^.DT;
end;

function TTomlValue.Get(const AKey: TStringView): TTomlValue;
var
  LNode: PTomlNode;
  LCur: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := TOML_NODE_NONE;
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkTable) then
    Exit;
  LNode := FDoc^.Node(FIdx);
  LCur := LNode^.Container.FirstChild;
  while LCur <> TOML_NODE_NONE do
  begin
    if FDoc^.Node(LCur)^.Key.Equals(AKey) then
    begin
      Result.FIdx := LCur;
      Exit;
    end;
    LCur := FDoc^.Node(LCur)^.Next;
  end;
end;

function TTomlValue.Get(const AKey: string): TTomlValue;
begin
  Result := Get(TStringView.FromStr(AKey));
end;

function TTomlValue.Has(const AKey: TStringView): Boolean;
begin
  Result := Get(AKey).IsValid;
end;

function TTomlValue.Has(const AKey: string): Boolean;
begin
  Result := Get(AKey).IsValid;
end;

function TTomlValue.TableLen: UInt32;
begin
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkTable) then
    Exit(0);
  Result := FDoc^.Node(FIdx)^.Container.Count;
end;

function TTomlValue.TableKeyAt(AIndex: UInt32): TStringView;
var
  LCur: UInt32;
  LI: UInt32;
begin
  Result := TStringView.Empty;
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkTable) then
    Exit;
  if AIndex >= FDoc^.Node(FIdx)^.Container.Count then Exit;
  LCur := FDoc^.Node(FIdx)^.Container.FirstChild;
  LI := 0;
  while LI < AIndex do
  begin
    if LCur = TOML_NODE_NONE then Exit;
    LCur := FDoc^.Node(LCur)^.Next;
    Inc(LI);
  end;
  if LCur <> TOML_NODE_NONE then
    Result := FDoc^.Node(LCur)^.Key;
end;

function TTomlValue.TableValueAt(AIndex: UInt32): TTomlValue;
var
  LCur: UInt32;
  LI: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := TOML_NODE_NONE;
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkTable) then
    Exit;
  if AIndex >= FDoc^.Node(FIdx)^.Container.Count then Exit;
  LCur := FDoc^.Node(FIdx)^.Container.FirstChild;
  LI := 0;
  while LI < AIndex do
  begin
    if LCur = TOML_NODE_NONE then Exit;
    LCur := FDoc^.Node(LCur)^.Next;
    Inc(LI);
  end;
  Result.FIdx := LCur;
end;

function TTomlValue.ArrayLen: UInt32;
begin
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkArray) then
    Exit(0);
  Result := FDoc^.Node(FIdx)^.Container.Count;
end;

function TTomlValue.ArrayGet(AIndex: UInt32): TTomlValue;
var
  LCur: UInt32;
  LI: UInt32;
begin
  Result.FDoc := FDoc;
  Result.FIdx := TOML_NODE_NONE;
  if (FIdx = TOML_NODE_NONE) or (FDoc^.Node(FIdx)^.Kind <> tnkArray) then
    Exit;
  if AIndex >= FDoc^.Node(FIdx)^.Container.Count then Exit;
  LCur := FDoc^.Node(FIdx)^.Container.FirstChild;
  LI := 0;
  while LI < AIndex do
  begin
    if LCur = TOML_NODE_NONE then Exit;
    LCur := FDoc^.Node(LCur)^.Next;
    Inc(LI);
  end;
  Result.FIdx := LCur;
end;

end.
