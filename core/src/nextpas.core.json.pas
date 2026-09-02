unit nextpas.core.json;
{**
 * @desc JSON 门面：解析、序列化、DOM 访问、Marshal。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.intf,
  nextpas.core.io.intf,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.json.writer,
  nextpas.core.mem.allocator.base;

type
  TJsonNodeKind = nextpas.core.json.types.TJsonNodeKind;
  TJsonError = nextpas.core.json.types.TJsonError;
  TJsonValue = nextpas.core.json.types.TJsonValue;
  IJsonDocument = nextpas.core.json.types.IJsonDocument;

{ Parse JSON string into a document. Returns IJsonDocument (auto-released). }
function JsonParse(const AInput: string): IJsonDocument; overload;
function JsonParse(const AInput: TStringView): IJsonDocument; overload;
{ Bulk-read IReader then parse (not token-streaming Decoder). }
function JsonParse(const AReader: IReader): IJsonDocument; overload;
function TryJsonParse(const AInput: string; out ADoc: IJsonDocument): Boolean; overload;
function TryJsonParse(const AReader: IReader; out ADoc: IJsonDocument): Boolean; overload;

{ Parse with custom allocator (arena/pool for bulk allocation). }
function JsonParseWith(const AInput: string; const AAllocator: TMemAllocator): IJsonDocument; overload;
function JsonParseWith(const AInput: TStringView; const AAllocator: TMemAllocator): IJsonDocument; overload;

{ Serialize a TJsonValue subtree to compact JSON string. }
function JsonStringify(const AValue: TJsonValue): string;

{ Object field readers with defaults. Missing keys and type mismatches
  return ADefault; non-object inputs return ADefault as well. No exceptions. }
function JsonIntField(const AValue: TJsonValue; const AKey: string;
  ADefault: Int64 = 0): Int64;
function JsonFloatField(const AValue: TJsonValue; const AKey: string;
  ADefault: Double = 0.0): Double;
function JsonStrField(const AValue: TJsonValue; const AKey: string;
  const ADefault: string = ''): string;
function JsonBoolField(const AValue: TJsonValue; const AKey: string;
  ADefault: Boolean = False): Boolean;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.mem.default,
  nextpas.core.errors,
  nextpas.core.format.limits,
  nextpas.core.text.escape;

type
  TJsonDocumentImpl = class(TInterfacedObject, IJsonDocument)
  private
    FDoc: TJsonDocument;
    FInputCopy: string;
  public
    constructor Create(const AInput: string; const AAllocator: TMemAllocator);
    constructor CreateFromView(const AInput: TStringView; const AAllocator: TMemAllocator); inline;
    destructor Destroy; override;
    function Root: TJsonValue;
    function HasError: Boolean;
    function Error: TJsonError;
    procedure RequireStringifiable(const AOperation: string);
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

constructor TJsonDocumentImpl.Create(const AInput: string; const AAllocator: TMemAllocator);
begin
  inherited Create;
  FInputCopy := AInput;
  FDoc.Init(AAllocator);
  FDoc.Parse(TStringView.FromStr(FInputCopy));
end;

constructor TJsonDocumentImpl.CreateFromView(const AInput: TStringView; const AAllocator: TMemAllocator); inline;
begin
  inherited Create;
  // perf: inline + zero-copy TStringView view (no SetString/alloc/copy); bytes.ops single source preserved (view only, no Move)
  // lifecycle: view is non-owning — caller must keep AInput.Data alive for document lifetime (clean strings borrow input)
  FInputCopy := '';
  FDoc.Init(AAllocator);
  FDoc.Parse(AInput);
end;

destructor TJsonDocumentImpl.Destroy;
begin
  FDoc.Done;
  inherited;
end;

function TJsonDocumentImpl.Root: TJsonValue;
begin
  Result := TJsonValue.Create(FDoc, FDoc.Root);
end;

function TJsonDocumentImpl.HasError: Boolean;
begin
  Result := FDoc.HasError;
end;

function TJsonDocumentImpl.Error: TJsonError;
begin
  Result := FDoc.Error;
end;

procedure TJsonDocumentImpl.RequireStringifiable(const AOperation: string);
begin
  if FDoc.HasError then
    raise EInvalidOperationError.Create(
      'TJsonDocument.' + AOperation + ': diagnostic document cannot be stringified');
end;

procedure StringifyNode(var ADoc: TJsonDocument; AIdx: UInt32; var AW: TJsonWriter); forward;

procedure StringifyNode(var ADoc: TJsonDocument; AIdx: UInt32; var AW: TJsonWriter);
var
  LNode, LKeyNode, LValNode: PJsonNode;
  LChild, LValIdx: UInt32;
  I: UInt32;
begin
  if AIdx = JSON_NODE_NONE then
  begin
    AW.Null;
    Exit;
  end;
  LNode := ADoc.Node(AIdx);
  case LNode^.Kind of
    jnkNull: AW.Null;
    jnkBool: AW.Bool(LNode^.BoolVal);
    jnkInt: AW.Int(LNode^.IntVal);
    jnkReal: AW.Float(LNode^.RealVal);
    jnkString:
      if (LNode^.Flags and JNF_CLEAN_STR) <> 0 then
        AW.StrClean(LNode^.Str.Data, LNode^.Str.Len)
      else
        AW.Str(LNode^.Str);
    jnkArray:
    begin
      AW.BeginArray;
      LChild := LNode^.Container.FirstChild;
      for I := 0 to LNode^.Container.Count - 1 do
      begin
        if LChild = JSON_NODE_NONE then Break;
        LValNode := ADoc.Node(LChild);
        case LValNode^.Kind of
          jnkNull: AW.Null;
          jnkBool: AW.Bool(LValNode^.BoolVal);
          jnkInt: AW.Int(LValNode^.IntVal);
          jnkReal: AW.Float(LValNode^.RealVal);
          jnkString:
            if (LValNode^.Flags and JNF_CLEAN_STR) <> 0 then
              AW.StrClean(LValNode^.Str.Data, LValNode^.Str.Len)
            else
              AW.Str(LValNode^.Str);
        else
          StringifyNode(ADoc, LChild, AW);
        end;
        LChild := LValNode^.Next;
      end;
      AW.EndArray;
    end;
    jnkObject:
    begin
      AW.BeginObject;
      LChild := LNode^.Container.FirstChild;
      for I := 0 to LNode^.Container.Count - 1 do
      begin
        if LChild = JSON_NODE_NONE then Break;
        LKeyNode := ADoc.Node(LChild);
        if (LKeyNode^.Flags and JNF_CLEAN_STR) <> 0 then
          AW.KeyClean(LKeyNode^.Str.Data, LKeyNode^.Str.Len)
        else
          AW.Key(LKeyNode^.Str);
        LValIdx := LKeyNode^.Next;
        LValNode := ADoc.Node(LValIdx);
        case LValNode^.Kind of
          jnkNull: AW.Null;
          jnkBool: AW.Bool(LValNode^.BoolVal);
          jnkInt: AW.Int(LValNode^.IntVal);
          jnkReal: AW.Float(LValNode^.RealVal);
          jnkString:
            if (LValNode^.Flags and JNF_CLEAN_STR) <> 0 then
              AW.StrClean(LValNode^.Str.Data, LValNode^.Str.Len)
            else
              AW.Str(LValNode^.Str);
        else
          StringifyNode(ADoc, LValIdx, AW);
        end;
        LChild := LValNode^.Next;
      end;
      AW.EndObject;
    end;
  end;
end;

function TJsonDocumentImpl.Stringify: string;
var
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
begin
  RequireStringifiable('Stringify');
  LBuilder.Init(FDoc.Input.Len + 32);
  try
    LWriter.Init(LBuilder);
    StringifyNode(FDoc, FDoc.Root, LWriter);
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function TJsonDocumentImpl.StringifyPretty(const AIndent: Int32): string;
var
  LBuilder: TStringBuilder;

  procedure WriteIndent(ADepth: Int32);
  begin
    LBuilder.AppendChar(#10);
    if ADepth * AIndent > 0 then
      LBuilder.AppendChars(' ', ADepth * AIndent);
  end;

  procedure WritePrettyNode(AIdx: UInt32; ADepth: Int32);
  var
    LNode: PJsonNode;
    LChild: UInt32;
    I: UInt32;
  begin
    if AIdx = JSON_NODE_NONE then
    begin
      LBuilder.AppendBytes('null', 4);
      Exit;
    end;
    LNode := FDoc.Node(AIdx);
    case LNode^.Kind of
      jnkNull: LBuilder.AppendBytes('null', 4);
      jnkBool:
        if LNode^.BoolVal then LBuilder.AppendBytes('true', 4)
        else LBuilder.AppendBytes('false', 5);
      jnkInt: LBuilder.AppendInt(LNode^.IntVal);
      jnkReal: LBuilder.AppendFloat(LNode^.RealVal);
      jnkString:
      begin
        LBuilder.AppendChar('"');
        JsonEscapeToBuilder(LNode^.Str, LBuilder);
        LBuilder.AppendChar('"');
      end;
      jnkArray:
      begin
        if LNode^.Container.Count = 0 then
        begin
          LBuilder.AppendBytes('[]', 2);
          Exit;
        end;
        LBuilder.AppendChar('[');
        LChild := LNode^.Container.FirstChild;
        for I := 0 to LNode^.Container.Count - 1 do
        begin
          if I > 0 then LBuilder.AppendChar(',');
          WriteIndent(ADepth + 1);
          if LChild = JSON_NODE_NONE then Break;
          WritePrettyNode(LChild, ADepth + 1);
          LChild := FDoc.Node(LChild)^.Next;
        end;
        WriteIndent(ADepth);
        LBuilder.AppendChar(']');
      end;
      jnkObject:
      begin
        if LNode^.Container.Count = 0 then
        begin
          LBuilder.AppendBytes('{}', 2);
          Exit;
        end;
        LBuilder.AppendChar('{');
        LChild := LNode^.Container.FirstChild;
        for I := 0 to LNode^.Container.Count - 1 do
        begin
          if I > 0 then LBuilder.AppendChar(',');
          WriteIndent(ADepth + 1);
          if LChild = JSON_NODE_NONE then Break;
          LBuilder.AppendChar('"');
          JsonEscapeToBuilder(FDoc.Node(LChild)^.Str, LBuilder);
          LBuilder.AppendBytes('": ', 3);
          WritePrettyNode(FDoc.Node(LChild)^.Next, ADepth + 1);
          LChild := FDoc.Node(FDoc.Node(LChild)^.Next)^.Next;
        end;
        WriteIndent(ADepth);
        LBuilder.AppendChar('}');
      end;
    end;
  end;

begin
  RequireStringifiable('StringifyPretty');
  LBuilder.Init(512);
  try
    WritePrettyNode(FDoc.Root, 0);
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function JsonParse(const AInput: string): IJsonDocument;
begin
  Result := TJsonDocumentImpl.Create(AInput, DefaultAllocator);
end;

function JsonParse(const AInput: TStringView): IJsonDocument;
begin
  Result := TJsonDocumentImpl.CreateFromView(AInput, DefaultAllocator);
end;

function TryJsonParse(const AInput: string; out ADoc: IJsonDocument): Boolean;
begin
  ADoc := JsonParse(AInput);
  Result := not ADoc.HasError;
end;

function JsonParse(const AReader: IReader): IJsonDocument;
var
  LStr: string;
  LLen, LCap, LRead: SizeUInt;
  LBuf: array[0..32767] of Byte;
begin
  if AReader = nil then
    raise EArgumentError.Create('JsonParse: reader must not be nil');
  // perf: single string alloc via bytes.ops BytesGrowCapacity (single source, exponential amortized O(1))
  // zero-copy: Move(PAnsiChar(LStr)[LLen]) + TStringView.FromStr share (Create does FInputCopy:=AInput refcount share, no BytesToString copy)
  // stability: SetLength exception-safe (no manual FreeMem), final SetLength(LLen) trims capacity exactly; avoids TBytes+LStr double peak 2x
  // not inline per red-line 2: loop+I-Cache, capacity math delegates to bytes.ops single source
  LStr := '';
  LLen := 0;
  LCap := 0;
  repeat
    LRead := AReader.Read(LBuf[0], SizeOf(LBuf));
    if LRead = 0 then
      Break;
    if LLen + LRead > LCap then
    begin
      if LCap = 0 then
        LCap := SizeUInt(Length(LBuf))
      else
        LCap := BytesGrowCapacity(LCap, LLen + LRead);
      if LCap < LLen + LRead then
        LCap := LLen + LRead;
      SetLength(LStr, LCap);
    end;
    if LRead > 0 then
      Move(LBuf[0], (PAnsiChar(LStr) + LLen)^, LRead);
    Inc(LLen, LRead);
    if LLen > FORMAT_BULK_PARSE_MAX_BYTES then
      RequireFormatBulkByteCount(LLen, 'JsonParse');
  until False;
  SetLength(LStr, LLen);
  RequireFormatBulkByteCount(SizeUInt(Length(LStr)), 'JsonParse');
  Result := JsonParse(LStr);
end;

function TryJsonParse(const AReader: IReader; out ADoc: IJsonDocument): Boolean;
begin
  ADoc := nil;
  if AReader = nil then
    Exit(False);
  try
    ADoc := JsonParse(AReader);
    Result := not ADoc.HasError;
  except
    ADoc := nil;
    Result := False;
  end;
end;

function JsonParseWith(const AInput: string; const AAllocator: TMemAllocator): IJsonDocument;
begin
  Result := TJsonDocumentImpl.Create(AInput, AAllocator);
end;

function JsonParseWith(const AInput: TStringView; const AAllocator: TMemAllocator): IJsonDocument;
begin
  Result := TJsonDocumentImpl.CreateFromView(AInput, AAllocator);
end;

function JsonStringify(const AValue: TJsonValue): string;
var
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
begin
  if (AValue.FDoc <> nil) and PJsonDocument(AValue.FDoc)^.HasError then
    raise EInvalidOperationError.Create(
      'JsonStringify: diagnostic document cannot be stringified');

  LBuilder.Init(256);
  try
    LWriter.Init(LBuilder);
    StringifyNode(PJsonDocument(AValue.FDoc)^, AValue.FIdx, LWriter);
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function JsonIntField(const AValue: TJsonValue; const AKey: string;
  ADefault: Int64): Int64;
var
  LField: TJsonValue;
begin
  Result := ADefault;
  if not AValue.IsObject then
    Exit;
  LField := AValue.Get(AKey);
  if LField.IsInt or LField.IsReal then
    Result := LField.AsInt;
end;

function JsonFloatField(const AValue: TJsonValue; const AKey: string;
  ADefault: Double): Double;
var
  LField: TJsonValue;
begin
  Result := ADefault;
  if not AValue.IsObject then
    Exit;
  LField := AValue.Get(AKey);
  if LField.IsInt or LField.IsReal then
    Result := LField.AsFloat;
end;

function JsonStrField(const AValue: TJsonValue; const AKey: string;
  const ADefault: string): string;
var
  LField: TJsonValue;
begin
  Result := ADefault;
  if not AValue.IsObject then
    Exit;
  LField := AValue.Get(AKey);
  if LField.IsStr then
    Result := LField.AsStr.ToString;
end;

function JsonBoolField(const AValue: TJsonValue; const AKey: string;
  ADefault: Boolean): Boolean;
var
  LField: TJsonValue;
begin
  Result := ADefault;
  if not AValue.IsObject then
    Exit;
  LField := AValue.Get(AKey);
  if LField.IsBool then
    Result := LField.AsBool;
end;

end.
