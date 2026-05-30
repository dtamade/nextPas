unit nextpas.core.toml;

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
  ITomlDocument = interface
    ['{D4E5F6A7-B8C9-0123-DEFA-456789012345}']
    function Root: TTomlValue;
    function HasError: Boolean;
    function Error: TTomlError;
    function Stringify: string;
  end;

function TomlParse(const AInput: string): ITomlDocument; overload;
function TomlParse(const AInput: TStringView): ITomlDocument; overload;
function TomlParseWith(const AInput: string; const AAllocator: IAllocator): ITomlDocument; overload;

implementation

uses
  nextpas.core.mem.default;

type
  TTomlDocumentImpl = class(TInterfacedObject, ITomlDocument)
  private
    FDoc: TTomlDocument;
    FInputCopy: string;
  public
    constructor Create(const AInput: string; const AAllocator: IAllocator);
    constructor CreateFromView(const AInput: TStringView; const AAllocator: IAllocator);
    destructor Destroy; override;
    function Root: TTomlValue;
    function HasError: Boolean;
    function Error: TTomlError;
    function Stringify: string;
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

procedure StringifyValue(var ADoc: TTomlDocument; AIdx: UInt32; var AW: TTomlWriter; ATopLevel: Boolean); forward;

procedure StringifyTable(var ADoc: TTomlDocument; AIdx: UInt32; var AW: TTomlWriter; const APath: string);
var
  LCur: UInt32;
  LNode: PTomlNode;
  LChildPath: string;
begin
  LCur := ADoc.Node(AIdx)^.Container.FirstChild;
  while LCur <> TOML_NODE_NONE do
  begin
    LNode := ADoc.Node(LCur);
    if (LNode^.Kind <> tnkTable) and (LNode^.Kind <> tnkArray) then
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
      if APath = '' then
        LChildPath := LNode^.Key.ToString
      else
        LChildPath := APath + '.' + LNode^.Key.ToString;
      AW.BeginTable(LChildPath);
      StringifyTable(ADoc, LCur, AW, LChildPath);
    end
    else if LNode^.Kind = tnkArray then
    begin
      if APath = '' then
        LChildPath := LNode^.Key.ToString
      else
        LChildPath := APath + '.' + LNode^.Key.ToString;
      StringifyValue(ADoc, LCur, AW, True);
    end;
    LCur := LNode^.Next;
  end;
end;

procedure StringifyValue(var ADoc: TTomlDocument; AIdx: UInt32; var AW: TTomlWriter; ATopLevel: Boolean);
var
  LNode: PTomlNode;
  LCur: UInt32;
  LFirst: Boolean;
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
      LFirst := True;
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
begin
  LBuilder.Init(256);
  LWriter.Init(LBuilder);
  StringifyTable(FDoc, FDoc.Root, LWriter, '');
  Result := LBuilder.ToString;
  LBuilder.Done;
end;

function TomlParse(const AInput: string): ITomlDocument;
begin
  Result := TTomlDocumentImpl.Create(AInput, DefaultAllocator);
end;

function TomlParse(const AInput: TStringView): ITomlDocument;
begin
  Result := TTomlDocumentImpl.CreateFromView(AInput, DefaultAllocator);
end;

function TomlParseWith(const AInput: string; const AAllocator: IAllocator): ITomlDocument;
begin
  Result := TTomlDocumentImpl.Create(AInput, AAllocator);
end;

end.
