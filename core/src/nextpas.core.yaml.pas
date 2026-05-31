unit nextpas.core.yaml;
{**
 * @desc YAML 门面：解析、序列化、DOM 访问。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml.parser,
  nextpas.core.yaml.value,
  nextpas.core.yaml.writer;

type
  TYamlNodeKind = nextpas.core.yaml.types.TYamlNodeKind;
  TYamlValue = nextpas.core.yaml.value.TYamlValue;

  IYamlDocument = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EA0100000001}']
    function Root: TYamlValue;
    function HasError: Boolean;
    function Error: TYamlError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

function YamlParse(const AInput: string): IYamlDocument; overload;
function YamlParse(const AInput: TStringView): IYamlDocument; overload;

implementation

type
  TYamlDocumentImpl = class(TInterfacedObject, IYamlDocument)
  private
    FDoc: TYamlDocument;
    FInput: string;
  public
    constructor Create(const AInput: string);
    constructor CreateFromView(const AView: TStringView);
    function Root: TYamlValue;
    function HasError: Boolean;
    function Error: TYamlError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

constructor TYamlDocumentImpl.Create(const AInput: string);
begin
  inherited Create;
  FInput := AInput;
  if Length(FInput) > 0 then
    YamlDocParse(FDoc, @FInput[1], Length(FInput))
  else
    YamlDocParse(FDoc, nil, 0);
end;

constructor TYamlDocumentImpl.CreateFromView(const AView: TStringView);
begin
  inherited Create;
  FInput := AView.ToString;
  if Length(FInput) > 0 then
    YamlDocParse(FDoc, @FInput[1], Length(FInput))
  else
    YamlDocParse(FDoc, nil, 0);
end;

function TYamlDocumentImpl.Root: TYamlValue;
begin
  Result := TYamlValue.Create(FDoc, FDoc.RootIdx);
end;

function TYamlDocumentImpl.HasError: Boolean;
begin
  Result := FDoc.HasError;
end;

function TYamlDocumentImpl.Error: TYamlError;
begin
  Result := FDoc.Error;
end;

function TYamlDocumentImpl.Stringify: string;
begin
  Result := YamlStringify(FDoc, FDoc.RootIdx);
end;

function TYamlDocumentImpl.StringifyPretty(const AIndent: Int32): string;
begin
  Result := YamlStringifyPretty(FDoc, FDoc.RootIdx, AIndent);
end;

function YamlParse(const AInput: string): IYamlDocument;
begin
  Result := TYamlDocumentImpl.Create(AInput);
end;

function YamlParse(const AInput: TStringView): IYamlDocument;
begin
  Result := TYamlDocumentImpl.CreateFromView(AInput);
end;

end.
