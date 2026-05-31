unit nextpas.core.http.impl.h1.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FWriter: IWriter;
    FHeaders: IHttpHeaders;
    FHeadersSent: Boolean;
    FStatus: THttpStatus;
    procedure WriteStatusLine;
    procedure WriteAllHeaders;
    procedure WriteCRLF;
    procedure WriteStr(const AStr: string);
  public
    constructor Create(const AWriter: IWriter);
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Headers: IHttpHeaders read GetHeaders;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.http.headers;

{ TH1ResponseWriter }

constructor TH1ResponseWriter.Create(const AWriter: IWriter);
begin
  inherited Create;
  FWriter := AWriter;
  FHeaders := NewHttpHeaders;
  FHeadersSent := False;
  FStatus := HTTP_STATUS_OK;
end;

procedure TH1ResponseWriter.WriteStr(const AStr: string);
begin
  if Length(AStr) > 0 then
    FWriter.Write(AStr[1], SizeUInt(Length(AStr)));
end;

procedure TH1ResponseWriter.WriteCRLF;
const
  CRLF: array[0..1] of Byte = (13, 10);
begin
  FWriter.Write(CRLF[0], 2);
end;

procedure TH1ResponseWriter.WriteStatusLine;
begin
  WriteStr('HTTP/1.1 ');
  WriteStr(IntToStr(Int64(FStatus)));
  WriteStr(' ');
  WriteStr(HttpStatusText(FStatus));
  WriteCRLF;
end;

procedure TH1ResponseWriter.WriteAllHeaders;
begin
  FHeaders.ForEach(procedure(const AName, AValue: string)
  begin
    WriteStr(AName);
    WriteStr(': ');
    WriteStr(AValue);
    WriteCRLF;
  end);
end;

procedure TH1ResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  if FHeadersSent then
    Exit;
  FStatus := AStatus;
  if not FHeaders.Has('content-length') and not FHeaders.Has('transfer-encoding') then
    FHeaders.Set_('connection', 'close');
  WriteStatusLine;
  WriteAllHeaders;
  WriteCRLF;
  FHeadersSent := True;
end;

function TH1ResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TH1ResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TH1ResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if not FHeadersSent then
    WriteHeader(HTTP_STATUS_OK);
  Result := FWriter.Write(ABuf, ACount);
end;

procedure TH1ResponseWriter.Flush;
var
  LFlusher: IFlusher;
begin
  if Supports(FWriter, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

end.
