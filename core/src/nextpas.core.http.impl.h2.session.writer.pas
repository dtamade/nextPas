unit nextpas.core.http.impl.h2.session.writer;
{**
 * @desc H2 server response writer (buffered IHttpResponseWriter).
 *       Mechanical extract from impl.h2.session (behavior freeze).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH2ResponseWriter = class(TInterfacedObject, IHttpResponseWriter,
    IHttpResponseWriterCommitState)
  private
    FStatus: THttpStatus;
    FHeaders: IHttpHeaders;
    FBody: IStream;
    FCommitted: Boolean;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    function BodyStream: IStream;
    function HeadersCommitted: Boolean;
  end;

implementation

uses
  nextpas.core.io.memory,
  nextpas.core.http.headers;

constructor TH2ResponseWriter.Create;
begin
  inherited Create;
  FStatus := HTTP_STATUS_OK;
  FHeaders := NewHttpHeaders;
  FBody := CreateBytesStream;
  FCommitted := False;
end;

procedure TH2ResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
  FCommitted := True;
end;

function TH2ResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TH2ResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TH2ResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if not FCommitted then
    WriteHeader(HTTP_STATUS_OK);
  Result := FBody.Write(ABuf, ACount);
end;

procedure TH2ResponseWriter.Flush;
begin
end;

function TH2ResponseWriter.BodyStream: IStream;
begin
  Result := FBody;
end;

function TH2ResponseWriter.HeadersCommitted: Boolean;
begin
  Result := FCommitted;
end;

end.