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
  TJsonValue = nextpas.core.json.value.TJsonValue;

  { Parsed JSON document with automatic lifetime management.
    All values remain valid as long as the document is alive. }
  IJsonDocument = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function Root: TJsonValue;
    function HasError: Boolean;
    function Error: TJsonError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

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
  nextpas.core.mem.default,
  nextpas.core.errors,
  nextpas.core.format.limits,
  nextpas.core.io.util,
  nextpas.core.text.escape;

function JsonBytesToString(const ABytes: TBytes): string;
begin
  if Length(ABytes) = 0 then
    Exit('');
  SetString(Result, PAnsiChar(@ABytes[0]), Length(ABytes));
end;

type
  TJsonDocumentImpl = class(TInterfacedObject, IJsonDocument)
  private
    FDoc: TJsonDocument;
    FInputCopy: string;
  public
    constructor Create(const AInput: string; const AAllocator: TMemAllocator);
    constructor CreateFromView(const AInput: TStringView; const AAllocator: TMemAllocator);
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

constructor TJsonDocumentImpl.CreateFromView(const AInput: TStringView; const AAllocator: TMemAllocator);
begin
  inherited Create;
  // perf/lifecycle: TStringView is non-owning; zero-copy (FInputCopy := view) would
  // avoid SetString copy but requires caller to keep view.Data alive for document
  // lifetime. To preserve ownership and keep DOM valid after caller buffer is freed,
  // we copy into FInputCopy. If caller can guarantee lifetime, replace with direct
  // view assignment and skip this allocation.
  SetString(FInputCopy, AInput.Data, AInput.Len);
  FDoc.Init(AAllocator);
  FDoc.Parse(TStringView.FromStr(FInputCopy));
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
  LBytes: TBytes;
begin
  if AReader = nil then
    raise EArgumentError.Create('JsonParse: reader must not be nil');
  LBytes := IoReadAll(AReader);
  RequireFormatBulkByteCount(SizeUInt(Length(LBytes)), 'JsonParse');
  Result := JsonParse(JsonBytesToString(LBytes));
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
  if (AValue.FDoc <> nil) and AValue.FDoc^.HasError then
    raise EInvalidOperationError.Create(
      'JsonStringify: diagnostic document cannot be stringified');

  LBuilder.Init(256);
  try
    LWriter.Init(LBuilder);
    StringifyNode(AValue.FDoc^, AValue.FIdx, LWriter);
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
