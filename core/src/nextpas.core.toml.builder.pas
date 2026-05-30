unit nextpas.core.toml.builder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.toml.base,
  nextpas.core.toml.writer;

type
  ITomlBuilder = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-345678901234}']
    procedure BeginTable(const AKey: string);
    procedure BeginArrayTable(const AKey: string);
    procedure Key(const AKey: string);
    procedure Str(const AValue: string);
    procedure Int(const AValue: Int64);
    procedure Float(const AValue: Double);
    procedure Bool(const AValue: Boolean);
    procedure DateTime(const AValue: TTomlDateTime);
    procedure BeginInlineTable;
    procedure EndInlineTable;
    procedure BeginArray;
    procedure EndArray;
    procedure Comment(const AText: string);
    procedure Newline;
    function ToString: string;
    function AsView: TStringView;
    function Len: SizeUInt;
  end;

function TomlBuilder: ITomlBuilder; overload;
function TomlBuilder(const AInitialCap: SizeUInt): ITomlBuilder; overload;

implementation

type
  TTomlBuilderImpl = class(TInterfacedObject, ITomlBuilder)
  private
    FBuilder: TStringBuilder;
    FWriter: TTomlWriter;
  public
    constructor Create(const AInitialCap: SizeUInt);
    destructor Destroy; override;
    procedure BeginTable(const AKey: string);
    procedure BeginArrayTable(const AKey: string);
    procedure Key(const AKey: string);
    procedure Str(const AValue: string);
    procedure Int(const AValue: Int64);
    procedure Float(const AValue: Double);
    procedure Bool(const AValue: Boolean);
    procedure DateTime(const AValue: TTomlDateTime);
    procedure BeginInlineTable;
    procedure EndInlineTable;
    procedure BeginArray;
    procedure EndArray;
    procedure Comment(const AText: string);
    procedure Newline;
    function ToString: string; override;
    function AsView: TStringView;
    function Len: SizeUInt;
  end;

constructor TTomlBuilderImpl.Create(const AInitialCap: SizeUInt);
begin
  inherited Create;
  FBuilder.Init(AInitialCap);
  FWriter.Init(FBuilder);
end;

destructor TTomlBuilderImpl.Destroy;
begin
  FBuilder.Done;
  inherited;
end;

procedure TTomlBuilderImpl.BeginTable(const AKey: string);
begin FWriter.BeginTable(AKey); end;

procedure TTomlBuilderImpl.BeginArrayTable(const AKey: string);
begin FWriter.BeginArrayTable(AKey); end;

procedure TTomlBuilderImpl.Key(const AKey: string);
begin FWriter.Key(AKey); end;

procedure TTomlBuilderImpl.Str(const AValue: string);
begin FWriter.Str(AValue); end;

procedure TTomlBuilderImpl.Int(const AValue: Int64);
begin FWriter.Int(AValue); end;

procedure TTomlBuilderImpl.Float(const AValue: Double);
begin FWriter.Float(AValue); end;

procedure TTomlBuilderImpl.Bool(const AValue: Boolean);
begin FWriter.Bool(AValue); end;

procedure TTomlBuilderImpl.DateTime(const AValue: TTomlDateTime);
begin FWriter.DateTime(AValue); end;

procedure TTomlBuilderImpl.BeginInlineTable;
begin FWriter.BeginInlineTable; end;

procedure TTomlBuilderImpl.EndInlineTable;
begin FWriter.EndInlineTable; end;

procedure TTomlBuilderImpl.BeginArray;
begin FWriter.BeginArray; end;

procedure TTomlBuilderImpl.EndArray;
begin FWriter.EndArray; end;

procedure TTomlBuilderImpl.Comment(const AText: string);
begin FWriter.Comment(AText); end;

procedure TTomlBuilderImpl.Newline;
begin FWriter.Newline; end;

function TTomlBuilderImpl.ToString: string;
begin Result := FBuilder.ToString; end;

function TTomlBuilderImpl.AsView: TStringView;
begin Result := FBuilder.AsView; end;

function TTomlBuilderImpl.Len: SizeUInt;
begin Result := FBuilder.Len; end;

function TomlBuilder: ITomlBuilder;
begin
  Result := TTomlBuilderImpl.Create(256);
end;

function TomlBuilder(const AInitialCap: SizeUInt): ITomlBuilder;
begin
  Result := TTomlBuilderImpl.Create(AInitialCap);
end;

end.
