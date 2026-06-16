unit nextpas.core.yaml.builder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.errors,
  nextpas.core.yaml.types,
  nextpas.core.yaml.parser,
  nextpas.core.yaml.writer;

type
  TYamlBuilder = record
  private
    FDoc: TYamlDocument;
    FStack: array[0..31] of UInt32;
    FMapPendingKey: array[0..31] of Boolean;
    FStackTop: Int32;
    FOwnedStrings: PString;
    FOwnedCount: SizeUInt;
    FOwnedCap: SizeUInt;
    function CurrentContainer: UInt32; inline;
    function CurrentContainerKind: TYamlNodeKind; inline;
    procedure EnsureContainerStackHasRoom;
    procedure RequireOpenContainer(
      const AKind: TYamlNodeKind;
      const AMessage: string);
    procedure RequireNoPendingMappingKey;
    procedure RequireCanAppendValue;
    procedure FinishAppendedValue(AContainerIdx: UInt32);
    procedure AppendToContainer(ANodeIdx: UInt32);
    procedure PushContainerUnchecked(ANodeIdx: UInt32);
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
  FOwnedCap := 16;
  FOwnedStrings := PString(FDoc.Allocator.Allocate(FOwnedCap * SizeOf(string)));
  if FOwnedStrings = nil then
  begin
    FDoc.Done;
    raise EOutOfMemoryError.Create('out of memory');
  end;
  FillChar(FOwnedStrings^, FOwnedCap * SizeOf(string), 0);
  FOwnedCount := 0;
end;

procedure TYamlBuilder.Done;
var
  LI: SizeUInt;
begin
  if FOwnedStrings <> nil then
  begin
    if FOwnedCount > 0 then
      for LI := 0 to FOwnedCount - 1 do
        FOwnedStrings[LI] := '';
    FDoc.Allocator.Deallocate(Pointer(FOwnedStrings));
    FOwnedStrings := nil;
  end;
  FOwnedCount := 0;
  FOwnedCap := 0;
  FDoc.Done;
end;

function TYamlBuilder.CurrentContainer: UInt32;
begin
  if FStackTop >= 0 then
    Result := FStack[FStackTop]
  else
    Result := YAML_NODE_NONE;
end;

function TYamlBuilder.CurrentContainerKind: TYamlNodeKind;
var
  LContainer: UInt32;
begin
  LContainer := CurrentContainer;
  if LContainer = YAML_NODE_NONE then
    Result := ynkNull
  else
    Result := FDoc.Node(LContainer)^.Kind;
end;

procedure TYamlBuilder.RequireNoPendingMappingKey;
begin
  if (FStackTop >= 0) and FMapPendingKey[FStackTop] then
    raise EInvalidOperationError.Create('YAML builder mapping key has no value');
end;

procedure TYamlBuilder.RequireCanAppendValue;
begin
  if CurrentContainer = YAML_NODE_NONE then
  begin
    if FDoc.NodeCount() > 0 then
      raise EInvalidOperationError.Create('YAML builder root value is already set');
    Exit;
  end;
  if CurrentContainerKind <> ynkMapping then
    Exit;
  if not FMapPendingKey[FStackTop] then
    raise EInvalidOperationError.Create('YAML builder mapping value has no key');
end;

procedure TYamlBuilder.FinishAppendedValue(AContainerIdx: UInt32);
begin
  if AContainerIdx = YAML_NODE_NONE then
    Exit;
  Inc(FDoc.Node(AContainerIdx)^.Container.Count);
  if FDoc.Node(AContainerIdx)^.Kind = ynkMapping then
    FMapPendingKey[FStackTop] := False;
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
    FDoc.SetRoot(ANodeIdx);
    Exit;
  end;
  LNode := FDoc.Node(LContainer);
  if LNode^.Container.FirstChild = YAML_NODE_NONE then
    LNode^.Container.FirstChild := ANodeIdx
  else
  begin
    LCur := LNode^.Container.FirstChild;
    while FDoc.Node(LCur)^.Next <> YAML_NODE_NONE do
      LCur := FDoc.Node(LCur)^.Next;
    FDoc.Node(LCur)^.Next := ANodeIdx;
  end;
end;

procedure TYamlBuilder.EnsureContainerStackHasRoom;
begin
  if FStackTop >= High(FStack) then
    raise EInvalidOperationError.Create('YAML builder nesting too deep');
end;

procedure TYamlBuilder.RequireOpenContainer(
  const AKind: TYamlNodeKind;
  const AMessage: string);
var
  LContainer: UInt32;
begin
  LContainer := CurrentContainer;
  if (LContainer = YAML_NODE_NONE) or
     (FDoc.Node(LContainer)^.Kind <> AKind) then
    raise EInvalidOperationError.Create(AMessage);
end;

procedure TYamlBuilder.PushContainerUnchecked(ANodeIdx: UInt32);
begin
  Inc(FStackTop);
  FStack[FStackTop] := ANodeIdx;
  FMapPendingKey[FStackTop] := False;
end;

function TYamlBuilder.RetainString(const AValue: string): TStringView;
var
  LIndex: SizeUInt;
  LOldCap: SizeUInt;
  LNewPtr: Pointer;
begin
  LIndex := FOwnedCount;
  if LIndex >= FOwnedCap then
  begin
    LOldCap := FOwnedCap;
    if FOwnedCap = 0 then
      FOwnedCap := 16
    else
      FOwnedCap := FOwnedCap * 2;
    LNewPtr := FDoc.Allocator.Reallocate(Pointer(FOwnedStrings),
      FOwnedCap * SizeOf(string));
    if LNewPtr = nil then
      raise EOutOfMemoryError.Create('out of memory');
    FOwnedStrings := PString(LNewPtr);
    FillChar(FOwnedStrings[LOldCap], (FOwnedCap - LOldCap) * SizeOf(string), 0);
  end;
  FOwnedStrings[LIndex] := AValue;
  Inc(FOwnedCount);
  Result := TStringView.FromStr(FOwnedStrings[LIndex]);
end;

procedure TYamlBuilder.PutNull;
var LIdx, LCont: UInt32;
begin
  RequireCanAppendValue;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkNull;
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  FinishAppendedValue(LCont);
end;

procedure TYamlBuilder.PutBool(const AValue: Boolean);
var LIdx, LCont: UInt32;
begin
  RequireCanAppendValue;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkBool;
  FDoc.Node(LIdx)^.BoolVal := AValue;
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  FinishAppendedValue(LCont);
end;

procedure TYamlBuilder.PutInt(const AValue: Int64);
var LIdx, LCont: UInt32;
begin
  RequireCanAppendValue;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkInt;
  FDoc.Node(LIdx)^.IntVal := AValue;
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  FinishAppendedValue(LCont);
end;

procedure TYamlBuilder.PutFloat(const AValue: Double);
var LIdx, LCont: UInt32;
begin
  RequireCanAppendValue;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkFloat;
  FDoc.Node(LIdx)^.RealVal := AValue;
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  FinishAppendedValue(LCont);
end;

procedure TYamlBuilder.PutStr(const AValue: string);
var LIdx, LCont: UInt32;
begin
  RequireCanAppendValue;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkString;
  FDoc.Node(LIdx)^.Str := RetainString(AValue);
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  FinishAppendedValue(LCont);
end;

procedure TYamlBuilder.PutStrView(const AValue: TStringView);
var LIdx, LCont: UInt32;
begin
  RequireCanAppendValue;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkString;
  FDoc.Node(LIdx)^.Str := RetainString(AValue.ToString);
  AppendToContainer(LIdx);
  LCont := CurrentContainer;
  FinishAppendedValue(LCont);
end;

procedure TYamlBuilder.BeginSeq;
var LIdx, LCont: UInt32;
begin
  RequireCanAppendValue;
  EnsureContainerStackHasRoom;
  LCont := CurrentContainer;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkSequence;
  FDoc.Node(LIdx)^.Container.FirstChild := YAML_NODE_NONE;
  FDoc.Node(LIdx)^.Container.Count := 0;
  AppendToContainer(LIdx);
  FinishAppendedValue(LCont);
  PushContainerUnchecked(LIdx);
end;

procedure TYamlBuilder.EndSeq;
begin
  RequireOpenContainer(ynkSequence, 'YAML builder sequence is not open');
  RequireNoPendingMappingKey;
  Dec(FStackTop);
end;

procedure TYamlBuilder.BeginMap;
var LIdx, LCont: UInt32;
begin
  RequireCanAppendValue;
  EnsureContainerStackHasRoom;
  LCont := CurrentContainer;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkMapping;
  FDoc.Node(LIdx)^.Container.FirstChild := YAML_NODE_NONE;
  FDoc.Node(LIdx)^.Container.Count := 0;
  AppendToContainer(LIdx);
  FinishAppendedValue(LCont);
  PushContainerUnchecked(LIdx);
end;

procedure TYamlBuilder.EndMap;
begin
  RequireOpenContainer(ynkMapping, 'YAML builder mapping is not open');
  RequireNoPendingMappingKey;
  Dec(FStackTop);
end;

procedure TYamlBuilder.PutKey(const AKey: string);
var LIdx: UInt32;
begin
  RequireOpenContainer(ynkMapping, 'YAML builder mapping is not open');
  RequireNoPendingMappingKey;
  LIdx := FDoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    raise EOutOfMemoryError.Create('out of memory');
  FDoc.Node(LIdx)^.Kind := ynkString;
  FDoc.Node(LIdx)^.Str := RetainString(AKey);
  AppendToContainer(LIdx);
  FMapPendingKey[FStackTop] := True;
end;

function TYamlBuilder.Stringify: string;
begin
  RequireNoPendingMappingKey;
  Result := YamlStringify(FDoc, FDoc.Root);
end;

function TYamlBuilder.StringifyPretty(const AIndent: Int32): string;
begin
  RequireNoPendingMappingKey;
  Result := YamlStringifyPretty(FDoc, FDoc.Root, AIndent);
end;

end.
