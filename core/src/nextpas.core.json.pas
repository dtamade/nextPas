unit nextpas.core.json;
{ High-level JSON facade with automatic lifetime management.
  Parse JSON into IJsonDocument (refcounted, auto-released).
  Access values via TJsonValue (zero-cost record view).

  Usage:
    var Doc: IJsonDocument;
    Doc := JsonParse('{"name":"Alice","age":30}');
    WriteLn(Doc.Root.ObjectGet('name').AsStr.ToString);
    // auto-released when Doc goes out of scope
}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.intf,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.json.writer;

type
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

{ Parse with custom allocator (arena/pool for bulk allocation). }
function JsonParseWith(const AInput: string; const AAllocator: IAllocator): IJsonDocument; overload;
function JsonParseWith(const AInput: TStringView; const AAllocator: IAllocator): IJsonDocument; overload;

{ Serialize a TJsonValue subtree to compact JSON string. }
function JsonStringify(const AValue: TJsonValue): string;

implementation

uses
  nextpas.core.mem.default,
  nextpas.core.text.escape;

type
  TJsonDocumentImpl = class(TInterfacedObject, IJsonDocument)
  private
    FDoc: TJsonDocument;
    FInputCopy: string;
  public
    constructor Create(const AInput: string; const AAllocator: IAllocator);
    constructor CreateFromView(const AInput: TStringView; const AAllocator: IAllocator);
    destructor Destroy; override;
    function Root: TJsonValue;
    function HasError: Boolean;
    function Error: TJsonError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

constructor TJsonDocumentImpl.Create(const AInput: string; const AAllocator: IAllocator);
begin
  inherited Create;
  FInputCopy := AInput;
  FDoc.Init(AAllocator);
  FDoc.Parse(TStringView.FromStr(FInputCopy));
end;

constructor TJsonDocumentImpl.CreateFromView(const AInput: TStringView; const AAllocator: IAllocator);
begin
  inherited Create;
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

procedure StringifyNode(var ADoc: TJsonDocument; AIdx: UInt32; var AW: TJsonWriter); forward;

procedure StringifyNode(var ADoc: TJsonDocument; AIdx: UInt32; var AW: TJsonWriter);
var
  LNode: PJsonNode;
  LChild: UInt32;
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
    jnkString: AW.Str(LNode^.Str);
    jnkArray:
    begin
      AW.BeginArray;
      LChild := LNode^.Container.FirstChild;
      for I := 0 to LNode^.Container.Count - 1 do
      begin
        if LChild = JSON_NODE_NONE then Break;
        StringifyNode(ADoc, LChild, AW);
        LChild := ADoc.Node(LChild)^.Next;
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
        AW.Key(ADoc.Node(LChild)^.Str);
        StringifyNode(ADoc, ADoc.Node(LChild)^.Next, AW);
        LChild := ADoc.Node(ADoc.Node(LChild)^.Next)^.Next;
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
  LBuilder.Init(256);
  LWriter.Init(LBuilder);
  StringifyNode(FDoc, FDoc.Root, LWriter);
  Result := LBuilder.ToString;
  LBuilder.Done;
end;

function TJsonDocumentImpl.StringifyPretty(const AIndent: Int32): string;
var
  LBuilder: TStringBuilder;

  procedure WriteIndent(ADepth: Int32);
  var J: Int32;
  begin
    LBuilder.AppendChar(#10);
    for J := 1 to ADepth * AIndent do
      LBuilder.AppendChar(' ');
  end;

  procedure WritePrettyNode(AIdx: UInt32; ADepth: Int32);
  var
    LNode: PJsonNode;
    LChild: UInt32;
    I: UInt32;
    LBuf: array[0..31] of AnsiChar;
    LN: Int32;
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
  LBuilder.Init(512);
  WritePrettyNode(FDoc.Root, 0);
  Result := LBuilder.ToString;
  LBuilder.Done;
end;

function JsonParse(const AInput: string): IJsonDocument;
begin
  Result := TJsonDocumentImpl.Create(AInput, DefaultAllocator);
end;

function JsonParse(const AInput: TStringView): IJsonDocument;
begin
  Result := TJsonDocumentImpl.CreateFromView(AInput, DefaultAllocator);
end;

function JsonParseWith(const AInput: string; const AAllocator: IAllocator): IJsonDocument;
begin
  Result := TJsonDocumentImpl.Create(AInput, AAllocator);
end;

function JsonParseWith(const AInput: TStringView; const AAllocator: IAllocator): IJsonDocument;
begin
  Result := TJsonDocumentImpl.CreateFromView(AInput, AAllocator);
end;

function JsonStringify(const AValue: TJsonValue): string;
var
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
begin
  LBuilder.Init(256);
  LWriter.Init(LBuilder);
  StringifyNode(AValue.FDoc^, AValue.FIdx, LWriter);
  Result := LBuilder.ToString;
  LBuilder.Done;
end;

end.
