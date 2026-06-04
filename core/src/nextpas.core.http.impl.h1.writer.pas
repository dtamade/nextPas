unit nextpas.core.http.impl.h1.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ResponseWriter = class(TInterfacedObject, IHttpResponseWriter, IHttpHijacker)
  private
    FWriter: IWriter;
    FHeaders: IHttpHeaders;
    FHeadersSent: Boolean;
    FStatus: THttpStatus;
    FChunkedWriter: IWriter;
    FConn: ITcpStream;
    FHijacked: Boolean;
    FFinalized: Boolean;
    FNoBodyAllowed: Boolean;
    FSuppressBody: Boolean;
    procedure WriteStatusLine;
    procedure WriteInformationalHeader(const AStatus: THttpStatus);
    procedure WriteAllHeaders;
    procedure WriteCRLF;
    procedure WriteStr(const AStr: string);
    function ResponseMustNotHaveBody: Boolean;
  public
    constructor Create(const AWriter: IWriter); overload;
    constructor Create(const AWriter: IWriter; const AConn: ITcpStream); overload;
    constructor Create(const AWriter: IWriter; const AConn: ITcpStream;
      const ASuppressBody: Boolean); overload;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    function Hijack: ITcpStream;
    function HasCommitted: Boolean;
    function IsHijacked: Boolean;
    property Headers: IHttpHeaders read GetHeaders;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.impl.h1.chunked;

procedure WriteAllOrRaise(const AWriter: IWriter; const ABuf;
  const ACount: SizeUInt);
var
  LWritten: SizeUInt;
  LTotal: SizeUInt;
  LPtr: PByte;
begin
  if ACount = 0 then
    Exit;
  LPtr := @ABuf;
  LTotal := 0;
  while LTotal < ACount do
  begin
    LWritten := AWriter.Write(LPtr[LTotal], ACount - LTotal);
    if LWritten = 0 then
      raise EIOError.Create('h1 response writer: write failed (zero progress)');
    Inc(LTotal, LWritten);
  end;
end;

{ TH1ResponseWriter }

constructor TH1ResponseWriter.Create(const AWriter: IWriter);
begin
  Create(AWriter, nil, False);
end;

constructor TH1ResponseWriter.Create(const AWriter: IWriter; const AConn: ITcpStream);
begin
  Create(AWriter, AConn, False);
end;

constructor TH1ResponseWriter.Create(const AWriter: IWriter; const AConn: ITcpStream;
  const ASuppressBody: Boolean);
begin
  inherited Create;
  FWriter := AWriter;
  FHeaders := NewHttpHeaders;
  FHeadersSent := False;
  FStatus := HTTP_STATUS_OK;
  FConn := AConn;
  FHijacked := False;
  FFinalized := False;
  FNoBodyAllowed := False;
  FSuppressBody := ASuppressBody;
end;

procedure TH1ResponseWriter.WriteStr(const AStr: string);
begin
  if Length(AStr) > 0 then
    WriteAllOrRaise(FWriter, AStr[1], SizeUInt(Length(AStr)));
end;

procedure TH1ResponseWriter.WriteCRLF;
const
  CRLF: AnsiString = #13#10;
begin
  WriteAllOrRaise(FWriter, CRLF[1], 2);
end;

procedure TH1ResponseWriter.WriteStatusLine;
begin
  WriteStr('HTTP/1.1 ');
  WriteStr(IntToStr(Int64(FStatus)));
  WriteStr(' ');
  WriteStr(HttpStatusText(FStatus));
  WriteCRLF;
end;

procedure TH1ResponseWriter.WriteInformationalHeader(const AStatus: THttpStatus);
var
  LFinalStatus: THttpStatus;
begin
  LFinalStatus := FStatus;
  FStatus := AStatus;
  WriteStatusLine;
  WriteAllHeaders;
  WriteCRLF;
  FStatus := LFinalStatus;
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

function TH1ResponseWriter.ResponseMustNotHaveBody: Boolean;
begin
  Result := (FStatus = HTTP_STATUS_NO_CONTENT) or
            (FStatus = HTTP_STATUS_NOT_MODIFIED) or
            ((FStatus div 100) = 1);
end;

procedure TH1ResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  if FHeadersSent then
    Exit;
  if ((AStatus div 100) = 1) and (AStatus <> HTTP_STATUS_SWITCHING_PROTOCOLS) then
  begin
    WriteInformationalHeader(AStatus);
    Exit;
  end;
  FStatus := AStatus;
  FNoBodyAllowed := ResponseMustNotHaveBody;
  if (not FNoBodyAllowed) and
     (not FSuppressBody) and
     (not FHeaders.Has('content-length')) and
     (not FHeaders.Has('transfer-encoding')) then
    FHeaders.Set_('transfer-encoding', 'chunked');
  WriteStatusLine;
  WriteAllHeaders;
  WriteCRLF;
  FHeadersSent := True;
  if FHeaders.Get('transfer-encoding') = 'chunked' then
    FChunkedWriter := TChunkedWriter.Create(FWriter);
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
  if FFinalized then
    raise EHttpError.Create('response already finalized');
  if not FHeadersSent then
    WriteHeader(HTTP_STATUS_OK);
  if FNoBodyAllowed then
    raise EHttpError.Create('response status must not include a body');
  if FSuppressBody then
    Exit(ACount);
  if FChunkedWriter <> nil then
    Result := FChunkedWriter.Write(ABuf, ACount)
  else
  begin
    WriteAllOrRaise(FWriter, ABuf, ACount);
    Result := ACount;
  end;
end;

procedure TH1ResponseWriter.Flush;
var
  LFlusher: IFlusher;
begin
  if FChunkedWriter <> nil then
  begin
    (FChunkedWriter as IFlusher).Flush;
    FFinalized := True;
  end;
  if Supports(FWriter, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function TH1ResponseWriter.Hijack: ITcpStream;
begin
  if FConn = nil then
    raise EHttpError.Create('Connection not available for hijack');
  FHijacked := True;
  Result := FConn;
end;

function TH1ResponseWriter.HasCommitted: Boolean;
begin
  Result := FHeadersSent;
end;

function TH1ResponseWriter.IsHijacked: Boolean;
begin
  Result := FHijacked;
end;

end.
