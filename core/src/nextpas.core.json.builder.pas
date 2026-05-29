unit nextpas.core.json.builder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.json.writer;

type
  IJsonBuilder = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']
    procedure BeginObject;
    procedure EndObject;
    procedure BeginArray;
    procedure EndArray;
    procedure Key(const AKey: string);
    procedure Null;
    procedure Bool(const AValue: Boolean);
    procedure Int(const AValue: Int64);
    procedure UInt(const AValue: UInt64);
    procedure Float(const AValue: Double);
    procedure Str(const AValue: string);
    procedure RawJson(const AJson: string);
    function ToString: string;
    function AsView: TStringView;
    function Len: SizeUInt;
  end;

function JsonBuilder: IJsonBuilder; overload;
function JsonBuilder(const AInitialCap: SizeUInt): IJsonBuilder; overload;

implementation

type
  TJsonBuilderImpl = class(TInterfacedObject, IJsonBuilder)
  private
    FBuilder: TStringBuilder;
    FWriter: TJsonWriter;
  public
    constructor Create(const AInitialCap: SizeUInt);
    destructor Destroy; override;
    procedure BeginObject;
    procedure EndObject;
    procedure BeginArray;
    procedure EndArray;
    procedure Key(const AKey: string);
    procedure Null;
    procedure Bool(const AValue: Boolean);
    procedure Int(const AValue: Int64);
    procedure UInt(const AValue: UInt64);
    procedure Float(const AValue: Double);
    procedure Str(const AValue: string);
    procedure RawJson(const AJson: string);
    function ToString: string; override;
    function AsView: TStringView;
    function Len: SizeUInt;
  end;

constructor TJsonBuilderImpl.Create(const AInitialCap: SizeUInt);
begin
  inherited Create;
  FBuilder.Init(AInitialCap);
  FWriter.Init(FBuilder);
end;

destructor TJsonBuilderImpl.Destroy;
begin
  FBuilder.Done;
  inherited;
end;

procedure TJsonBuilderImpl.BeginObject;
begin
  FWriter.BeginObject;
end;

procedure TJsonBuilderImpl.EndObject;
begin
  FWriter.EndObject;
end;

procedure TJsonBuilderImpl.BeginArray;
begin
  FWriter.BeginArray;
end;

procedure TJsonBuilderImpl.EndArray;
begin
  FWriter.EndArray;
end;

procedure TJsonBuilderImpl.Key(const AKey: string);
begin
  FWriter.Key(AKey);
end;

procedure TJsonBuilderImpl.Null;
begin
  FWriter.Null;
end;

procedure TJsonBuilderImpl.Bool(const AValue: Boolean);
begin
  FWriter.Bool(AValue);
end;

procedure TJsonBuilderImpl.Int(const AValue: Int64);
begin
  FWriter.Int(AValue);
end;

procedure TJsonBuilderImpl.UInt(const AValue: UInt64);
begin
  FWriter.UInt(AValue);
end;

procedure TJsonBuilderImpl.Float(const AValue: Double);
begin
  FWriter.Float(AValue);
end;

procedure TJsonBuilderImpl.Str(const AValue: string);
begin
  FWriter.Str(AValue);
end;

procedure TJsonBuilderImpl.RawJson(const AJson: string);
begin
  FWriter.RawValue(PAnsiChar(AJson), SizeUInt(Length(AJson)));
end;

function TJsonBuilderImpl.ToString: string;
begin
  Result := FBuilder.ToString;
end;

function TJsonBuilderImpl.AsView: TStringView;
begin
  Result := FBuilder.AsView;
end;

function TJsonBuilderImpl.Len: SizeUInt;
begin
  Result := FBuilder.Len;
end;

function JsonBuilder: IJsonBuilder;
begin
  Result := TJsonBuilderImpl.Create(256);
end;

function JsonBuilder(const AInitialCap: SizeUInt): IJsonBuilder;
begin
  Result := TJsonBuilderImpl.Create(AInitialCap);
end;

end.
