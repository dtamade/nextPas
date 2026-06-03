unit nextpas.core.http.impl.h1.parser;
{**
 * @desc HTTP/1.1 parser adapter wrapping llhttp.
 *       Collects parsed request/response data into a high-level interface.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ParserType = (ptRequest, ptResponse);
  TH1ParserErrorKind = (pekNone, pekMalformed, pekUnsupportedTransferCoding);

  IH1Parser = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-500000000001}']
    function Execute(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeUInt;
    procedure Finish;
    function GetMethod: THttpMethod;
    function GetStatusCode: THttpStatus;
    function GetHttpVersion: THttpVersion;
    function GetUrl: string;
    function GetHeaders: IHttpHeaders;
    function GetBody: string;
    function GetBodySize: Int64;
    function NewBodyReader: IReader;
    function IsComplete: Boolean;
    function ShouldKeepAlive: Boolean;
    function GetTrailerBytes: Int64;
    function HasError: Boolean;
    function ErrorMessage: string;
    function ErrorKind: TH1ParserErrorKind;
    procedure Reset;
  end;

function NewH1RequestParser: IH1Parser;
function NewH1ResponseParser: IH1Parser; overload;
function NewH1ResponseParser(const ASkipBody: Boolean): IH1Parser; overload;

implementation

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.http.impl.h1.llhttp,
  nextpas.core.http.headers,
  nextpas.core.text;

type
  TSharedBytesReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPosition: SizeUInt;
    FSize: SizeUInt;
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TH1Parser = class(TInterfacedObject, IH1Parser)
  private
    FParser: TLlhttpInternalT;
    FSettings: TLlhttpSettingsT;
    FParserType: TH1ParserType;
    FSkipBody: Boolean;
    FMethod: THttpMethod;
    FStatusCode: THttpStatus;
    FVersion: THttpVersion;
    FUrl: string;
    FHeaders: IHttpHeaders;
    FBody: TBytes;
    FComplete: Boolean;
    FError: Boolean;
    FErrorMsg: string;
    FErrorKind: TH1ParserErrorKind;
    FTrailerBytes: Int64;
    FCurrentField: string;
    FCurrentValue: string;
    function ResponseEndsAtEof: Boolean;
    procedure ApplyResponseSkipBodyHint;
    function RejectWithUserError(const AReason: string;
      const AKind: TH1ParserErrorKind; const AParser: PTLlhttpInternalT): LongInt;
    function ValidateRequestTransferEncoding(
      const AParser: PTLlhttpInternalT): LongInt;
  public
    constructor Create(const AType: TH1ParserType;
      const ASkipBody: Boolean = False);
    function Execute(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeUInt;
    procedure Finish;
    function GetMethod: THttpMethod;
    function GetStatusCode: THttpStatus;
    function GetHttpVersion: THttpVersion;
    function GetUrl: string;
    function GetHeaders: IHttpHeaders;
    function GetBody: string;
    function GetBodySize: Int64;
    function NewBodyReader: IReader;
    function IsComplete: Boolean;
    function ShouldKeepAlive: Boolean;
    function GetTrailerBytes: Int64;
    function HasError: Boolean;
    function ErrorMessage: string;
    function ErrorKind: TH1ParserErrorKind;
    procedure Reset;
  end;

{ Callback helpers }

const
  UNSUPPORTED_REQUEST_VERSION_REASON = 'Unsupported HTTP request version';
  INVALID_TRANSFER_ENCODING_REASON = 'Invalid `Transfer-Encoding` header value';
  UNSUPPORTED_REQUEST_TRANSFER_CODING_REASON =
    'Unsupported `Transfer-Encoding` request coding';

function BytesToString(const AData: TBytes): string;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
end;

{ TSharedBytesReader }

constructor TSharedBytesReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
  FPosition := 0;
  FSize := SizeUInt(Length(AData));
end;

function TSharedBytesReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  if (ACount = 0) or (FPosition >= FSize) then
    Exit(0);
  LAvailable := FSize - FPosition;
  if ACount < LAvailable then
    Result := ACount
  else
    Result := LAvailable;
  Move(FData[FPosition], ABuf, Result);
  Inc(FPosition, Result);
end;

function GetSelf(p0: PTLlhttpInternalT): TH1Parser; inline;
begin
  Result := TH1Parser(p0^.data);
end;

function IsSupportedRequestVersion(const AParser: PTLlhttpInternalT): Boolean; inline;
begin
  Result := (AParser^.http_major = 1) and
            ((AParser^.http_minor = 0) or (AParser^.http_minor = 1));
end;

{ cdecl callbacks }

function CbOnUrl(p0: PTLlhttpInternalT; p1: PAnsiChar; p2: SizeUInt): LongInt; cdecl;
var
  LSelf: TH1Parser;
  LChunk: string;
begin
  LSelf := GetSelf(p0);
  SetString(LChunk, p1, p2);
  LSelf.FUrl := LSelf.FUrl + LChunk;
  Result := 0;
end;

function CbOnHeaderField(p0: PTLlhttpInternalT; p1: PAnsiChar; p2: SizeUInt): LongInt; cdecl;
var
  LSelf: TH1Parser;
  LChunk: string;
begin
  LSelf := GetSelf(p0);
  SetString(LChunk, p1, p2);
  if (p0^.flags and F_TRAILING) <> 0 then
    Inc(LSelf.FTrailerBytes, Int64(p2));
  LSelf.FCurrentField := LSelf.FCurrentField + LChunk;
  Result := 0;
end;

function CbOnHeaderValue(p0: PTLlhttpInternalT; p1: PAnsiChar; p2: SizeUInt): LongInt; cdecl;
var
  LSelf: TH1Parser;
  LChunk: string;
begin
  LSelf := GetSelf(p0);
  SetString(LChunk, p1, p2);
  if (p0^.flags and F_TRAILING) <> 0 then
    Inc(LSelf.FTrailerBytes, Int64(p2));
  LSelf.FCurrentValue := LSelf.FCurrentValue + LChunk;
  Result := 0;
end;

function CbOnHeaderValueComplete(p0: PTLlhttpInternalT): LongInt; cdecl;
var
  LSelf: TH1Parser;
begin
  LSelf := GetSelf(p0);
  if LSelf.FCurrentField <> '' then
  begin
    if (p0^.flags and F_TRAILING) = 0 then
      LSelf.FHeaders.Add(LSelf.FCurrentField, LSelf.FCurrentValue);
    if (p0^.flags and F_TRAILING) <> 0 then
      Inc(LSelf.FTrailerBytes, 4);
  end;
  LSelf.FCurrentField := '';
  LSelf.FCurrentValue := '';
  Result := 0;
end;

function CbOnHeadersComplete(p0: PTLlhttpInternalT): LongInt; cdecl;
var
  LSelf: TH1Parser;
begin
  LSelf := GetSelf(p0);
  if (LSelf.FParserType = ptRequest) and (not IsSupportedRequestVersion(p0)) then
  begin
    llhttp_set_error_reason(p0, PAnsiChar(UNSUPPORTED_REQUEST_VERSION_REASON));
    Exit(HPE_INVALID_VERSION);
  end;
  // Extract version
  if (p0^.http_major = 1) and (p0^.http_minor = 0) then
    LSelf.FVersion := hvHttp10
  else
    LSelf.FVersion := hvHttp11;
  // Extract method (request) or status (response)
  if LSelf.FParserType = ptRequest then
  begin
    case p0^.method of
      HTTP_DELETE:  LSelf.FMethod := hmDelete;
      HTTP_GET:    LSelf.FMethod := hmGet;
      HTTP_HEAD:   LSelf.FMethod := hmHead;
      HTTP_POST:   LSelf.FMethod := hmPost;
      HTTP_PUT:    LSelf.FMethod := hmPut;
      HTTP_CONNECT: LSelf.FMethod := hmConnect;
      HTTP_OPTIONS: LSelf.FMethod := hmOptions;
      HTTP_TRACE:  LSelf.FMethod := hmTrace;
      HTTP_PATCH:  LSelf.FMethod := hmPatch;
    else
      LSelf.FMethod := hmGet;
    end;
    Result := LSelf.ValidateRequestTransferEncoding(p0);
    if Result <> 0 then
      Exit;
  end
  else
    LSelf.FStatusCode := p0^.status_code;
  Result := 0;
end;

function CbOnBody(p0: PTLlhttpInternalT; p1: PAnsiChar; p2: SizeUInt): LongInt; cdecl;
var
  LSelf: TH1Parser;
  LOldLen: SizeUInt;
begin
  LSelf := GetSelf(p0);
  if p2 > 0 then
  begin
    LOldLen := SizeUInt(Length(LSelf.FBody));
    SetLength(LSelf.FBody, LOldLen + p2);
    Move(p1^, LSelf.FBody[LOldLen], p2);
  end;
  Result := 0;
end;

function CbOnMessageComplete(p0: PTLlhttpInternalT): LongInt; cdecl;
var
  LSelf: TH1Parser;
begin
  LSelf := GetSelf(p0);
  if (LSelf.FParserType = ptRequest) and (not IsSupportedRequestVersion(p0)) then
  begin
    llhttp_set_error_reason(p0, PAnsiChar(UNSUPPORTED_REQUEST_VERSION_REASON));
    Exit(HPE_INVALID_VERSION);
  end;
  LSelf.FComplete := True;
  if (LSelf.FParserType = ptRequest) and
     (p0^.upgrade = 0) and
     (llhttp_should_keep_alive(p0) <> 0) then
    Exit(HPE_PAUSED);
  Result := 0;
end;

{ TH1Parser }

constructor TH1Parser.Create(const AType: TH1ParserType;
  const ASkipBody: Boolean);
var
  LType: TLlhttpTypeT;
begin
  inherited Create;
  FParserType := AType;
  FSkipBody := ASkipBody and (AType = ptResponse);
  FHeaders := NewHttpHeaders;
  FComplete := False;
  FError := False;
  FMethod := hmGet;
  FStatusCode := 0;
  FVersion := hvHttp11;

  llhttp_settings_init(@FSettings);
  FSettings.on_url := @CbOnUrl;
  FSettings.on_header_field := @CbOnHeaderField;
  FSettings.on_header_value := @CbOnHeaderValue;
  FSettings.on_header_value_complete := @CbOnHeaderValueComplete;
  FSettings.on_headers_complete := @CbOnHeadersComplete;
  FSettings.on_body := @CbOnBody;
  FSettings.on_message_complete := @CbOnMessageComplete;

  if AType = ptRequest then
    LType := HTTP_REQUEST
  else
    LType := HTTP_RESPONSE;

  llhttp_init(@FParser, LType, @FSettings);
  FParser.data := Pointer(Self);
  ApplyResponseSkipBodyHint;
end;

function TH1Parser.Execute(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeUInt;
var
  LErrno: TLlhttpErrnoT;
  LErrorPos: PAnsiChar;
begin
  LErrno := llhttp_execute(@FParser, ABuf, ALen);
  if (LErrno = HPE_PAUSED) and FComplete then
  begin
    FError := False;
    FErrorMsg := '';
    LErrorPos := llhttp_get_error_pos(@FParser);
    if (LErrorPos <> nil) and
       (PtrUInt(LErrorPos) >= PtrUInt(ABuf)) and
       (PtrUInt(LErrorPos) <= PtrUInt(ABuf) + ALen) then
      Result := SizeUInt(PtrUInt(LErrorPos) - PtrUInt(ABuf))
    else
      Result := ALen;
    Exit;
  end;
  if (LErrno = HPE_PAUSED_UPGRADE) and (llhttp_get_upgrade(@FParser) <> 0) then
  begin
    FComplete := True;
    FError := False;
    FErrorMsg := '';
    LErrorPos := llhttp_get_error_pos(@FParser);
    if (LErrorPos <> nil) and
       (PtrUInt(LErrorPos) >= PtrUInt(ABuf)) and
       (PtrUInt(LErrorPos) <= PtrUInt(ABuf) + ALen) then
      Result := SizeUInt(PtrUInt(LErrorPos) - PtrUInt(ABuf))
    else
      Result := ALen;
    Exit;
  end;
  if LErrno <> HPE_OK then
  begin
    FError := True;
    FComplete := False;
    if FErrorKind = pekNone then
      FErrorKind := pekMalformed;
    FErrorMsg := string(AnsiString(llhttp_get_error_reason(@FParser)));
    Result := 0;
  end
  else
    Result := ALen;
end;

procedure TH1Parser.Finish;
var
  LErrno: TLlhttpErrnoT;
begin
  if FComplete then Exit;
  LErrno := llhttp_finish(@FParser);
  if (LErrno = HPE_OK) or (FComplete) then
    { on_message_complete was called by llhttp_finish }
  else
  begin
    { Only close-delimited responses may complete at EOF. }
    if (FParserType = ptResponse) and ResponseEndsAtEof then
      FComplete := True
    else
    begin
      FError := True;
      if FErrorKind = pekNone then
        FErrorKind := pekMalformed;
      FErrorMsg := string(AnsiString(llhttp_get_error_reason(@FParser)));
    end;
  end;
end;

function TH1Parser.ResponseEndsAtEof: Boolean;
var
  LTransferEncoding: string;
begin
  Result := False;
  if FStatusCode = 0 then
    Exit(False);

  if FSkipBody then
    Exit(True);

  if ((FStatusCode div 100) = 1) or
     (FStatusCode = 204) or
     (FStatusCode = 304) then
    Exit(True);

  LTransferEncoding := LowerCase(FHeaders.Get('transfer-encoding'));
  if LTransferEncoding <> '' then
    Exit(False);

  if FHeaders.Get('content-length') <> '' then
    Exit(False);

  Result := True;
end;

procedure TH1Parser.ApplyResponseSkipBodyHint;
begin
  if not FSkipBody then
    Exit;
  FParser.method := HTTP_HEAD;
  FParser.flags := FParser.flags or F_SKIPBODY;
end;

function TH1Parser.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function TH1Parser.GetStatusCode: THttpStatus;
begin
  Result := FStatusCode;
end;

function TH1Parser.GetHttpVersion: THttpVersion;
begin
  Result := FVersion;
end;

function TH1Parser.GetUrl: string;
begin
  Result := FUrl;
end;

function TH1Parser.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TH1Parser.GetBody: string;
begin
  Result := BytesToString(FBody);
end;

function TH1Parser.GetBodySize: Int64;
begin
  Result := Int64(Length(FBody));
end;

function TH1Parser.NewBodyReader: IReader;
begin
  if Length(FBody) = 0 then
    Exit(nil);
  Result := TSharedBytesReader.Create(FBody);
end;

function TH1Parser.IsComplete: Boolean;
begin
  Result := FComplete;
end;

function TH1Parser.ShouldKeepAlive: Boolean;
var
  LConn: string;
  LTransferEncoding: string;
begin
  if (not FSkipBody) and
     ((FStatusCode div 100) <> 1) and
     (FStatusCode <> 204) and
     (FStatusCode <> 304) then
  begin
    LTransferEncoding := LowerCase(FHeaders.Get('transfer-encoding'));
    if LTransferEncoding <> '' then
    begin
      if Pos('chunked', LTransferEncoding) = 0 then
        Exit(False);
    end
    else if FHeaders.Get('content-length') = '' then
      Exit(False);
  end;

  LConn := LowerCase(FHeaders.Get('connection'));
  if LConn = 'close' then
    Exit(False);

  if FVersion = hvHttp10 then
    Result := (LConn = 'keep-alive')
  else
    Result := True;
end;

function TH1Parser.GetTrailerBytes: Int64;
begin
  Result := FTrailerBytes;
end;

function TH1Parser.RejectWithUserError(const AReason: string;
  const AKind: TH1ParserErrorKind; const AParser: PTLlhttpInternalT): LongInt;
begin
  FErrorKind := AKind;
  FErrorMsg := AReason;
  llhttp_set_error_reason(AParser, PAnsiChar(FErrorMsg));
  Result := HPE_USER;
end;

function TH1Parser.ValidateRequestTransferEncoding(
  const AParser: PTLlhttpInternalT): LongInt;
var
  LValues: TStringArray;
  LCombined: string;
  LTokens: TStringArray;
  LIndex: SizeInt;
  LLastTokenIndex: SizeInt;
  LToken: string;
begin
  Result := 0;
  LValues := FHeaders.GetAll('transfer-encoding');
  if Length(LValues) = 0 then
    Exit(0);

  LCombined := LValues[0];
  for LIndex := 1 to High(LValues) do
    LCombined := LCombined + ',' + LValues[LIndex];

  LTokens := TextSplit(LowerCase(LCombined), ',');
  LLastTokenIndex := -1;
  for LIndex := High(LTokens) downto 0 do
  begin
    LToken := TextTrim(LTokens[LIndex]);
    if LToken <> '' then
    begin
      LLastTokenIndex := LIndex;
      Break;
    end;
  end;

  if LLastTokenIndex < 0 then
    Exit(0);

  if LLastTokenIndex <> High(LTokens) then
    Exit(RejectWithUserError(INVALID_TRANSFER_ENCODING_REASON,
      pekMalformed, AParser));

  if TextTrim(LTokens[LLastTokenIndex]) <> 'chunked' then
    Exit(0);

  for LIndex := 0 to LLastTokenIndex - 1 do
  begin
    LToken := TextTrim(LTokens[LIndex]);
    if (LToken = '') or (LToken = 'chunked') then
      Exit(RejectWithUserError(INVALID_TRANSFER_ENCODING_REASON,
        pekMalformed, AParser));
    Exit(RejectWithUserError(UNSUPPORTED_REQUEST_TRANSFER_CODING_REASON,
      pekUnsupportedTransferCoding, AParser));
  end;
end;

function TH1Parser.HasError: Boolean;
begin
  Result := FError;
end;

function TH1Parser.ErrorMessage: string;
begin
  Result := FErrorMsg;
end;

function TH1Parser.ErrorKind: TH1ParserErrorKind;
begin
  Result := FErrorKind;
end;

procedure TH1Parser.Reset;
begin
  FMethod := hmGet;
  FStatusCode := 0;
  FVersion := hvHttp11;
  FUrl := '';
  FHeaders := NewHttpHeaders;
  FBody := nil;
  FComplete := False;
  FError := False;
  FErrorMsg := '';
  FErrorKind := pekNone;
  FTrailerBytes := 0;
  FCurrentField := '';
  FCurrentValue := '';
  llhttp_reset(@FParser);
  FParser.data := Pointer(Self);
  ApplyResponseSkipBodyHint;
end;

{ Factory functions }

function NewH1RequestParser: IH1Parser;
begin
  Result := TH1Parser.Create(ptRequest);
end;

function NewH1ResponseParser: IH1Parser;
begin
  Result := NewH1ResponseParser(False);
end;

function NewH1ResponseParser(const ASkipBody: Boolean): IH1Parser;
begin
  Result := TH1Parser.Create(ptResponse, ASkipBody);
end;

end.
