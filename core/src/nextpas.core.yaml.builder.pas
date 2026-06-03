unit nextpas.core.yaml.builder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml.parser,
  nextpas.core.yaml.writer;

type
  TYamlBuilder = record
  private
    FDoc: TYamlDocument;
    FStack: array[0..31] of UInt32;
    FStackTop: Int32;
    FOwnedStrings: array of string;
    FOwnedCount: SizeUInt;
    function CurrentContainer: UInt32; inline;
    procedure AppendToContainer(ANodeIdx: UInt32);
    function RetainString(const AValue: string): TStringView;
  public
    procedure Init;
    procedure Done;
    procedure PutNull;
    procedure PutBool(const AValue: Boolean);
    procedure PutInt(const AValue: Int64);
    procedure PutFloat(const AValue: Double);
    procedure PutStr(const AValue: string);
    procedure PutStrView(const AValue: TStringView);
    procedure BeginSeq;
    procedure EndSeq;
    procedure BeginMap;
    procedure EndMap;
    procedure PutKey(const AKey: string);
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

implementation

procedure TYamlBuilder.Init;
begin
  YamlDocInit(FDoc);
  FStackTop := -1;
  SetLength(FOwnedStrings, 16);
  FOwnedCount := 0;
end;

procedure TYamlBuilder.Done;
begin
  SetLength(FDoc.Nodes, 0);
  SetLength(FDoc.Anchors, 0);
  SetLength(FOwnedStrings, 0);
  FOwnedCount := 0;
end;

function TYamlBuilder.CurrentContainer: UInt32;
begin
  if FStackTop >= 0 then
    Result := FStack[FStackTop]
  else
    Result := YAML_NODE_NONE;
end;

procedure TYamlBuilder.AppendToContainer(ANodeIdx: UInt32);
var
  LContainer: UInt32;
  LNode: PYamlNode;
  LCur: UInt32;
begin
  LContainer := CurrentContainer;
  if LContainer = YAML_NODE_NONE then
  begin
    FDoc.RootIdx := ANodeIdx;
    Exit;
  end;
  LNode := @FDoc.Nodes[LContainer];
  if LNode^.Container.FirstChild = YAML_NODE_NONE then
    LNode^.Container.FirstChild := ANodeIdx
  else
  begin
    LCur := LNode^.Container.FirstChild;
    while FDoc.Nodes[LCur].Next <> YAML_NODE_NONE do
      LCur := FDoc.Nodes[LCur].Next;
    FDoc.Nodes[LCur].Next := ANodeIdx;
  end;
end;

function TYamlBuilder.RetainString(const AValue: string): TStringView;
var
  LIndex: SizeUInt;
  LCapacity: SizeUInt;
begin
  LIndex := FOwnedCount;
  LCapacity := SizeUInt(Length(FOwnedStrings));
  if LIndex >= LCapacity then
  begin
    if LCapacity = 0 then
      SetLength(FOwnedStrings, 16)
    else
      SetLength(FOwnedStrings, LCapacity * 2);
  end;
  FOwnedStrings[LIndex] := AValue;
  Inc(FOwnedCount);
  Result := TStringView.FromStr(FOwnedStrings[LIndex]);
end;

function AddBuilderNode(var ADoc: TYamlDocument): UInt32;
begin
  Result := ADoc.NodeCount;
  if ADoc.NodeCount >= UInt32(Length(ADoc.Nodes)) then
    SetLength(ADoc.Nodes, Length(ADoc.Nodes) * 2);
  FillChar(ADoc.Nodes[Result], SizeOf(TYamlNode), 0);
  ADoc.Nodes[Result].Next := YAML_NODE_NONE;
  Inc(ADoc.NodeCount);
end;

procedure TYamlBuilder.PutNull;
var LIdx, LCont: UInt32;
begin
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkNull;
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  if LCont <> YAML_NODE_NONE then
    Inc(FDoc.Nodes[LCont].Container.Count);
end;

procedure TYamlBuilder.PutBool(const AValue: Boolean);
var LIdx, LCont: UInt32;
begin
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkBool;
  FDoc.Nodes[LIdx].BoolVal := AValue;
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  if LCont <> YAML_NODE_NONE then
    Inc(FDoc.Nodes[LCont].Container.Count);
end;

procedure TYamlBuilder.PutInt(const AValue: Int64);
var LIdx, LCont: UInt32;
begin
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkInt;
  FDoc.Nodes[LIdx].IntVal := AValue;
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  if LCont <> YAML_NODE_NONE then
    Inc(FDoc.Nodes[LCont].Container.Count);
end;

procedure TYamlBuilder.PutFloat(const AValue: Double);
var LIdx, LCont: UInt32;
begin
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkFloat;
  FDoc.Nodes[LIdx].RealVal := AValue;
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  if LCont <> YAML_NODE_NONE then
    Inc(FDoc.Nodes[LCont].Container.Count);
end;

procedure TYamlBuilder.PutStr(const AValue: string);
var LIdx, LCont: UInt32;
begin
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkString;
  FDoc.Nodes[LIdx].Str := RetainString(AValue);
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  if LCont <> YAML_NODE_NONE then
    Inc(FDoc.Nodes[LCont].Container.Count);
end;

procedure TYamlBuilder.PutStrView(const AValue: TStringView);
var LIdx, LCont: UInt32;
begin
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkString;
  FDoc.Nodes[LIdx].Str := RetainString(AValue.ToString);
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  if LCont <> YAML_NODE_NONE then
    Inc(FDoc.Nodes[LCont].Container.Count);
end;

procedure TYamlBuilder.BeginSeq;
var LIdx, LCont: UInt32;
begin
  LCont := CurrentContainer;
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkSequence;
  FDoc.Nodes[LIdx].Container.FirstChild := YAML_NODE_NONE;
  FDoc.Nodes[LIdx].Container.Count := 0;
  AppendToContainer(LIdx);
  if LCont <> YAML_NODE_NONE then
    Inc(FDoc.Nodes[LCont].Container.Count);
  if FStackTop < 31 then
  begin
    Inc(FStackTop);
    FStack[FStackTop] := LIdx;
  end;
end;

procedure TYamlBuilder.EndSeq;
begin
  if FStackTop >= 0 then
    Dec(FStackTop);
end;

procedure TYamlBuilder.BeginMap;
var LIdx, LCont: UInt32;
begin
  LCont := CurrentContainer;
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkMapping;
  FDoc.Nodes[LIdx].Container.FirstChild := YAML_NODE_NONE;
  FDoc.Nodes[LIdx].Container.Count := 0;
  AppendToContainer(LIdx);
  if LCont <> YAML_NODE_NONE then
    Inc(FDoc.Nodes[LCont].Container.Count);
  if FStackTop < 31 then
  begin
    Inc(FStackTop);
    FStack[FStackTop] := LIdx;
  end;
end;

procedure TYamlBuilder.EndMap;
begin
  if FStackTop >= 0 then
    Dec(FStackTop);
end;

procedure TYamlBuilder.PutKey(const AKey: string);
var LIdx: UInt32;
begin
  LIdx := AddBuilderNode(FDoc);
  FDoc.Nodes[LIdx].Kind := ynkString;
  FDoc.Nodes[LIdx].Str := RetainString(AKey);
  AppendToContainer(LIdx);
end;

function TYamlBuilder.Stringify: string;
begin
  Result := YamlStringify(FDoc, FDoc.RootIdx);
end;

function TYamlBuilder.StringifyPretty(const AIndent: Int32): string;
begin
  Result := YamlStringifyPretty(FDoc, FDoc.RootIdx, AIndent);
end;

end.
