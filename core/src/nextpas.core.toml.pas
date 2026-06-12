unit nextpas.core.toml;
{**
 * @desc TOML 门面：解析、序列化、DOM 访问。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.intf,
  nextpas.core.toml.base,
  nextpas.core.toml.parser,
  nextpas.core.toml.value,
  nextpas.core.toml.writer,
  nextpas.core.toml.builder;

type
  TTomlNodeKind = nextpas.core.toml.base.TTomlNodeKind;
  TTomlDateTimeKind = nextpas.core.toml.base.TTomlDateTimeKind;
  TTomlDateTime = nextpas.core.toml.base.TTomlDateTime;
  TTomlError = nextpas.core.toml.base.TTomlError;
  TTomlValue = nextpas.core.toml.value.TTomlValue;
  TTomlValueEnumerator = nextpas.core.toml.value.TTomlValueEnumerator;
  ITomlBuilder = nextpas.core.toml.builder.ITomlBuilder;

  ITomlDocument = interface
    ['{D4E5F6A7-B8C9-0123-DEFA-456789012345}']
    function Root: TTomlValue;
    function HasError: Boolean;
    function Error: TTomlError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32): string;
  end;

function TomlParse(const AInput: string): ITomlDocument; overload;
function TomlParse(const AInput: TStringView): ITomlDocument; overload;
function TryTomlParse(const AInput: string; out ADoc: ITomlDocument): Boolean;
function TomlParseWith(const AInput: string; const AAllocator: IAllocator): ITomlDocument; overload;
function TomlParseWith(const AInput: TStringView; const AAllocator: IAllocator): ITomlDocument; overload;
function TomlBuilder: ITomlBuilder; overload; inline;
function TomlBuilder(const AInitialCap: SizeUInt): ITomlBuilder; overload; inline;
function TomlDateTime(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32): TTomlDateTime; inline;
function TomlDateTimeWithOffset(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32; AOffsetMinutes: Int16): TTomlDateTime; inline;
function TomlDate(AYear: UInt16; AMonth, ADay: Byte): TTomlDateTime; inline;
function TomlTime(AHour, AMinute, ASecond: Byte; ANanosecond: UInt32): TTomlDateTime; inline;
function TomlEnumerate(const AValue: TTomlValue): TTomlValueEnumerator; inline;

implementation

uses
  nextpas.core.errors,
  nextpas.core.mem.default;

const
  TOML_STRINGIFY_MAX_PATH_SEGMENTS = 128;

type
  TTomlDocumentImpl = class(TInterfacedObject, ITomlDocument)
  private
    FDoc: TTomlDocument;
    FInputCopy: string;
    procedure RequireStringifiable(const AOperation: string);
  public
    constructor Create(const AInput: string; const AAllocator: IAllocator);
    constructor CreateFromView(const AInput: TStringView; const AAllocator: IAllocator);
    destructor Destroy; override;
    function Root: TTomlValue;
    function HasError: Boolean;
    function Error: TTomlError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32): string;
  end;

constructor TTomlDocumentImpl.Create(const AInput: string; const AAllocator: IAllocator);
begin
  inherited Create;
  FInputCopy := AInput;
  FDoc.Init(AAllocator);
  FDoc.Parse(TStringView.FromStr(FInputCopy));
end;

constructor TTomlDocumentImpl.CreateFromView(const AInput: TStringView; const AAllocator: IAllocator);
begin
  inherited Create;
  SetString(FInputCopy, AInput.Data, AInput.Len);
  FDoc.Init(AAllocator);
  FDoc.Parse(TStringView.FromStr(FInputCopy));
end;

destructor TTomlDocumentImpl.Destroy;
begin
  FDoc.Done;
  inherited;
end;

function TTomlDocumentImpl.Root: TTomlValue;
begin
  Result := TTomlValue.Create(FDoc, FDoc.Root);
end;

function TTomlDocumentImpl.HasError: Boolean;
begin
  Result := FDoc.HasError;
end;

function TTomlDocumentImpl.Error: TTomlError;
begin
  Result := FDoc.Error;
end;

procedure TTomlDocumentImpl.RequireStringifiable(const AOperation: string);
begin
  if FDoc.HasError then
    raise EInvalidOperationError.Create(
      'TTomlDocument.' + AOperation + ': diagnostic document cannot be stringified');
end;

procedure StringifyValue(var ADoc: TTomlDocument; AIdx: UInt32; var AW: TTomlWriter; ATopLevel: Boolean); forward;

function IsArrayTable(var ADoc: TTomlDocument; AIdx: UInt32): Boolean;
begin
  Result := (ADoc.Node(AIdx)^.Kind = tnkArray) and
    ((ADoc.Node(AIdx)^.Flags and TOML_NODE_FLAG_ARRAY_TABLE) <> 0);
end;

type
  TPathSegments = record
    Segs: array[0..TOML_STRINGIFY_MAX_PATH_SEGMENTS - 1] of TStringView;
    Count: Int32;
  end;

procedure PushPathSegment(var APath: TPathSegments; const AKey: TStringView);
begin
  if APath.Count >= TOML_STRINGIFY_MAX_PATH_SEGMENTS then
    raise EResourceExhaustedError.Create(
      'TTomlDocument: table path stack limit exceeded');
  APath.Segs[APath.Count] := AKey;
  Inc(APath.Count);
end;

function IsBareKeyView(const AView: TStringView): Boolean;
var
  LI: SizeUInt;
  LCh: Byte;
begin
  if AView.Len = 0 then Exit(False);
  for LI := 0 to AView.Len - 1 do
  begin
    LCh := Byte(AView.Data[LI]);
    if not (((LCh >= Ord('A')) and (LCh <= Ord('Z')))
      or ((LCh >= Ord('a')) and (LCh <= Ord('z')))
      or ((LCh >= Ord('0')) and (LCh <= Ord('9')))
      or (LCh = Ord('-')) or (LCh = Ord('_'))) then
      Exit(False);
  end;
  Result := True;
end;

procedure WriteTableHeader(var AW: TTomlWriter; var APath: TPathSegments; AIsArray: Boolean);
var
  LI: Int32;
  LJ: SizeUInt;
  LBuilder: TStringBuilder;
  LCh: Byte;
begin
  LBuilder.Init(64);
  try
    for LI := 0 to APath.Count - 1 do
    begin
      if LI > 0 then LBuilder.AppendChar('.');
      if IsBareKeyView(APath.Segs[LI]) then
        LBuilder.AppendBytes(APath.Segs[LI].Data, APath.Segs[LI].Len)
      else
      begin
        LBuilder.AppendChar('"');
        if APath.Segs[LI].Len > 0 then
        for LJ := 0 to APath.Segs[LI].Len - 1 do
        begin
          LCh := Byte(APath.Segs[LI].Data[LJ]);
          case LCh of
            Ord('"'): LBuilder.AppendBytes('\"', 2);
            Ord('\'): LBuilder.AppendBytes('\\', 2);
            8: LBuilder.AppendBytes('\b', 2);
            9: LBuilder.AppendBytes('\t', 2);
            10: LBuilder.AppendBytes('\n', 2);
            12: LBuilder.AppendBytes('\f', 2);
            13: LBuilder.AppendBytes('\r', 2);
          else
            if LCh < 32 then
            begin
              LBuilder.AppendBytes('\u00', 4);
              LBuilder.AppendChar(AnsiChar(Ord('0') + (LCh shr 4)));
              if (LCh and $F) < 10 then
                LBuilder.AppendChar(AnsiChar(Ord('0') + (LCh and $F)))
              else
                LBuilder.AppendChar(AnsiChar(Ord('a') + (LCh and $F) - 10));
            end
            else
              LBuilder.AppendChar(AnsiChar(LCh));
          end;
        end;
        LBuilder.AppendChar('"');
      end;
    end;
    if AIsArray then
      AW.BeginArrayTableRaw(LBuilder.ToString)
    else
      AW.BeginTableRaw(LBuilder.ToString);
  finally
    LBuilder.Done;
  end;
end;

procedure StringifyTable(var ADoc: TTomlDocument; AIdx: UInt32; var AW: TTomlWriter; var APath: TPathSegments); forward;

procedure StringifyTable(var ADoc: TTomlDocument; AIdx: UInt32; var AW: TTomlWriter; var APath: TPathSegments);
var
  LCur: UInt32;
  LNode: PTomlNode;
  LArrayChild: UInt32;
begin
  LCur := ADoc.Node(AIdx)^.Container.FirstChild;
  while LCur <> TOML_NODE_NONE do
  begin
    LNode := ADoc.Node(LCur);
    if (LNode^.Kind <> tnkTable) and not IsArrayTable(ADoc, LCur) then
    begin
      AW.Key(LNode^.Key);
      StringifyValue(ADoc, LCur, AW, False);
    end;
    LCur := LNode^.Next;
  end;
  LCur := ADoc.Node(AIdx)^.Container.FirstChild;
  while LCur <> TOML_NODE_NONE do
  begin
    LNode := ADoc.Node(LCur);
    if LNode^.Kind = tnkTable then
    begin
      PushPathSegment(APath, LNode^.Key);
      try
        WriteTableHeader(AW, APath, False);
        StringifyTable(ADoc, LCur, AW, APath);
      finally
        Dec(APath.Count);
      end;
    end
    else if IsArrayTable(ADoc, LCur) then
    begin
      PushPathSegment(APath, LNode^.Key);
      try
        LArrayChild := LNode^.Container.FirstChild;
        while LArrayChild <> TOML_NODE_NONE do
        begin
          WriteTableHeader(AW, APath, True);
          StringifyTable(ADoc, LArrayChild, AW, APath);
          LArrayChild := ADoc.Node(LArrayChild)^.Next;
        end;
      finally
        Dec(APath.Count);
      end;
    end;
    LCur := LNode^.Next;
  end;
end;

procedure StringifyValue(var ADoc: TTomlDocument; AIdx: UInt32; var AW: TTomlWriter; ATopLevel: Boolean);
var
  LNode: PTomlNode;
  LCur: UInt32;
begin
  if AIdx = TOML_NODE_NONE then Exit;
  LNode := ADoc.Node(AIdx);
  case LNode^.Kind of
    tnkString: AW.Str(LNode^.Str);
    tnkInt: AW.Int(LNode^.IntVal);
    tnkFloat: AW.Float(LNode^.FloatVal);
    tnkBool: AW.Bool(LNode^.BoolVal);
    tnkDateTime: AW.DateTime(LNode^.DT);
    tnkArray:
    begin
      AW.BeginArray;
      LCur := LNode^.Container.FirstChild;
      while LCur <> TOML_NODE_NONE do
      begin
        StringifyValue(ADoc, LCur, AW, False);
        LCur := ADoc.Node(LCur)^.Next;
      end;
      AW.EndArray;
    end;
    tnkTable:
    begin
      AW.BeginInlineTable;
      LCur := LNode^.Container.FirstChild;
      while LCur <> TOML_NODE_NONE do
      begin
        AW.Key(ADoc.Node(LCur)^.Key);
        StringifyValue(ADoc, LCur, AW, False);
        LCur := ADoc.Node(LCur)^.Next;
      end;
      AW.EndInlineTable;
    end;
  end;
end;

function TTomlDocumentImpl.Stringify: string;
var
  LBuilder: TStringBuilder;
  LWriter: TTomlWriter;
  LPath: TPathSegments;
begin
  RequireStringifiable('Stringify');
  LBuilder.Init(256);
  try
    LWriter.Init(LBuilder);
    LPath.Count := 0;
    StringifyTable(FDoc, FDoc.Root, LWriter, LPath);
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function TTomlDocumentImpl.StringifyPretty(const AIndent: Int32): string;
var
  LBuilder: TStringBuilder;
  LWriter: TTomlWriter;
  LPath: TPathSegments;
begin
  RequireStringifiable('StringifyPretty');
  LBuilder.Init(256);
  try
    LWriter.InitPretty(LBuilder, AIndent);
    LPath.Count := 0;
    StringifyTable(FDoc, FDoc.Root, LWriter, LPath);
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function TomlParse(const AInput: string): ITomlDocument;
begin
  Result := TTomlDocumentImpl.Create(AInput, DefaultAllocator);
end;

function TomlParse(const AInput: TStringView): ITomlDocument;
begin
  Result := TTomlDocumentImpl.CreateFromView(AInput, DefaultAllocator);
end;

function TryTomlParse(const AInput: string; out ADoc: ITomlDocument): Boolean;
begin
  ADoc := TomlParse(AInput);
  Result := not ADoc.HasError;
end;

function TomlParseWith(const AInput: string; const AAllocator: IAllocator): ITomlDocument;
begin
  Result := TTomlDocumentImpl.Create(AInput, AAllocator);
end;

function TomlParseWith(const AInput: TStringView; const AAllocator: IAllocator): ITomlDocument;
begin
  Result := TTomlDocumentImpl.CreateFromView(AInput, AAllocator);
end;

function TomlBuilder: ITomlBuilder;
begin
  Result := nextpas.core.toml.builder.TomlBuilder;
end;

function TomlBuilder(const AInitialCap: SizeUInt): ITomlBuilder;
begin
  Result := nextpas.core.toml.builder.TomlBuilder(AInitialCap);
end;

function TomlDateTime(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32): TTomlDateTime;
begin
  Result := nextpas.core.toml.base.TomlDateTime(
    AYear, AMonth, ADay, AHour, AMinute, ASecond, ANanosecond);
end;

function TomlDateTimeWithOffset(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32; AOffsetMinutes: Int16): TTomlDateTime;
begin
  Result := nextpas.core.toml.base.TomlDateTimeWithOffset(
    AYear, AMonth, ADay, AHour, AMinute, ASecond, ANanosecond, AOffsetMinutes);
end;

function TomlDate(AYear: UInt16; AMonth, ADay: Byte): TTomlDateTime;
begin
  Result := nextpas.core.toml.base.TomlDate(AYear, AMonth, ADay);
end;

function TomlTime(AHour, AMinute, ASecond: Byte; ANanosecond: UInt32): TTomlDateTime;
begin
  Result := nextpas.core.toml.base.TomlTime(AHour, AMinute, ASecond, ANanosecond);
end;

function TomlEnumerate(const AValue: TTomlValue): TTomlValueEnumerator;
begin
  Result := nextpas.core.toml.value.TomlEnumerate(AValue);
end;

end.
