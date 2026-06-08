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
  TH1ParserErrorKind = (pekNone, pekMalformed, pekUnsupportedTransferCoding,
    pekUnsupportedMethod);
  TH1RequestMetadata = record
    HasHost: Boolean;
    HostRepeated: Boolean;
    HasTransferEncoding: Boolean;
    HasContentLength: Boolean;
    DeclaredContentLength: Int64;
    ContentLengthTooLarge: Boolean;
    RequestDeclaresBody: Boolean;
    ExpectsContinue: Boolean;
    HasUnsupportedExpect: Boolean;
    ConnectionClose: Boolean;
    ConnectionKeepAlive: Boolean;
  end;

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
    function HeadersComplete: Boolean;
    function IsComplete: Boolean;
    function ShouldKeepAlive: Boolean;
    function GetTrailerBytes: Int64;
    function GetRequestMetadata: TH1RequestMetadata;
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
    FHeaderStore: THttpHeaders;
    FUrl: string;
    FHeaders: IHttpHeaders;
    FBody: TBytes;
    FBodySize: SizeUInt;
    FHeadersComplete: Boolean;
    FComplete: Boolean;
    FError: Boolean;
    FErrorMsg: string;
    FErrorKind: TH1ParserErrorKind;
    FHeaderCompleteUserError: Boolean;
    FTrailerBytes: Int64;
    FRequestMetadata: TH1RequestMetadata;
    FPendingRequestMetadata: TH1RequestMetadata;
    FRequestMetadataSawHost: Boolean;
    FRequestMetadataSawConnection: Boolean;
    FRequestMetadataSawContentLength: Boolean;
    FRequestTransferEncoding: string;
    FCurrentField: string;
    FCurrentValue: string;
    FCurrentFieldPtr: PAnsiChar;
    FCurrentFieldLen: SizeUInt;
    FCurrentValuePtr: PAnsiChar;
    FCurrentValueLen: SizeUInt;
    function ResponseEndsAtEof: Boolean;
    procedure ApplyResponseSkipBodyHint;
    function RejectWithUserError(const AReason: string;
      const AKind: TH1ParserErrorKind; const AParser: PTLlhttpInternalT): LongInt;
    function BuildRequestMetadata(
      const AParser: PTLlhttpInternalT): LongInt;
    procedure UpdateRequestMetadataFromHeader(const AField: string;
      const AFieldPtr: PAnsiChar; const AFieldLen: SizeUInt;
      const AValue: string; const AValuePtr: PAnsiChar;
      const AValueLen: SizeUInt);
    procedure EnsureBodyCapacity(const ARequired: SizeUInt);
    function SnapshotBody: TBytes;
    function ConsumedUntilErrorPosition(const ABuf: PAnsiChar;
      const ALen: SizeUInt): SizeUInt;
    function ConsumedThroughHeaderBoundaryAfterErrorPosition(
      const ABuf: PAnsiChar; const ALen: SizeUInt): SizeUInt;
    procedure MaterializeCurrentHeaderSpans;
    procedure ClearCurrentHeaderSpans;
    procedure ClearRequestMetadataCache;
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
    function HeadersComplete: Boolean;
    function IsComplete: Boolean;
    function ShouldKeepAlive: Boolean;
    function GetTrailerBytes: Int64;
    function GetRequestMetadata: TH1RequestMetadata;
    function HasError: Boolean;
    function ErrorMessage: string;
    function ErrorKind: TH1ParserErrorKind;
    procedure Reset;
  end;

{ Callback helpers }

const
  UNSUPPORTED_REQUEST_VERSION_REASON = 'Unsupported HTTP request version';
  UNSUPPORTED_REQUEST_METHOD_REASON = 'Unsupported HTTP request method';
  INVALID_TRANSFER_ENCODING_REASON = 'Invalid `Transfer-Encoding` header value';
  UNSUPPORTED_REQUEST_TRANSFER_CODING_REASON =
    'Unsupported `Transfer-Encoding` request coding';
  BODY_TOO_LARGE_REASON = 'HTTP body buffer too large';

function IsResponseContentLengthFramingError(
  const AErrno: TLlhttpErrnoT): Boolean; inline;
begin
  Result := (AErrno = HPE_UNEXPECTED_CONTENT_LENGTH) or
            (AErrno = HPE_INVALID_CONTENT_LENGTH);
end;

function LowerTrim(const AValue: string): string; inline;
begin
  Result := LowerCase(TextTrim(AValue));
end;

function HeaderValueHasToken(const AValue, AToken: string): Boolean;
var
  LStart: SizeInt;
  LPos: SizeInt;
begin
  Result := False;
  if AValue = '' then
    Exit;

  LStart := 1;
  while LStart <= Length(AValue) do
  begin
    LPos := LStart;
    while (LPos <= Length(AValue)) and (AValue[LPos] <> ',') do
      Inc(LPos);
    if LowerTrim(Copy(AValue, LStart, LPos - LStart)) = AToken then
      Exit(True);
    LStart := LPos + 1;
  end;
end;

function HeaderValuesHaveToken(const AValues: TStringArray;
  const AToken: string): Boolean;
var
  LI: SizeInt;
begin
  Result := False;
  for LI := Low(AValues) to High(AValues) do
    if HeaderValueHasToken(AValues[LI], AToken) then
      Exit(True);
end;

function HeaderValuesFinalTokenEquals(const AValues: TStringArray;
  const AToken: string): Boolean;
var
  LI: SizeInt;
  LStart: SizeInt;
  LPos: SizeInt;
  LToken: string;
begin
  Result := False;
  for LI := Low(AValues) to High(AValues) do
  begin
    LStart := 1;
    while LStart <= Length(AValues[LI]) do
    begin
      LPos := LStart;
      while (LPos <= Length(AValues[LI])) and
            (AValues[LI][LPos] <> ',') do
        Inc(LPos);
      LToken := LowerTrim(Copy(AValues[LI], LStart, LPos - LStart));
      if LToken <> '' then
        Result := LToken = AToken;
      LStart := LPos + 1;
    end;
  end;
end;

function LowerAscii(const AChar: AnsiChar): AnsiChar; inline;
begin
  if (AChar >= 'A') and (AChar <= 'Z') then
    Result := AnsiChar(Ord(AChar) + 32)
  else
    Result := AChar;
end;

function HeaderFieldSpanEquals(const AFieldPtr: PAnsiChar;
  const AFieldLen: SizeUInt; const AName: string): Boolean; inline;
var
  I: SizeUInt;
begin
  Result := False;
  if AFieldPtr = nil then
    Exit;
  if AFieldLen <> SizeUInt(Length(AName)) then
    Exit;
  for I := 0 to AFieldLen - 1 do
    if LowerAscii(AFieldPtr[I]) <> AnsiChar(AName[SizeInt(I) + 1]) then
      Exit;
  Result := True;
end;

function HeaderFieldEquals(const AField: string; const AFieldPtr: PAnsiChar;
  const AFieldLen: SizeUInt; const AName: string): Boolean; inline;
begin
  if AField <> '' then
    Result := SameText(AField, AName)
  else
    Result := HeaderFieldSpanEquals(AFieldPtr, AFieldLen, AName);
end;

function CapturedHeaderValueToString(const AValue: string;
  const AValuePtr: PAnsiChar; const AValueLen: SizeUInt): string; inline;
begin
  if AValue <> '' then
    Exit(AValue);
  if AValuePtr = nil then
    Exit('');
  SetString(Result, AValuePtr, AValueLen);
end;

function CapturedHeaderValueIsNonEmpty(const AValue: string;
  const AValuePtr: PAnsiChar; const AValueLen: SizeUInt): Boolean; inline;
begin
  if AValue <> '' then
    Exit(True);
  Result := (AValuePtr <> nil) and (AValueLen > 0);
end;

function SpanTrimBounds(const AValuePtr: PAnsiChar; const AValueLen: SizeUInt;
  out AStart, AStop: SizeUInt): Boolean; inline;
begin
  AStart := 0;
  AStop := AValueLen;
  while (AStart < AStop) and (AValuePtr[AStart] <= ' ') do
    Inc(AStart);
  while (AStop > AStart) and (AValuePtr[AStop - 1] <= ' ') do
    Dec(AStop);
  Result := AStart < AStop;
end;

function TryParseTrimmedInt64Span(const AValuePtr: PAnsiChar;
  const AValueLen: SizeUInt; out AResult: Int64): Boolean;
var
  LStart: SizeUInt;
  LStop: SizeUInt;
  LIndex: SizeUInt;
  LLimit: QWord;
  LAcc: QWord;
  LDigit: QWord;
  LNegative: Boolean;
  LCh: AnsiChar;
begin
  AResult := 0;
  if (AValuePtr = nil) or
     (not SpanTrimBounds(AValuePtr, AValueLen, LStart, LStop)) then
    Exit(False);

  LNegative := False;
  LCh := AValuePtr[LStart];
  if (LCh = '+') or (LCh = '-') then
  begin
    LNegative := LCh = '-';
    Inc(LStart);
    if LStart >= LStop then
      Exit(False);
  end;

  if LNegative then
    LLimit := QWord(High(Int64)) + 1
  else
    LLimit := QWord(High(Int64));

  LAcc := 0;
  for LIndex := LStart to LStop - 1 do
  begin
    LCh := AValuePtr[LIndex];
    if (LCh < '0') or (LCh > '9') then
      Exit(False);
    LDigit := QWord(Ord(LCh) - Ord('0'));
    if LAcc > (LLimit - LDigit) div 10 then
      Exit(False);
    LAcc := (LAcc * 10) + LDigit;
  end;

  if LNegative then
  begin
    if LAcc = QWord(High(Int64)) + 1 then
      AResult := Low(Int64)
    else
      AResult := -Int64(LAcc);
  end
  else
    AResult := Int64(LAcc);
  Result := True;
end;

function CapturedHeaderValueTrimmedToInt64(const AValue: string;
  const AValuePtr: PAnsiChar; const AValueLen: SizeUInt;
  out AResult: Int64): Boolean; inline;
begin
  if AValue <> '' then
    Exit(TryStrToInt64(TextTrim(AValue), AResult));
  Result := TryParseTrimmedInt64Span(AValuePtr, AValueLen, AResult);
end;

function CapturedHeaderValueIsUnsignedDecimal(const AValue: string;
  const AValuePtr: PAnsiChar; const AValueLen: SizeUInt): Boolean;
var
  LValue: string;
  LStart: SizeUInt;
  LStop: SizeUInt;
  LIndex: SizeUInt;
begin
  if AValue <> '' then
  begin
    LValue := TextTrim(AValue);
    if LValue = '' then
      Exit(False);
    for LIndex := 1 to SizeUInt(Length(LValue)) do
      if (LValue[SizeInt(LIndex)] < '0') or
         (LValue[SizeInt(LIndex)] > '9') then
        Exit(False);
    Exit(True);
  end;

  if not SpanTrimBounds(AValuePtr, AValueLen, LStart, LStop) then
    Exit(False);
  for LIndex := LStart to LStop - 1 do
    if (AValuePtr[LIndex] < '0') or (AValuePtr[LIndex] > '9') then
      Exit(False);
  Result := True;
end;

procedure UpdateExpectMetadata(var AMetadata: TH1RequestMetadata;
  const AValue: string);
var
  LStart: SizeInt;
  LPos: SizeInt;
  LToken: string;
begin
  if AValue = '' then
    Exit;

  LStart := 1;
  while LStart <= Length(AValue) do
  begin
    LPos := LStart;
    while (LPos <= Length(AValue)) and (AValue[LPos] <> ',') do
      Inc(LPos);
    LToken := LowerTrim(Copy(AValue, LStart, LPos - LStart));
    if LToken = '100-continue' then
      AMetadata.ExpectsContinue := True
    else if LToken <> '' then
      AMetadata.HasUnsupportedExpect := True;
    LStart := LPos + 1;
  end;
end;

function TrimmedSpanEqualsLowerAscii(const AValuePtr: PAnsiChar;
  const AStart, AStop: SizeUInt; const AExpected: string): Boolean; inline;
var
  I: SizeUInt;
begin
  if (AStop - AStart) <> SizeUInt(Length(AExpected)) then
    Exit(False);
  for I := 0 to (AStop - AStart) - 1 do
    if LowerAscii(AValuePtr[AStart + I]) <>
       AnsiChar(AExpected[SizeInt(I) + 1]) then
      Exit(False);
  Result := True;
end;

procedure UpdateConnectionMetadata(var AMetadata: TH1RequestMetadata;
  const AValue: string);
var
  LStart: SizeInt;
  LPos: SizeInt;
  LToken: string;
begin
  if AValue = '' then
    Exit;

  LStart := 1;
  while LStart <= Length(AValue) do
  begin
    LPos := LStart;
    while (LPos <= Length(AValue)) and (AValue[LPos] <> ',') do
      Inc(LPos);
    LToken := LowerTrim(Copy(AValue, LStart, LPos - LStart));
    if LToken = 'close' then
      AMetadata.ConnectionClose := True
    else if LToken = 'keep-alive' then
      AMetadata.ConnectionKeepAlive := True;
    LStart := LPos + 1;
  end;
end;

procedure UpdateConnectionMetadataFromCapturedValue(
  var AMetadata: TH1RequestMetadata; const AValue: string;
  const AValuePtr: PAnsiChar; const AValueLen: SizeUInt);
var
  LStart: SizeUInt;
  LPos: SizeUInt;
  LTokenStart: SizeUInt;
  LTokenStop: SizeUInt;
begin
  if AValue <> '' then
  begin
    UpdateConnectionMetadata(AMetadata, TextTrim(AValue));
    Exit;
  end;
  if (AValuePtr = nil) or (AValueLen = 0) then
    Exit;

  LStart := 0;
  while LStart < AValueLen do
  begin
    LPos := LStart;
    while (LPos < AValueLen) and (AValuePtr[LPos] <> ',') do
      Inc(LPos);

    LTokenStart := LStart;
    LTokenStop := LPos;
    while (LTokenStart < LTokenStop) and
          (AValuePtr[LTokenStart] <= ' ') do
      Inc(LTokenStart);
    while (LTokenStop > LTokenStart) and
          (AValuePtr[LTokenStop - 1] <= ' ') do
      Dec(LTokenStop);

    if LTokenStart < LTokenStop then
    begin
      if TrimmedSpanEqualsLowerAscii(AValuePtr, LTokenStart, LTokenStop,
        'close') then
        AMetadata.ConnectionClose := True
      else if TrimmedSpanEqualsLowerAscii(AValuePtr, LTokenStart, LTokenStop,
        'keep-alive') then
        AMetadata.ConnectionKeepAlive := True;
    end;
    LStart := LPos + 1;
  end;
end;

procedure UpdateExpectMetadataFromCapturedValue(var AMetadata: TH1RequestMetadata;
  const AValue: string; const AValuePtr: PAnsiChar; const AValueLen: SizeUInt);
var
  LStart: SizeUInt;
  LPos: SizeUInt;
  LTokenStart: SizeUInt;
  LTokenStop: SizeUInt;
begin
  if AValue <> '' then
  begin
    UpdateExpectMetadata(AMetadata, TextTrim(AValue));
    Exit;
  end;
  if (AValuePtr = nil) or (AValueLen = 0) then
    Exit;

  LStart := 0;
  while LStart < AValueLen do
  begin
    LPos := LStart;
    while (LPos < AValueLen) and (AValuePtr[LPos] <> ',') do
      Inc(LPos);

    LTokenStart := LStart;
    LTokenStop := LPos;
    while (LTokenStart < LTokenStop) and
          (AValuePtr[LTokenStart] <= ' ') do
      Inc(LTokenStart);
    while (LTokenStop > LTokenStart) and
          (AValuePtr[LTokenStop - 1] <= ' ') do
      Dec(LTokenStop);

    if LTokenStart < LTokenStop then
    begin
      if TrimmedSpanEqualsLowerAscii(AValuePtr, LTokenStart, LTokenStop,
        '100-continue') then
        AMetadata.ExpectsContinue := True
      else
        AMetadata.HasUnsupportedExpect := True;
    end;
    LStart := LPos + 1;
  end;
end;

function BytesToString(const AData: TBytes; const ASize: SizeUInt): string;
begin
  SetLength(Result, SizeInt(ASize));
  if ASize > 0 then
    Move(AData[0], Result[1], ASize);
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

procedure AppendSpan(var AText: string; const AData: PAnsiChar;
  const ALen: SizeUInt); inline;
var
  LOldLen: SizeInt;
begin
  if ALen = 0 then
    Exit;
  LOldLen := Length(AText);
  if LOldLen = 0 then
  begin
    SetString(AText, AData, ALen);
    Exit;
  end;
  SetLength(AText, LOldLen + SizeInt(ALen));
  Move(AData^, AText[LOldLen + 1], ALen);
end;

procedure MaterializeCapturedSpan(var AText: string; var AData: PAnsiChar;
  var ALen: SizeUInt); inline;
begin
  if AData = nil then
    Exit;
  AppendSpan(AText, AData, ALen);
  AData := nil;
  ALen := 0;
end;

procedure CaptureHeaderSpan(var AText: string; var AData: PAnsiChar;
  var ACapturedLen: SizeUInt; const ASpan: PAnsiChar;
  const ASpanLen: SizeUInt); inline;
begin
  if ASpanLen = 0 then
    Exit;
  if (AText = '') and (AData = nil) then
  begin
    AData := ASpan;
    ACapturedLen := ASpanLen;
    Exit;
  end;
  MaterializeCapturedSpan(AText, AData, ACapturedLen);
  AppendSpan(AText, ASpan, ASpanLen);
end;

{ cdecl callbacks }

function CbOnUrl(p0: PTLlhttpInternalT; p1: PAnsiChar; p2: SizeUInt): LongInt; cdecl;
var
  LSelf: TH1Parser;
begin
  LSelf := GetSelf(p0);
  AppendSpan(LSelf.FUrl, p1, p2);
  Result := 0;
end;

function CbOnHeaderField(p0: PTLlhttpInternalT; p1: PAnsiChar; p2: SizeUInt): LongInt; cdecl;
var
  LSelf: TH1Parser;
begin
  LSelf := GetSelf(p0);
  if (p0^.flags and F_TRAILING) <> 0 then
    Inc(LSelf.FTrailerBytes, Int64(p2));
  CaptureHeaderSpan(LSelf.FCurrentField, LSelf.FCurrentFieldPtr,
    LSelf.FCurrentFieldLen, p1, p2);
  Result := 0;
end;

function CbOnHeaderValue(p0: PTLlhttpInternalT; p1: PAnsiChar; p2: SizeUInt): LongInt; cdecl;
var
  LSelf: TH1Parser;
begin
  LSelf := GetSelf(p0);
  if (p0^.flags and F_TRAILING) <> 0 then
    Inc(LSelf.FTrailerBytes, Int64(p2));
  CaptureHeaderSpan(LSelf.FCurrentValue, LSelf.FCurrentValuePtr,
    LSelf.FCurrentValueLen, p1, p2);
  Result := 0;
end;

function CbOnHeaderValueComplete(p0: PTLlhttpInternalT): LongInt; cdecl;
var
  LSelf: TH1Parser;
begin
  LSelf := GetSelf(p0);
  if (LSelf.FCurrentField <> '') or (LSelf.FCurrentFieldPtr <> nil) then
  begin
    if (p0^.flags and F_TRAILING) = 0 then
    begin
      if LSelf.FParserType = ptRequest then
        LSelf.UpdateRequestMetadataFromHeader(LSelf.FCurrentField,
          LSelf.FCurrentFieldPtr, LSelf.FCurrentFieldLen,
          LSelf.FCurrentValue, LSelf.FCurrentValuePtr,
          LSelf.FCurrentValueLen);
      if (LSelf.FCurrentField = '') and (LSelf.FCurrentValue = '') then
        LSelf.FHeaderStore.AddParsedSpans(LSelf.FCurrentFieldPtr,
          LSelf.FCurrentFieldLen, LSelf.FCurrentValuePtr,
          LSelf.FCurrentValueLen)
      else
      begin
        LSelf.MaterializeCurrentHeaderSpans;
        LSelf.FHeaderStore.AddParsed(LSelf.FCurrentField, LSelf.FCurrentValue);
      end;
    end;
    if (p0^.flags and F_TRAILING) <> 0 then
      Inc(LSelf.FTrailerBytes, 4);
  end;
  LSelf.ClearCurrentHeaderSpans;
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
  LSelf.FHeadersComplete := True;
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
    begin
      LSelf.FHeaderCompleteUserError := True;
      Exit(LSelf.RejectWithUserError(UNSUPPORTED_REQUEST_METHOD_REASON,
        pekUnsupportedMethod, p0));
    end;
    end;
    Result := LSelf.BuildRequestMetadata(p0);
    LSelf.FHeaderCompleteUserError := Result = HPE_USER;
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
  LRequired: SizeUInt;
begin
  LSelf := GetSelf(p0);
  if p2 > 0 then
  begin
    if p2 > High(SizeUInt) - LSelf.FBodySize then
      Exit(LSelf.RejectWithUserError(BODY_TOO_LARGE_REASON, pekMalformed, p0));
    LRequired := LSelf.FBodySize + p2;
    if LRequired > SizeUInt(High(SizeInt)) then
      Exit(LSelf.RejectWithUserError(BODY_TOO_LARGE_REASON, pekMalformed, p0));
    LSelf.EnsureBodyCapacity(LRequired);
    Move(p1^, LSelf.FBody[LSelf.FBodySize], p2);
    LSelf.FBodySize := LRequired;
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
  if (p0^.upgrade = 0) and (llhttp_should_keep_alive(p0) <> 0) then
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
  FHeaderStore := THttpHeaders.Create;
  FHeaders := FHeaderStore;
  FComplete := False;
  FError := False;
  FMethod := hmGet;
  FStatusCode := 0;
  FVersion := hvHttp11;
  ClearRequestMetadataCache;

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
begin
  LErrno := llhttp_execute(@FParser, ABuf, ALen);
  MaterializeCurrentHeaderSpans;
  if (LErrno = HPE_PAUSED) and FComplete then
  begin
    FError := False;
    FErrorMsg := '';
    Result := ConsumedUntilErrorPosition(ABuf, ALen);
    Exit;
  end;
  if (LErrno = HPE_PAUSED_UPGRADE) and (llhttp_get_upgrade(@FParser) <> 0) then
  begin
    FComplete := True;
    FError := False;
    FErrorMsg := '';
    Result := ConsumedUntilErrorPosition(ABuf, ALen);
    Exit;
  end;
  if LErrno <> HPE_OK then
  begin
    FError := True;
    FComplete := False;
    if FErrorKind = pekNone then
      FErrorKind := pekMalformed;
    FErrorMsg := string(AnsiString(llhttp_get_error_reason(@FParser)));
    if (LErrno = HPE_USER) and FHeaderCompleteUserError then
      Result := ConsumedThroughHeaderBoundaryAfterErrorPosition(ABuf, ALen)
    else if (FParserType = ptRequest) and
      (LErrno = HPE_INVALID_TRANSFER_ENCODING) then
      Result := ConsumedThroughHeaderBoundaryAfterErrorPosition(ABuf, ALen)
    else if (FParserType = ptResponse) and
      IsResponseContentLengthFramingError(LErrno) then
      Result := ConsumedThroughHeaderBoundaryAfterErrorPosition(ABuf, ALen)
    else
      Result := ConsumedUntilErrorPosition(ABuf, ALen);
  end
  else
    Result := ALen;
end;

function TH1Parser.ConsumedUntilErrorPosition(const ABuf: PAnsiChar;
  const ALen: SizeUInt): SizeUInt;
var
  LErrorPos: PAnsiChar;
  LBase: PtrUInt;
  LPos: PtrUInt;
begin
  Result := ALen;
  if ABuf = nil then
    Exit;
  LErrorPos := llhttp_get_error_pos(@FParser);
  if LErrorPos = nil then
    Exit;

  LBase := PtrUInt(ABuf);
  LPos := PtrUInt(LErrorPos);
  if (LPos >= LBase) and (LPos <= LBase + ALen) then
    Result := SizeUInt(LPos - LBase);
end;

function TH1Parser.ConsumedThroughHeaderBoundaryAfterErrorPosition(
  const ABuf: PAnsiChar; const ALen: SizeUInt): SizeUInt;
var
  LI: SizeUInt;
begin
  Result := ConsumedUntilErrorPosition(ABuf, ALen);
  if ABuf = nil then
    Exit;
  if Result >= ALen then
    Exit;

  LI := Result;
  while LI + 3 < ALen do
  begin
    if (ABuf[LI] = #13) and (ABuf[LI + 1] = #10) and
       (ABuf[LI + 2] = #13) and (ABuf[LI + 3] = #10) then
      Exit(LI + 4);
    Inc(LI);
  end;
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
  LTransferEncodingValues: TStringArray;
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

  LTransferEncodingValues := FHeaders.GetAll('transfer-encoding');
  if Length(LTransferEncodingValues) > 0 then
    Exit(not HeaderValuesFinalTokenEquals(LTransferEncodingValues, 'chunked'));

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
  Result := BytesToString(FBody, FBodySize);
end;

function TH1Parser.GetBodySize: Int64;
begin
  Result := Int64(FBodySize);
end;

function TH1Parser.NewBodyReader: IReader;
begin
  if FBodySize = 0 then
    Exit(nil);
  Result := TSharedBytesReader.Create(SnapshotBody);
end;

function TH1Parser.HeadersComplete: Boolean;
begin
  Result := FHeadersComplete;
end;

function TH1Parser.IsComplete: Boolean;
begin
  Result := FComplete;
end;

function TH1Parser.ShouldKeepAlive: Boolean;
var
  LConnValues: TStringArray;
  LTransferEncodingValues: TStringArray;
begin
  if FError then
    Exit(False);

  if FStatusCode = HTTP_STATUS_SWITCHING_PROTOCOLS then
    Exit(False);

  if (not FSkipBody) and
     ((FStatusCode div 100) <> 1) and
     (FStatusCode <> 204) and
     (FStatusCode <> 304) then
  begin
    LTransferEncodingValues := FHeaders.GetAll('transfer-encoding');
    if Length(LTransferEncodingValues) > 0 then
    begin
      if not HeaderValuesFinalTokenEquals(LTransferEncodingValues, 'chunked') then
        Exit(False);
    end
    else if FHeaders.Get('content-length') = '' then
      Exit(False);
  end;

  LConnValues := FHeaders.GetAll('connection');
  if HeaderValuesHaveToken(LConnValues, 'close') then
    Exit(False);

  if FVersion = hvHttp10 then
    Result := HeaderValuesHaveToken(LConnValues, 'keep-alive')
  else
    Result := True;
end;

function TH1Parser.GetTrailerBytes: Int64;
begin
  Result := FTrailerBytes;
end;

function TH1Parser.GetRequestMetadata: TH1RequestMetadata;
begin
  Result := FRequestMetadata;
end;

function TH1Parser.RejectWithUserError(const AReason: string;
  const AKind: TH1ParserErrorKind; const AParser: PTLlhttpInternalT): LongInt;
begin
  FErrorKind := AKind;
  FErrorMsg := AReason;
  llhttp_set_error_reason(AParser, PAnsiChar(FErrorMsg));
  Result := HPE_USER;
end;

function TH1Parser.BuildRequestMetadata(
  const AParser: PTLlhttpInternalT): LongInt;
var
  LTokens: TStringArray;
  LIndex: SizeInt;
  LLastTokenIndex: SizeInt;
  LToken: string;
begin
  Result := 0;
  if FPendingRequestMetadata.HasTransferEncoding then
  begin
    LTokens := TextSplit(LowerCase(FRequestTransferEncoding), ',');
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

    if LLastTokenIndex >= 0 then
    begin
      if LLastTokenIndex <> High(LTokens) then
        Exit(RejectWithUserError(INVALID_TRANSFER_ENCODING_REASON,
          pekMalformed, AParser));

      if TextTrim(LTokens[LLastTokenIndex]) = 'chunked' then
      begin
        for LIndex := 0 to LLastTokenIndex - 1 do
        begin
          LToken := TextTrim(LTokens[LIndex]);
          if (LToken = '') or (LToken = 'chunked') then
            Exit(RejectWithUserError(INVALID_TRANSFER_ENCODING_REASON,
              pekMalformed, AParser));
          Exit(RejectWithUserError(UNSUPPORTED_REQUEST_TRANSFER_CODING_REASON,
            pekUnsupportedTransferCoding, AParser));
        end;
      end
      else
        Exit(RejectWithUserError(UNSUPPORTED_REQUEST_TRANSFER_CODING_REASON,
          pekUnsupportedTransferCoding, AParser));
    end;
  end;
  FRequestMetadata := FPendingRequestMetadata;
end;

procedure TH1Parser.UpdateRequestMetadataFromHeader(const AField: string;
  const AFieldPtr: PAnsiChar; const AFieldLen: SizeUInt;
  const AValue: string; const AValuePtr: PAnsiChar;
  const AValueLen: SizeUInt);
var
  LValue: string;
begin
  if HeaderFieldEquals(AField, AFieldPtr, AFieldLen, 'host') then
  begin
    if FRequestMetadataSawHost then
    begin
      FPendingRequestMetadata.HostRepeated := True;
      Exit;
    end;
    FRequestMetadataSawHost := True;
    FPendingRequestMetadata.HasHost := CapturedHeaderValueIsNonEmpty(AValue,
      AValuePtr, AValueLen);
    Exit;
  end;

  if HeaderFieldEquals(AField, AFieldPtr, AFieldLen, 'connection') then
  begin
    FRequestMetadataSawConnection := True;
    UpdateConnectionMetadataFromCapturedValue(FPendingRequestMetadata, AValue,
      AValuePtr, AValueLen);
    Exit;
  end;

  if HeaderFieldEquals(AField, AFieldPtr, AFieldLen, 'content-length') then
  begin
    if FRequestMetadataSawContentLength then
      Exit;
    FRequestMetadataSawContentLength := True;
    if CapturedHeaderValueTrimmedToInt64(AValue, AValuePtr, AValueLen,
      FPendingRequestMetadata.DeclaredContentLength) then
    begin
      FPendingRequestMetadata.HasContentLength := True;
      if FPendingRequestMetadata.DeclaredContentLength > 0 then
        FPendingRequestMetadata.RequestDeclaresBody := True;
    end;
    if (not FPendingRequestMetadata.HasContentLength) and
       CapturedHeaderValueIsUnsignedDecimal(AValue, AValuePtr, AValueLen) then
    begin
      FPendingRequestMetadata.HasContentLength := True;
      FPendingRequestMetadata.ContentLengthTooLarge := True;
      FPendingRequestMetadata.RequestDeclaresBody := True;
    end;
    Exit;
  end;

  if HeaderFieldEquals(AField, AFieldPtr, AFieldLen, 'expect') then
  begin
    UpdateExpectMetadataFromCapturedValue(FPendingRequestMetadata, AValue,
      AValuePtr, AValueLen);
    Exit;
  end;

  if HeaderFieldEquals(AField, AFieldPtr, AFieldLen, 'transfer-encoding') then
  begin
    LValue := CapturedHeaderValueToString(AValue, AValuePtr, AValueLen);
    if FPendingRequestMetadata.HasTransferEncoding then
      FRequestTransferEncoding := FRequestTransferEncoding + ',' + LValue
    else
      FRequestTransferEncoding := LValue;
    FPendingRequestMetadata.HasTransferEncoding := True;
    FPendingRequestMetadata.RequestDeclaresBody := True;
  end;
end;

procedure TH1Parser.EnsureBodyCapacity(const ARequired: SizeUInt);
var
  LNewCapacity: SizeUInt;
begin
  if SizeUInt(Length(FBody)) >= ARequired then
    Exit;

  LNewCapacity := SizeUInt(Length(FBody));
  if LNewCapacity < 256 then
    LNewCapacity := 256;
  while LNewCapacity < ARequired do
    LNewCapacity := LNewCapacity * 2;
  SetLength(FBody, SizeInt(LNewCapacity));
end;

function TH1Parser.SnapshotBody: TBytes;
begin
  Result := nil;
  SetLength(Result, SizeInt(FBodySize));
  if FBodySize > 0 then
    Move(FBody[0], Result[0], FBodySize);
end;

procedure TH1Parser.MaterializeCurrentHeaderSpans;
begin
  MaterializeCapturedSpan(FCurrentField, FCurrentFieldPtr, FCurrentFieldLen);
  MaterializeCapturedSpan(FCurrentValue, FCurrentValuePtr, FCurrentValueLen);
end;

procedure TH1Parser.ClearCurrentHeaderSpans;
begin
  FCurrentField := '';
  FCurrentValue := '';
  FCurrentFieldPtr := nil;
  FCurrentFieldLen := 0;
  FCurrentValuePtr := nil;
  FCurrentValueLen := 0;
end;

procedure TH1Parser.ClearRequestMetadataCache;
begin
  FRequestMetadata := Default(TH1RequestMetadata);
  FPendingRequestMetadata := Default(TH1RequestMetadata);
  FRequestMetadataSawHost := False;
  FRequestMetadataSawConnection := False;
  FRequestMetadataSawContentLength := False;
  FRequestTransferEncoding := '';
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
  FHeaderStore.Clear;
  FBodySize := 0;
  FHeadersComplete := False;
  FComplete := False;
  FError := False;
  FErrorMsg := '';
  FErrorKind := pekNone;
  FHeaderCompleteUserError := False;
  FTrailerBytes := 0;
  ClearRequestMetadataCache;
  ClearCurrentHeaderSpans;
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
