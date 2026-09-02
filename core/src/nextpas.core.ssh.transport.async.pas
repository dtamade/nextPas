unit nextpas.core.ssh.transport.async;

{** nextpas.core.ssh - 异步传输层 (TAsyncLoop + IAsyncTcpStream via ssh.net.ffi 单缝隙).
 * 复用 cipher/compress/kex 的同步加解密逻辑, I/O 事件化；IAsyncTcpStream 经 net.ffi re-export 单缝隙收口。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.async.loop,
  nextpas.core.async.base,
  nextpas.core.ssh.net.ffi,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.transport.core,
  nextpas.core.ssh.kex;

type
  TSshAsyncCb = procedure(AErr: ESSHError; AContext: Pointer);
  TSshAsyncPacketCb = procedure(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
  TSshAsyncStringCb = procedure(const AValue: string; AErr: ESSHError; AContext: Pointer);

  TAsyncSshTransport = class
  private
    FLoop: TAsyncLoop;
    FStream: IAsyncTcpStream;
    FState: TSshTransportState;
    FCore: TSshTransportCore;
    FServerIdent: string;
    FMyKexInitPayload: TBytes;

    FReadHeader: TBytes;
    FReadHeaderOff: SizeUInt;
    FReadBodyLen: UInt32;
    FReadTrailer: TBytes;
    FReadTrailerOff: SizeUInt;
    FReadPacketCb: TSshAsyncPacketCb;
    FReadPacketCtx: Pointer;

    FWriteBuf: TBytes;
    FWriteOff: SizeUInt;
    FWriteCb: TSshAsyncCb;
    FWriteCtx: Pointer;

    FVersionLines: Integer;
    FVersionBuf: TBytes;
    FVersionPos: Integer;
    FVersionCb: TSshAsyncStringCb;
    FVersionCtx: Pointer;
    FVersionSendBuf: TBytes;

    procedure FailPacketCb(AErr: ESSHError);
    procedure FailVersionCb(AErr: ESSHError);
    procedure FailWriteCb(AErr: ESSHError);
    procedure StartReadHeader;
    procedure DoReadPacket(const ACb: TSshAsyncPacketCb; AContext: Pointer);
    procedure DoSendPacket(const APayload: TBytes; const ACb: TSshAsyncCb; AContext: Pointer);
    procedure HandleWriteChunk(AUserData: UInt64; AResult: Int32);
    procedure HandleHeaderChunk(AResult: Int32);
    procedure HandleTrailerChunk(AResult: Int32);
    procedure HandleVersionSendDone(AResult: Int32);
    procedure HandleVersionByte(AResult: Int32);
  public
    constructor Create(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream);
    destructor Destroy; override;

    function AsyncExchangeVersions(const ACb: TSshAsyncStringCb; AContext: Pointer = nil): Boolean;
    function AsyncSendKexInit(const ACookie: TBytes; const ACb: TSshAsyncCb; AContext: Pointer = nil): Boolean;
    function AsyncSendKexInitEx(const ACookie: TBytes; ACompress: Boolean; const ACb: TSshAsyncCb; AContext: Pointer = nil): Boolean;
    procedure SetNegotiatedCompression(const ANeg: TSshNegotiated);
    procedure EnableCompression;
    function IsCompressionEnabled: Boolean;
    procedure ConfigureRekey(ABytes: UInt64; AIntervalMs: Integer);
    function ShouldRekey: Boolean;
    function AsyncSendIgnore(const AData: TBytes; const ACb: TSshAsyncCb; AContext: Pointer = nil): Boolean;
    function AsyncSendIgnoreEmpty(const ACb: TSshAsyncCb; AContext: Pointer = nil): Boolean;
    procedure ResetRekeyCounters;
    function AsyncSendPacket(const APayload: TBytes; const ACb: TSshAsyncCb; AContext: Pointer = nil): Boolean;
    function AsyncReadPacket(const ACb: TSshAsyncPacketCb; AContext: Pointer = nil): Boolean;
    function IsWriteBusy: Boolean;
    function DebugState: string;
    procedure ApplyNewKeys(const ANegotiated: TSshNegotiated;
      const AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc: TBytes);
    function AsyncDisconnect(AReason: UInt32; const ADesc: string; const ACb: TSshAsyncCb; AContext: Pointer = nil): Boolean;
    procedure Close;

    property State: TSshTransportState read FState;
    property ServerIdent: string read FServerIdent;
    property MyKexInitPayload: TBytes read FMyKexInitPayload;
    property Loop: TAsyncLoop read FLoop;
    property Stream: IAsyncTcpStream read FStream;
    procedure SetStateForTest(AState: TSshTransportState);
  end;

implementation

uses
  nextpas.core.crypto.random;

procedure AsyncTrans_OnWriteChunk(AUserData: UInt64; AResult: Int32; AContext: Pointer); forward;
procedure AsyncTrans_OnHeaderChunk(AUserData: UInt64; AResult: Int32; AContext: Pointer); forward;
procedure AsyncTrans_OnTrailerChunk(AUserData: UInt64; AResult: Int32; AContext: Pointer); forward;
procedure AsyncTrans_OnVersionSendDone(AUserData: UInt64; AResult: Int32; AContext: Pointer); forward;
procedure AsyncTrans_OnVersionByte(AUserData: UInt64; AResult: Int32; AContext: Pointer); forward;

constructor TAsyncSshTransport.Create(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream);
begin
  inherited Create;
  if (ALoop = nil) or (AStream = nil) then
    raise ESSHError.Create(sekProtocol, 'async transport: nil loop or stream');
  FLoop := ALoop;
  FStream := AStream;
  FState := tstInit;
  FCore := TSshTransportCore.Create;
end;

destructor TAsyncSshTransport.Destroy;
begin
  Close;
  FCore.Free;
  inherited;
end;

procedure TAsyncSshTransport.Close;
begin
  if FState <> tstClosed then
  begin
    FState := tstClosed;
    try FStream.Close; except end;
  end;
end;

procedure TAsyncSshTransport.FailPacketCb(AErr: ESSHError);
var Lcb: TSshAsyncPacketCb; Ctx: Pointer;
begin
  Lcb := FReadPacketCb; Ctx := FReadPacketCtx;
  FReadPacketCb := nil; FReadPacketCtx := nil;
  if Assigned(Lcb) then Lcb(nil, AErr, Ctx) else if AErr <> nil then AErr.Free;
end;

procedure TAsyncSshTransport.FailVersionCb(AErr: ESSHError);
var Lcb: TSshAsyncStringCb; Ctx: Pointer;
begin
  Lcb := FVersionCb; Ctx := FVersionCtx;
  FVersionCb := nil; FVersionCtx := nil;
  if Assigned(Lcb) then Lcb('', AErr, Ctx) else if AErr <> nil then AErr.Free;
end;

procedure TAsyncSshTransport.FailWriteCb(AErr: ESSHError);
var Lcb: TSshAsyncCb; Ctx: Pointer;
begin
  Lcb := FWriteCb; Ctx := FWriteCtx;
  FWriteCb := nil; FWriteCtx := nil; FWriteBuf := nil;
  if Assigned(Lcb) then Lcb(AErr, Ctx) else if AErr <> nil then AErr.Free;
end;

procedure TAsyncSshTransport.SetNegotiatedCompression(const ANeg: TSshNegotiated);
begin
  FCore.SetNegotiatedCompression(ANeg);
end;

procedure TAsyncSshTransport.EnableCompression;
begin
  FCore.EnableCompression;
end;

function TAsyncSshTransport.IsCompressionEnabled: Boolean;
begin
  Result := FCore.IsCompressionEnabled;
end;

procedure TAsyncSshTransport.ConfigureRekey(ABytes: UInt64; AIntervalMs: Integer);
begin
  FCore.ConfigureRekey(ABytes, AIntervalMs);
end;

function TAsyncSshTransport.ShouldRekey: Boolean;
begin
  Result := FCore.ShouldRekey(FState = tstEncrypted);
end;

procedure TAsyncSshTransport.ResetRekeyCounters;
begin
  FCore.ResetRekeyCounters;
end;

function TAsyncSshTransport.AsyncSendIgnore(const AData: TBytes; const ACb: TSshAsyncCb; AContext: Pointer): Boolean;
var LW: TsshWriter;
begin
  LW := TsshWriter.Create(1 + 4 + Length(AData));
  try
    LW.PutByte(SSH_MSG_IGNORE);
    LW.PutStringBytes(AData);
    Result := AsyncSendPacket(LW.ToBytes, ACb, AContext);
  finally LW.Free; end;
end;

function TAsyncSshTransport.AsyncSendIgnoreEmpty(const ACb: TSshAsyncCb; AContext: Pointer): Boolean;
begin
  Result := AsyncSendIgnore(nil, ACb, AContext);
end;

function TAsyncSshTransport.IsWriteBusy: Boolean;
begin
  Result := FWriteCb <> nil;
end;

function TAsyncSshTransport.DebugState: string;
begin
  Result := 'cb=' + BoolToStr(FWriteCb <> nil, 'True', 'False') + ' buf=' + nextpas.core.text.conv.IntToStr(Int64(Length(FWriteBuf))) + ' off=' + nextpas.core.text.conv.IntToStr(Int64(FWriteOff)) + ' state=' + nextpas.core.text.conv.IntToStr(Int64(Ord(FState))) + ' ptr=' + nextpas.core.text.conv.IntToStr(Int64(PtrUInt(Self)));
end;

procedure TAsyncSshTransport.SetStateForTest(AState: TSshTransportState);
begin
  FState := AState;
end;

procedure TAsyncSshTransport.ApplyNewKeys(const ANegotiated: TSshNegotiated;
  const AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc: TBytes);
begin
  if FState <> tstKexExchange then
    raise ESSHError.Create(sekProtocol, 'ssh transport: NEWKEYS outside kex');
  FCore.ApplyNewKeys(ANegotiated, AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc);
  FState := tstEncrypted;
end;

procedure TAsyncSshTransport.DoSendPacket(const APayload: TBytes; const ACb: TSshAsyncCb; AContext: Pointer);
var
  LWire: TBytes;
begin
  if FState = tstClosed then
  begin
    if Assigned(ACb) then ACb(ESSHError.Create(sekIO, 'ssh transport: closed'), AContext);
    Exit;
  end;
  try
    LWire := FCore.EncodePacket(APayload);
  except
    on E: ESSHError do
    begin
      if Assigned(ACb) then ACb(E, AContext) else E.Free;
      Exit;
    end;
    on E: Exception do
    begin
      if Assigned(ACb) then ACb(ESSHError.Create(sekIO, E.Message), AContext);
      Exit;
    end;
  end;
  FWriteBuf := LWire;
  FWriteOff := 0;
  FWriteCb := ACb;
  FWriteCtx := AContext;
  HandleWriteChunk(0, 0);
end;

function TAsyncSshTransport.AsyncSendPacket(const APayload: TBytes; const ACb: TSshAsyncCb; AContext: Pointer): Boolean;
begin
  if FWriteCb <> nil then Exit(False);
  DoSendPacket(APayload, ACb, AContext);
  Result := True;
end;

procedure TAsyncSshTransport.HandleWriteChunk(AUserData: UInt64; AResult: Int32);
var
  LRem: SizeUInt;
  Lcb: TSshAsyncCb;
  Ctx: Pointer;
begin
  if AResult < 0 then
  begin
    Lcb := FWriteCb; Ctx := FWriteCtx; FWriteCb := nil; FWriteCtx := nil; FWriteBuf := nil;
    if Assigned(Lcb) then Lcb(ESSHError.Create(sekIO, 'ssh transport: async write failed (' + nextpas.core.text.conv.IntToStr(Int64(AResult)) + ')'), Ctx);
    Exit;
  end;
  if AResult > 0 then Inc(FWriteOff, SizeUInt(AResult));
  LRem := SizeUInt(Length(FWriteBuf)) - FWriteOff;
  if LRem = 0 then
  begin
    Lcb := FWriteCb; Ctx := FWriteCtx; FWriteCb := nil; FWriteCtx := nil; FWriteBuf := nil;
    if Assigned(Lcb) then Lcb(nil, Ctx);
    Exit;
  end;
  if not FStream.AsyncWrite(@FWriteBuf[FWriteOff], UInt32(LRem), @AsyncTrans_OnWriteChunk, Self) then
  begin
    Lcb := FWriteCb; Ctx := FWriteCtx; FWriteCb := nil; FWriteCtx := nil; FWriteBuf := nil;
    if Assigned(Lcb) then Lcb(ESSHError.Create(sekIO, 'ssh transport: async write submit failed'), Ctx);
  end;
end;

function TAsyncSshTransport.AsyncSendKexInit(const ACookie: TBytes; const ACb: TSshAsyncCb; AContext: Pointer): Boolean;
begin
  Result := AsyncSendKexInitEx(ACookie, False, ACb, AContext);
end;

function TAsyncSshTransport.AsyncSendKexInitEx(const ACookie: TBytes; ACompress: Boolean; const ACb: TSshAsyncCb; AContext: Pointer): Boolean;
begin
  FMyKexInitPayload := SshBuildKexInitPayloadEx(ACookie, ACompress);
  Result := AsyncSendPacket(FMyKexInitPayload, ACb, AContext);
end;

procedure TAsyncSshTransport.DoReadPacket(const ACb: TSshAsyncPacketCb; AContext: Pointer);
begin
  if FState = tstClosed then
  begin
    if Assigned(ACb) then ACb(nil, ESSHError.Create(sekIO, 'ssh transport: closed'), AContext);
    Exit;
  end;
  FReadPacketCb := ACb;
  FReadPacketCtx := AContext;
  SetLength(FReadHeader, 4);
  FReadHeaderOff := 0;
  StartReadHeader;
end;

function TAsyncSshTransport.AsyncReadPacket(const ACb: TSshAsyncPacketCb; AContext: Pointer): Boolean;
begin
  if FReadPacketCb <> nil then Exit(False);
  DoReadPacket(ACb, AContext);
  Result := True;
end;

procedure TAsyncSshTransport.StartReadHeader;
begin
  if FReadHeaderOff >= 4 then
  begin
    try
      FReadBodyLen := FCore.BodyLengthFromHeader(FReadHeader);
    except
      on E: ESSHError do begin FailPacketCb(E); Exit; end;
      on E: Exception do begin FailPacketCb(ESSHError.Create(sekProtocol, E.Message)); Exit; end;
    end;
    if (FReadBodyLen < 1) or (FReadBodyLen > SSH_MAX_RECEIVE_PACKET) then
    begin FailPacketCb(ESSHError.Create(sekProtocol, 'ssh transport: unreasonable packet length ' + nextpas.core.text.conv.IntToStr(Int64(FReadBodyLen)))); Exit; end;
    SetLength(FReadTrailer, FCore.TrailerSize(FReadBodyLen));
    FReadTrailerOff := 0;
    if Length(FReadTrailer) = 0 then
    begin
      HandleTrailerChunk(0);
      Exit;
    end;
    if not FStream.AsyncRead(@FReadTrailer[0], UInt32(Length(FReadTrailer)), @AsyncTrans_OnTrailerChunk, Self) then
      FailPacketCb(ESSHError.Create(sekIO, 'ssh transport: async read trailer submit failed'));
    Exit;
  end;
  if not FStream.AsyncRead(@FReadHeader[FReadHeaderOff], UInt32(4 - FReadHeaderOff), @AsyncTrans_OnHeaderChunk, Self) then
    FailPacketCb(ESSHError.Create(sekIO, 'ssh transport: async read header submit failed'));
end;

procedure TAsyncSshTransport.HandleHeaderChunk(AResult: Int32);
begin
  if AResult <= 0 then
  begin
    if AResult = 0 then FailPacketCb(ESSHError.Create(sekIO, 'ssh transport: connection closed by peer'))
    else FailPacketCb(ESSHError.Create(sekIO, 'ssh transport: async read header failed (' + nextpas.core.text.conv.IntToStr(Int64(AResult)) + ')'));
    Exit;
  end;
  Inc(FReadHeaderOff, SizeUInt(AResult));
  StartReadHeader;
end;

procedure TAsyncSshTransport.HandleTrailerChunk(AResult: Int32);
var
  LPacket: TBytes;
  LResult: TBytes;
  Lcb: TSshAsyncPacketCb;
  Ctx: Pointer;
begin
  if AResult < 0 then
  begin FailPacketCb(ESSHError.Create(sekIO, 'ssh transport: async read trailer failed (' + nextpas.core.text.conv.IntToStr(Int64(AResult)) + ')')); Exit; end;
  if AResult > 0 then Inc(FReadTrailerOff, SizeUInt(AResult));
  if FReadTrailerOff < SizeUInt(Length(FReadTrailer)) then
  begin
    if not FStream.AsyncRead(@FReadTrailer[FReadTrailerOff], UInt32(SizeUInt(Length(FReadTrailer)) - FReadTrailerOff), @AsyncTrans_OnTrailerChunk, Self) then
      FailPacketCb(ESSHError.Create(sekIO, 'ssh transport: async read trailer submit failed'));
    Exit;
  end;
  SetLength(LPacket, 4 + SizeUInt(Length(FReadTrailer)));
  Move(FReadHeader[0], LPacket[0], 4);
  if Length(FReadTrailer) > 0 then Move(FReadTrailer[0], LPacket[4], SizeUInt(Length(FReadTrailer)));
  try
    LResult := FCore.DecodePacket(LPacket);
  except
    on E: ESSHError do begin FailPacketCb(E); Exit; end;
    on E: Exception do begin FailPacketCb(ESSHError.Create(sekProtocol, E.Message)); Exit; end;
  end;
  Lcb := FReadPacketCb; Ctx := FReadPacketCtx; FReadPacketCb := nil; FReadPacketCtx := nil;
  FReadHeader := nil; FReadTrailer := nil;
  if Assigned(Lcb) then Lcb(LResult, nil, Ctx);
end;

function TAsyncSshTransport.AsyncExchangeVersions(const ACb: TSshAsyncStringCb; AContext: Pointer): Boolean;
begin
  if FState <> tstInit then
  begin if Assigned(ACb) then ACb('', ESSHError.Create(sekProtocol, 'ssh transport: versions already exchanged'), AContext); Exit(False); end;
  if FVersionCb <> nil then Exit(False);
  FVersionCb := ACb;
  FVersionCtx := AContext;
  FVersionLines := 0;
  FVersionPos := 0;
  SetLength(FVersionBuf, 256);
  SetLength(FVersionSendBuf, Length(SSH_PROTOCOL_VERSION) + 2);
  Move(PByte(PChar(SSH_PROTOCOL_VERSION))^, FVersionSendBuf[0], SizeUInt(Length(SSH_PROTOCOL_VERSION)));
  FVersionSendBuf[Length(SSH_PROTOCOL_VERSION)] := 13;
  FVersionSendBuf[Length(SSH_PROTOCOL_VERSION) + 1] := 10;
  FState := tstVersionExchange;
  FWriteBuf := FVersionSendBuf;
  FWriteOff := 0;
  if not FStream.AsyncWrite(@FWriteBuf[0], UInt32(Length(FWriteBuf)), @AsyncTrans_OnVersionSendDone, Self) then
  begin
    FVersionCb := nil; FVersionCtx := nil;
    if Assigned(ACb) then ACb('', ESSHError.Create(sekIO, 'ssh transport: async write ident submit failed'), AContext);
    Exit(False);
  end;
  Result := True;
end;

procedure TAsyncSshTransport.HandleVersionSendDone(AResult: Int32);
var LRem: SizeUInt;
begin
  if AResult < 0 then begin FailVersionCb(ESSHError.Create(sekIO, 'ssh transport: ident send failed (' + nextpas.core.text.conv.IntToStr(Int64(AResult)) + ')')); Exit; end;
  Inc(FWriteOff, SizeUInt(AResult));
  LRem := SizeUInt(Length(FWriteBuf)) - FWriteOff;
  if LRem > 0 then
  begin
    if not FStream.AsyncWrite(@FWriteBuf[FWriteOff], UInt32(LRem), @AsyncTrans_OnVersionSendDone, Self) then
      FailVersionCb(ESSHError.Create(sekIO, 'ssh transport: async write ident submit failed'));
    Exit;
  end;
  FWriteBuf := nil; FWriteOff := 0; FVersionSendBuf := nil;
  if not FStream.AsyncRead(@FVersionBuf[FVersionPos], 1, @AsyncTrans_OnVersionByte, Self) then
    FailVersionCb(ESSHError.Create(sekIO, 'ssh transport: async read ident submit failed'));
end;

procedure TAsyncSshTransport.HandleVersionByte(AResult: Int32);
var LByte: Byte; LLine: string;
begin
  if AResult <= 0 then begin FailVersionCb(ESSHError.Create(sekIO, 'ssh transport: connection closed by peer')); Exit; end;
  LByte := FVersionBuf[FVersionPos];
  Inc(FVersionPos);
  if LByte <> 10 then
  begin
    if FVersionPos >= Length(FVersionBuf) then SetLength(FVersionBuf, Length(FVersionBuf) + 256);
    if FVersionPos > SSH_IDENT_MAX_LINE then begin FailVersionCb(ESSHError.Create(sekProtocol, 'ssh transport: ident banner too long')); Exit; end;
    if not FStream.AsyncRead(@FVersionBuf[FVersionPos], 1, @AsyncTrans_OnVersionByte, Self) then
      FailVersionCb(ESSHError.Create(sekIO, 'ssh transport: async read ident submit failed'));
    Exit;
  end;
  while (FVersionPos > 0) and ((FVersionBuf[FVersionPos-1] = 13) or (FVersionBuf[FVersionPos-1] = 10)) do Dec(FVersionPos);
  SetLength(LLine, FVersionPos);
  if FVersionPos > 0 then Move(FVersionBuf[0], PByte(PChar(LLine))^, SizeUInt(FVersionPos));
  Inc(FVersionLines);
  if FVersionLines > 32 then begin FailVersionCb(ESSHError.Create(sekProtocol, 'ssh transport: too many pre-ident lines')); Exit; end;
  if Copy(LLine, 1, 4) <> 'SSH-' then
  begin
    FVersionPos := 0;
    if not FStream.AsyncRead(@FVersionBuf[0], 1, @AsyncTrans_OnVersionByte, Self) then
      FailVersionCb(ESSHError.Create(sekIO, 'ssh transport: async read ident submit failed'));
    Exit;
  end;
  if (Copy(LLine, 1, 7) <> 'SSH-2.0') and (Copy(LLine, 1, 8) <> 'SSH-1.99') then
  begin FailVersionCb(ESSHError.Create(sekUnsupported, 'ssh transport: peer is not SSH-2.0 ("' + LLine + '")')); Exit; end;
  FServerIdent := LLine;
  FState := tstKexExchange;
  FVersionBuf := nil; FVersionPos := 0;
  if Assigned(FVersionCb) then
  begin
    FVersionCb(FServerIdent, nil, FVersionCtx);
    FVersionCb := nil; FVersionCtx := nil;
  end;
end;

function TAsyncSshTransport.AsyncDisconnect(AReason: UInt32; const ADesc: string; const ACb: TSshAsyncCb; AContext: Pointer): Boolean;
var LW: TsshWriter;
begin
  if FState = tstClosed then begin if Assigned(ACb) then ACb(nil, AContext); Exit(True); end;
  LW := TsshWriter.Create(64);
  try
    LW.PutByte(SSH_MSG_DISCONNECT);
    LW.PutUInt32(AReason);
    LW.PutStringText(ADesc);
    LW.PutStringText('');
    Result := AsyncSendPacket(LW.ToBytes, ACb, AContext);
  finally LW.Free; end;
  if Result then Close;
end;

{ ---- free dispatchers ---- }

procedure AsyncTrans_OnWriteChunk(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  TAsyncSshTransport(AContext).HandleWriteChunk(AUserData, AResult);
end;

procedure AsyncTrans_OnHeaderChunk(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  TAsyncSshTransport(AContext).HandleHeaderChunk(AResult);
end;

procedure AsyncTrans_OnTrailerChunk(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  TAsyncSshTransport(AContext).HandleTrailerChunk(AResult);
end;

procedure AsyncTrans_OnVersionSendDone(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  TAsyncSshTransport(AContext).HandleVersionSendDone(AResult);
end;

procedure AsyncTrans_OnVersionByte(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  TAsyncSshTransport(AContext).HandleVersionByte(AResult);
end;

end.
