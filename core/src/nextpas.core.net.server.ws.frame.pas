unit nextpas.core.net.server.ws.frame;
{**
 * @desc 事件驱动（poller 就绪驱动）的 WebSocket 帧编解码原语。
 *
 *       纯状态机，无 IO、无阻塞：Decoder 增量喂入字节并产出完整帧，
 *       Encoder 按角色（server 不掩码 / client 掩码）产出线缆字节。
 *       帧级语义与 http.websocket.TWebSocketImpl（阻塞 IReader/IWriter
 *       面向应用契约）保持一致——本单元剥离了流 IO，供
 *       ITcpServerPollDrivenSession 非阻塞路径复用同一套 RFC 6455 规则。
 *       http.websocket 的校验辅助实现为私有，重构为共享同一 codec 留待
 *       后续批次；此处按阻塞实现忠实镜像（单测双向印证）。
 *
 *       B8 切片内的裁切：permessage-deflate（RSV1）一律按协议错误拒绝
 *       （压缩隶属 http.websocket 的阻塞路径，非阻塞路径留待后续）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.websocket.base;

const
  { 与 http.websocket.WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE 保持同一默认，
    ws 帧语义跨阻塞/非阻塞路径一致。 }
  NET_WS_DEFAULT_MAX_MESSAGE_SIZE = Int64(67108864);

type
  TNetWsRole = (
    nwsServer,
    nwsClient
  );

  TNetWsFrame = record
    Fin: Boolean;
    Opcode: Byte;
    Payload: TBytes;
    { 仅 Opcode = WS_OPCODE_CLOSE 时有效 }
    CloseCode: UInt16;
    CloseReason: string;
  end;

  TNetWsDecodeCode = (
    nwsDecodeNeedMore,
    nwsDecodeFrame,
    { 对端已发关闭帧：之后不再产出任何帧 }
    nwsDecodeClosed,
    nwsDecodeProtocolError,
    nwsDecodeTooLarge
  );

  TNetWsEncodeCode = (
    nwsEncodeOk,
    nwsEncodeInvalid,
    nwsEncodeTooLarge
  );

  { 增量 WS 帧解码器：喂入就绪字节，按需产出完整帧。
    角色规则：server 只收掩码帧，client 只收非掩码帧（RFC 6455 §5.3）。
    分片由解码器内部归并：非终帧原样产出（Fin=False），终帧续片产出
    聚合后的完整消息帧（Opcode 还原为起始数据帧）——与阻塞 ReadFrame 一致。
    错误为终态：协议错误 / 超限后所有后续 TryDecode 恒返回同一错误码。 }
  TNetWsFrameDecoder = record
  private
    type
      TParseStage = (
        psIdle,
        psExtLen,
        psMaskKey,
        psPayload
      );
    var
      FBuffer: TBytes;
      FStart: SizeUInt;
      FLimit: SizeUInt;
      FIsClient: Boolean;
      FMaxFrameSize: Int64;
      FMaxMessageSize: Int64;
      FStage: TParseStage;
      FFin: Boolean;
      FOpcode: Byte;
      FMasked: Boolean;
      { len7 = 126 -> 2 字节扩展长；127 -> 8 字节 }
      FExtNeed: Int32;
      FExtHave: Int32;
      FExtLen: array[0..7] of Byte;
      FMaskHave: Int32;
      FMaskKey: array[0..3] of Byte;
      FPayloadLen: UInt64;
      FPayloadPending: UInt64;
      FPayload: TBytes;
      FPayloadHave: SizeUInt;
      FFragmentOpen: Boolean;
      FFragmentOpcode: Byte;
      FFragmentSize: UInt64;
      FFragmentPayload: TBytes;
      FFragmentCap: SizeUInt;
      FProtocolError: Boolean;
      FTooLarge: Boolean;
      FClosed: Boolean;
      procedure CompactIfConsumed;
      procedure SetProtocolError;
      procedure SetTooLarge;
      procedure FinalizeFrameHeader;
      function TryStartFrame: TNetWsDecodeCode;
      procedure TryConsumePayload;
      // 分片归并：指数扩容 + 单次 Move 零拷贝，inline 摊还 O(n)；复用 bytes 语义不新增重复实现
      procedure InitFragmentPayload(const AData: TBytes); inline;
      procedure AppendFragmentPayload(const AData: TBytes); inline;
      function TakeFragmentPayload: TBytes; inline;
      function FinishFrame(out AFrame: TNetWsFrame): TNetWsDecodeCode;
  public
    class function Create(const AIsClient: Boolean = False;
      const AMaxFrameSize: Int64 = WS_MAX_FRAME_SIZE;
      const AMaxMessageSize: Int64 = NET_WS_DEFAULT_MAX_MESSAGE_SIZE): TNetWsFrameDecoder; static;
    { 保留角色与限额，清空解析/分片状态（新连接复用） }
    procedure Reset;
    procedure Feed(const ABuf: PByte; ACount: SizeUInt);
    procedure Feed(const AData: TBytes); overload;
    function TryDecode(out AFrame: TNetWsFrame): TNetWsDecodeCode;
    { 未消费缓冲字节数（调试/测试用） }
    function BufferedBytes: SizeUInt;
  end;

  { WS 帧编码器（无内部状态）。server 角色不掩码；
    client 角色按 RFC 6455 §5.3 加 4 字节随机掩码。控帧负载 >125 或
    非终控帧一律拒绝（与阻塞 WriteFrame 的 ValidateControlPayloadSize 一致）。 }
  TNetWsFrameEncoder = record
  public
    class function BuildHeader(const AOpcode: Byte; const AFin: Boolean;
      const APayloadLen: UInt64; const ARole: TNetWsRole;
      out AHeader: TBytes): TNetWsEncodeCode; static;
    class function BuildFrame(const AOpcode: Byte; const AFin: Boolean;
      const APayload: TBytes; const ARole: TNetWsRole;
      out AOut: TBytes): TNetWsEncodeCode; static;
    class function BuildCloseFrame(const ACode: UInt16; const AReason: string;
      const ARole: TNetWsRole; out AOut: TBytes): TNetWsEncodeCode; static;
  end;

implementation

uses
  nextpas.core.bytes,
  nextpas.core.text.utf8,
  nextpas.core.tls.random;

function WsIsValidOpcode(const AOpcode: Byte): Boolean;
begin
  case AOpcode of
    Byte(WS_OPCODE_CONTINUATION), Byte(WS_OPCODE_TEXT), Byte(WS_OPCODE_BINARY),
    Byte(WS_OPCODE_CLOSE), Byte(WS_OPCODE_PING), Byte(WS_OPCODE_PONG):
      Result := True;
  else
    Result := False;
  end;
end;

function WsIsControlOpcode(const AOpcode: Byte): Boolean;
begin
  Result := AOpcode >= $08;
end;

function WsIsValidCloseCode(const ACode: UInt16): Boolean;
begin
  Result :=
    (ACode >= 1000) and
    (ACode < 5000) and
    (ACode <> 1004) and
    (ACode <> 1005) and
    (ACode <> 1006) and
    (ACode <> 1015);
end;

{ 与阻塞 impl 的 ValidateClosePayload 同一规则；失败返回 False（终态错误）。 }
function WsValidateClosePayload(const APayload: TBytes): Boolean;
var
  LCode: UInt16;
begin
  if Length(APayload) = 0 then
    Exit(True);
  if Length(APayload) = 1 then
    Exit(False);
  LCode := (UInt16(APayload[0]) shl 8) or UInt16(APayload[1]);
  if not WsIsValidCloseCode(LCode) then
    Exit(False);
  if (Length(APayload) > 2) and
     (not UTF8IsValid(PByte(@APayload[2]), SizeUInt(Length(APayload) - 2))) then
    Exit(False);
  Result := True;
end;

{ 与阻塞 impl 的 ValidateTextPayload 同一规则（组帧后整段校验）。 }
function WsIsValidTextPayload(const APayload: TBytes): Boolean;
begin
  if Length(APayload) = 0 then
    Exit(True);
  Result := UTF8IsValid(PByte(@APayload[0]), SizeUInt(Length(APayload)));
end;

function WsSizeExceedsLimit(const ASize: UInt64; const ALimit: Int64): Boolean;
begin
  Result := (ALimit > 0) and (ASize > UInt64(ALimit));
end;

function WsCombinedSizeExceedsLimit(const ACurrent, AAdd: UInt64;
  const ALimit: Int64): Boolean;
begin
  if ALimit <= 0 then
    Exit(False);
  if AAdd > UInt64(ALimit) then
    Exit(True);
  if ACurrent > UInt64(ALimit) - AAdd then
    Exit(True);
  Result := False;
end;

class function TNetWsFrameDecoder.Create(const AIsClient: Boolean;
  const AMaxFrameSize: Int64;
  const AMaxMessageSize: Int64): TNetWsFrameDecoder;
begin
  Result := Default(TNetWsFrameDecoder);
  Result.FIsClient := AIsClient;
  Result.FMaxFrameSize := AMaxFrameSize;
  Result.FMaxMessageSize := AMaxMessageSize;
end;

procedure TNetWsFrameDecoder.Reset;
begin
  FBuffer := nil;
  FStart := 0;
  FLimit := 0;
  FStage := psIdle;
  FFin := False;
  FOpcode := 0;
  FMasked := False;
  FExtNeed := 0;
  FExtHave := 0;
  FillChar(FExtLen, SizeOf(FExtLen), 0);
  FMaskHave := 0;
  FillChar(FMaskKey, SizeOf(FMaskKey), 0);
  FPayloadLen := 0;
  FPayloadPending := 0;
  FPayload := nil;
  FPayloadHave := 0;
  FFragmentOpen := False;
  FFragmentOpcode := 0;
  FFragmentSize := 0;
  FFragmentPayload := nil;
  FFragmentCap := 0;
  FProtocolError := False;
  FTooLarge := False;
  FClosed := False;
end;

function TNetWsFrameDecoder.BufferedBytes: SizeUInt;
begin
  Result := FLimit - FStart;
end;

procedure TNetWsFrameDecoder.CompactIfConsumed;
var
  LRoom: SizeUInt;
begin
  LRoom := FLimit - FStart;
  if LRoom = 0 then
  begin
    FStart := 0;
    FLimit := 0;
    SetLength(FBuffer, 0);
    Exit;
  end;
  if FStart > 0 then
  begin
    Move(FBuffer[FStart], FBuffer[0], LRoom);
    FStart := 0;
    FLimit := LRoom;
    SetLength(FBuffer, LRoom);
  end;
end;

procedure TNetWsFrameDecoder.SetProtocolError;
begin
  FProtocolError := True;
  FStage := psPayload; { 停表：后续 TryDecode 直接短路 }
end;

procedure TNetWsFrameDecoder.SetTooLarge;
begin
  FTooLarge := True;
  FStage := psPayload;
end;

procedure TNetWsFrameDecoder.Feed(const ABuf: PByte; ACount: SizeUInt);
var
  LNewLen: SizeUInt;
begin
  if ACount = 0 then
    Exit;
  { 背压护栏：默认限额下缓冲超出一帧上限视为协议错误（防无界增长）；
    限额 <=0 表示不限帧大小，此时不设缓冲护栏（配置自担风险，与阻塞实现一致）。 }
  if FMaxFrameSize > 0 then
  begin
    if BufferedBytes > SizeUInt(FMaxFrameSize) + 128 then
    begin
      SetProtocolError;
      Exit;
    end;
  end;
  LNewLen := FLimit + ACount;
  if LNewLen > SizeUInt(Length(FBuffer)) then
    SetLength(FBuffer, LNewLen * 2);
  Move(ABuf^, FBuffer[FLimit], ACount);
  Inc(FLimit, ACount);
end;

procedure TNetWsFrameDecoder.Feed(const AData: TBytes);
begin
  if Length(AData) > 0 then
    Feed(PByte(@AData[0]), SizeUInt(Length(AData)));
end;

{ 帧头解析完毕（长度/掩码权已知）后统一做限额校验并进入负载阶段。 }
procedure TNetWsFrameDecoder.FinalizeFrameHeader;
begin
  if WsIsControlOpcode(FOpcode) and (FPayloadLen > WS_MAX_CONTROL_PAYLOAD) then
  begin
    SetProtocolError;
    Exit;
  end;
  if WsSizeExceedsLimit(FPayloadLen, FMaxFrameSize) then
  begin
    SetTooLarge;
    Exit;
  end;
  if FPayloadLen > UInt64(High(SizeInt)) then
  begin
    SetTooLarge;
    Exit;
  end;
  if FOpcode in [Byte(WS_OPCODE_TEXT), Byte(WS_OPCODE_BINARY)] then
  begin
    if WsSizeExceedsLimit(FPayloadLen, FMaxMessageSize) then
    begin
      SetTooLarge;
      Exit;
    end;
  end
  else if FOpcode = Byte(WS_OPCODE_CONTINUATION) then
  begin
    if WsCombinedSizeExceedsLimit(FFragmentSize, FPayloadLen, FMaxMessageSize) then
    begin
      SetTooLarge;
      Exit;
    end;
  end;

  if FPayloadLen > 0 then
  begin
    SetLength(FPayload, SizeUInt(FPayloadLen));
    FPayloadHave := 0;
    FPayloadPending := FPayloadLen;
  end
  else
  begin
    FPayload := nil;
    FPayloadHave := 0;
    FPayloadPending := 0;
  end;

  if FMasked then
    FStage := psMaskKey
  else
    FStage := psPayload;
end;

{ 推进帧头解析（psIdle / psExtLen / psMaskKey 三个阶段），可能因缺字节
  提前返回；全部完成后经 FinalizeFrameHeader 进入 psPayload。 }
function TNetWsFrameDecoder.TryStartFrame: TNetWsDecodeCode;
var
  LAvail: SizeUInt;
  LNeed: Int32;
  LValue: UInt64;
  LI: Int32;
begin
  Result := nwsDecodeNeedMore;

  if FStage = psIdle then
  begin
    LAvail := BufferedBytes;
    if LAvail < 2 then
      Exit;
    FFin := (FBuffer[FStart] and $80) <> 0;
    if (FBuffer[FStart] and $40) <> 0 then
    begin
      SetProtocolError;
      Exit(nwsDecodeProtocolError);
    end;
    if (FBuffer[FStart] and $30) <> 0 then
    begin
      SetProtocolError;
      Exit(nwsDecodeProtocolError);
    end;
    FOpcode := FBuffer[FStart] and $0F;
    if not WsIsValidOpcode(FOpcode) then
    begin
      SetProtocolError;
      Exit(nwsDecodeProtocolError);
    end;
    if WsIsControlOpcode(FOpcode) and (not FFin) then
    begin
      SetProtocolError;
      Exit(nwsDecodeProtocolError);
    end;
    FMasked := (FBuffer[FStart + 1] and $80) <> 0;
    FPayloadLen := FBuffer[FStart + 1] and $7F;
    if (FOpcode = Byte(WS_OPCODE_CONTINUATION)) and (not FFragmentOpen) then
    begin
      SetProtocolError;
      Exit(nwsDecodeProtocolError);
    end;
    if (FOpcode in [Byte(WS_OPCODE_TEXT), Byte(WS_OPCODE_BINARY)]) and
       FFragmentOpen then
    begin
      SetProtocolError;
      Exit(nwsDecodeProtocolError);
    end;
    if FIsClient then
    begin
      { client 端只收服务端非掩码帧 }
      if FMasked then
      begin
        SetProtocolError;
        Exit(nwsDecodeProtocolError);
      end;
    end
    else
    begin
      { server 端只收客户端掩码帧（RFC 6455 §5.3） }
      if not FMasked then
      begin
        SetProtocolError;
        Exit(nwsDecodeProtocolError);
      end;
    end;
    Inc(FStart, 2);
    FExtNeed := 0;
    FExtHave := 0;
    FMaskHave := 0;
    case FPayloadLen of
      126:
        begin
          FExtNeed := 2;
          FExtHave := 0;
          FStage := psExtLen;
        end;
      127:
        begin
          FExtNeed := 8;
          FExtHave := 0;
          FStage := psExtLen;
        end;
    else
      FinalizeFrameHeader;
    end;
    { 126/127 走下方 psExtLen 分支；否则 FinalizeFrameHeader 已把
      阶段切到 psMaskKey/psPayload }
  end;

  if FStage = psExtLen then
  begin
    LAvail := BufferedBytes;
    LNeed := FExtNeed - FExtHave;
    if LAvail < SizeUInt(LNeed) then
    begin
      LNeed := Int32(LAvail);
      Move(FBuffer[FStart], FExtLen[FExtHave], SizeUInt(LNeed));
      Inc(FExtHave, LNeed);
      Inc(FStart, SizeUInt(LNeed));
      Exit;
    end;
    Move(FBuffer[FStart], FExtLen[FExtHave], SizeUInt(LNeed));
    Inc(FStart, SizeUInt(LNeed));
    FExtHave := FExtNeed;
    if FExtNeed = 2 then
    begin
      LValue := (UInt64(FExtLen[0]) shl 8) or UInt64(FExtLen[1]);
      if LValue < 126 then
      begin
        SetProtocolError;
        Exit(nwsDecodeProtocolError);
      end;
    end
    else
    begin
      if (FExtLen[0] and $80) <> 0 then
      begin
        { RFC 6455 §5.2: 64 位长度最高位必须为 0 }
        SetProtocolError;
        Exit(nwsDecodeProtocolError);
      end;
      LValue := 0;
      for LI := 0 to 7 do
        LValue := (LValue shl 8) or UInt64(FExtLen[LI]);
      if LValue < 65536 then
      begin
        SetProtocolError;
        Exit(nwsDecodeProtocolError);
      end;
    end;
    FPayloadLen := LValue;
    FinalizeFrameHeader;
  end;

  if FStage = psMaskKey then
  begin
    LAvail := BufferedBytes;
    LNeed := 4 - FMaskHave;
    if LAvail < SizeUInt(LNeed) then
    begin
      LNeed := Int32(LAvail);
      Move(FBuffer[FStart], FMaskKey[FMaskHave], SizeUInt(LNeed));
      Inc(FMaskHave, LNeed);
      Inc(FStart, SizeUInt(LNeed));
      Exit;
    end;
    Move(FBuffer[FStart], FMaskKey[FMaskHave], SizeUInt(LNeed));
    Inc(FStart, SizeUInt(LNeed));
    FMaskHave := 4;
    FStage := psPayload;
  end;
end;

{ 尽量消费负载字节到 FPayload（掩码帧同步解掩码）。 }
procedure TNetWsFrameDecoder.TryConsumePayload;
var
  LAvail: SizeUInt;
  LTake: UInt64;
  LI: SizeUInt;
  LOff: SizeUInt;
begin
  LAvail := BufferedBytes;
  { pending=0 时若还进入本过程说明状态机失步，直接退出避免
    LOff-1 下溢后越界读 FPayload }
  if (LAvail = 0) or (FPayloadPending = 0) then
    Exit;
  LTake := FPayloadPending;
  if LTake > LAvail then
    LTake := LAvail;
  LOff := SizeUInt(LTake);
  if FMasked then
  begin
    for LI := 0 to LOff - 1 do
      FPayload[FPayloadHave + LI] :=
        FBuffer[FStart + LI] xor FMaskKey[(FPayloadHave + LI) mod 4];
  end
  else
    Move(FBuffer[FStart], FPayload[FPayloadHave], LOff);
  Inc(FStart, LOff);
  Inc(FPayloadHave, LOff);
  Dec(FPayloadPending, LTake);
end;

{ 分片缓冲：指数扩容摊还 O(n)，Move 零拷贝追加；inline 降低调用开销。 }
procedure TNetWsFrameDecoder.InitFragmentPayload(const AData: TBytes); inline;
var
  LLen: SizeUInt;
  LCap: SizeUInt;
begin
  LLen := Length(AData);
  FFragmentSize := LLen;
  if LLen = 0 then
  begin
    FFragmentCap := 0;
    FFragmentPayload := nil;
    Exit;
  end;
  LCap := LLen;
  if LCap < 256 then
    LCap := 256
  else
    LCap := LCap * 2;
  if LCap < LLen then
    LCap := LLen;
  FFragmentCap := LCap;
  SetLength(FFragmentPayload, LCap);
  Move(AData[0], FFragmentPayload[0], LLen);
end;

procedure TNetWsFrameDecoder.AppendFragmentPayload(const AData: TBytes); inline;
var
  LAdd: SizeUInt;
  LNeed: UInt64;
  LNewCap: SizeUInt;
begin
  LAdd := Length(AData);
  if LAdd = 0 then
    Exit;
  LNeed := FFragmentSize + UInt64(LAdd);
  if LNeed > FFragmentCap then
  begin
    LNewCap := FFragmentCap;
    if LNewCap < 256 then
      LNewCap := 256;
    while LNewCap < LNeed do
    begin
      if LNewCap <= High(SizeUInt) div 2 then
        LNewCap := LNewCap * 2
      else
      begin
        LNewCap := SizeUInt(LNeed);
        Break;
      end;
    end;
    SetLength(FFragmentPayload, LNewCap);
    FFragmentCap := LNewCap;
  end;
  Move(AData[0], FFragmentPayload[SizeUInt(FFragmentSize)], LAdd);
  FFragmentSize := LNeed;
end;

function TNetWsFrameDecoder.TakeFragmentPayload: TBytes; inline;
begin
  if FFragmentSize = 0 then
  begin
    Result := nil;
    FFragmentPayload := nil;
    FFragmentCap := 0;
    FFragmentOpen := False;
    FFragmentOpcode := 0;
    Exit;
  end;
  SetLength(FFragmentPayload, SizeUInt(FFragmentSize));
  FFragmentCap := SizeUInt(FFragmentSize);
  Result := FFragmentPayload;
  FFragmentPayload := nil;
  FFragmentCap := 0;
  FFragmentSize := 0;
  FFragmentOpen := False;
  FFragmentOpcode := 0;
end;

{ 当前帧整帧负载齐备后组装并走分片归并；与阻塞 ReadFrame 返回语义一致。
  组装的帧写入 AFrame，返回码指示后续状态。 }
function TNetWsFrameDecoder.FinishFrame(out AFrame: TNetWsFrame): TNetWsDecodeCode;
begin
  Result := nwsDecodeNeedMore;
  AFrame := Default(TNetWsFrame);
  AFrame.Fin := FFin;
  AFrame.Opcode := FOpcode;
  AFrame.Payload := FPayload;

  FPayload := nil;
  FPayloadHave := 0;

  if FOpcode = Byte(WS_OPCODE_CLOSE) then
  begin
    if not WsValidateClosePayload(AFrame.Payload) then
    begin
      SetProtocolError;
      Exit(nwsDecodeProtocolError);
    end;
    FClosed := True;
    if Length(AFrame.Payload) >= 2 then
      AFrame.CloseCode := (UInt16(AFrame.Payload[0]) shl 8) or
        UInt16(AFrame.Payload[1]);
    if Length(AFrame.Payload) > 2 then
    begin
      SetLength(AFrame.CloseReason, Length(AFrame.Payload) - 2);
      Move(AFrame.Payload[2], AFrame.CloseReason[1],
        SizeUInt(Length(AFrame.Payload) - 2));
    end;
    { close 帧本身以 FRAME 产出（承载关闭信息）；此后再喂字节返回 Closed }
    Exit(nwsDecodeFrame);
  end;

  if FOpcode in [Byte(WS_OPCODE_TEXT), Byte(WS_OPCODE_BINARY)] then
  begin
    if FFin then
    begin
      if (FOpcode = Byte(WS_OPCODE_TEXT)) and
         (not WsIsValidTextPayload(AFrame.Payload)) then
      begin
        SetProtocolError;
        Exit(nwsDecodeProtocolError);
      end;
      Exit(nwsDecodeFrame);
    end;
    { 非终数据帧：开分片（阻塞 ReadFrame 同款），原样产出；指数预留摊还 O(n) }
    FFragmentOpen := True;
    FFragmentOpcode := FOpcode;
    InitFragmentPayload(AFrame.Payload);
    Exit(nwsDecodeFrame);
  end;

  if FOpcode = Byte(WS_OPCODE_CONTINUATION) then
  begin
    AppendFragmentPayload(AFrame.Payload);
    if FFin then
    begin
      { 终片：归并成全消息（Opcode 还原为起始数据帧）；Take 截断并移交所有权，零拷贝 }
      AFrame.Opcode := FFragmentOpcode;
      AFrame.Payload := TakeFragmentPayload;
      AFrame.Fin := True;
      if (AFrame.Opcode = Byte(WS_OPCODE_TEXT)) and
         (not WsIsValidTextPayload(AFrame.Payload)) then
      begin
        SetProtocolError;
        Exit(nwsDecodeProtocolError);
      end;
      Exit(nwsDecodeFrame);
    end;
    { 非终续片：原样产出（阻塞 ReadFrame 同款） }
    Exit(nwsDecodeFrame);
  end;

  { 控帧（ping/pong）：直接产出 }
  Exit(nwsDecodeFrame);
end;

function TNetWsFrameDecoder.TryDecode(out AFrame: TNetWsFrame): TNetWsDecodeCode;
var
  LCode: TNetWsDecodeCode;
begin
  AFrame := Default(TNetWsFrame);
  CompactIfConsumed;
  if FProtocolError then
    Exit(nwsDecodeProtocolError);
  if FClosed then
    Exit(nwsDecodeClosed);
  if FTooLarge then
    Exit(nwsDecodeTooLarge);

  { 单次调用推进尽量远的解析状态：
    - 帧完整时产出该帧并把阶段复位为 psIdle（分片/错误状态跨帧保留，
      帧内字段由下一次 psIdle 解析重写）；
    - 某阶段无可推进（帧缺字节）或缓冲耗尽即返回 NeedMore。 }
  repeat
    LCode := nwsDecodeNeedMore;
    case FStage of
      psIdle, psExtLen, psMaskKey:
        LCode := TryStartFrame;
      psPayload:
        ; { 负载消费在下方统一处理 }
    end;
    if FProtocolError then
      Exit(nwsDecodeProtocolError);
    if FTooLarge then
      Exit(nwsDecodeTooLarge);

    if FStage = psPayload then
    begin
      TryConsumePayload;
      if FPayloadPending = 0 then
      begin
        LCode := FinishFrame(AFrame);
        FStage := psIdle;
      end
      else
        LCode := nwsDecodeNeedMore;
    end;
    if FProtocolError then
      Exit(nwsDecodeProtocolError);
    if FTooLarge then
      Exit(nwsDecodeTooLarge);
  until (LCode <> nwsDecodeNeedMore) or (FStage <> psPayload) or
        (BufferedBytes = 0);
  Result := LCode;
end;

{ Encoder }

class function TNetWsFrameEncoder.BuildHeader(const AOpcode: Byte;
  const AFin: Boolean; const APayloadLen: UInt64; const ARole: TNetWsRole;
  out AHeader: TBytes): TNetWsEncodeCode;
var
  LIndex: SizeUInt;
  LMask: array[0..3] of Byte;
begin
  AHeader := nil;
  if not WsIsValidOpcode(AOpcode) then
    Exit(nwsEncodeInvalid);
  if WsIsControlOpcode(AOpcode) then
  begin
    if (not AFin) or (APayloadLen > WS_MAX_CONTROL_PAYLOAD) then
      Exit(nwsEncodeInvalid);
  end;
  if APayloadLen > UInt64(High(SizeInt)) then
    Exit(nwsEncodeTooLarge);

  if APayloadLen < 126 then
  begin
    SetLength(AHeader, 2);
    AHeader[1] := Byte(APayloadLen);
  end
  else if APayloadLen < 65536 then
  begin
    SetLength(AHeader, 4);
    AHeader[1] := 126;
    AHeader[2] := Byte(APayloadLen shr 8);
    AHeader[3] := Byte(APayloadLen);
  end
  else
  begin
    SetLength(AHeader, 10);
    AHeader[1] := 127;
    AHeader[2] := Byte(UInt64(APayloadLen) shr 56);
    AHeader[3] := Byte(UInt64(APayloadLen) shr 48);
    AHeader[4] := Byte(UInt64(APayloadLen) shr 40);
    AHeader[5] := Byte(UInt64(APayloadLen) shr 32);
    AHeader[6] := Byte(APayloadLen shr 24);
    AHeader[7] := Byte(APayloadLen shr 16);
    AHeader[8] := Byte(APayloadLen shr 8);
    AHeader[9] := Byte(APayloadLen);
  end;
  AHeader[0] := $80 or AOpcode;
  if not AFin then
    AHeader[0] := AHeader[0] and not $80;

  if ARole = nwsClient then
  begin
    AHeader[1] := AHeader[1] or $80;
    SecureRandomBytes(@LMask[0], 4);
    LIndex := SizeUInt(Length(AHeader));
    SetLength(AHeader, LIndex + 4);
    Move(LMask[0], AHeader[LIndex], 4);
  end;
  Result := nwsEncodeOk;
end;

class function TNetWsFrameEncoder.BuildFrame(const AOpcode: Byte;
  const AFin: Boolean; const APayload: TBytes; const ARole: TNetWsRole;
  out AOut: TBytes): TNetWsEncodeCode;
var
  LHeader: TBytes;
  LPLen: UInt64;
  LIndex: SizeUInt;
  LMaskOff: SizeUInt;
  LI: SizeUInt;
begin
  AOut := nil;
  LPLen := UInt64(Length(APayload));
  Result := BuildHeader(AOpcode, AFin, LPLen, ARole, LHeader);
  if Result <> nwsEncodeOk then
    Exit;
  LIndex := SizeUInt(Length(LHeader));
  SetLength(AOut, LIndex + SizeUInt(LPLen));
  Move(LHeader[0], AOut[0], LIndex);
  if LPLen > 0 then
  begin
    if ARole = nwsClient then
    begin
      { 掩码键位于 2/4/10 字节头之后 }
      LMaskOff := 2;
      if LPLen >= 126 then
      begin
        if LPLen < 65536 then
          LMaskOff := 4
        else
          LMaskOff := 10;
      end;
      for LI := 0 to SizeUInt(LPLen) - 1 do
        AOut[LIndex + LI] := APayload[LI] xor LHeader[LMaskOff + (LI mod 4)];
    end
    else
      Move(APayload[0], AOut[LIndex], SizeUInt(LPLen));
  end;
end;

class function TNetWsFrameEncoder.BuildCloseFrame(const ACode: UInt16;
  const AReason: string; const ARole: TNetWsRole;
  out AOut: TBytes): TNetWsEncodeCode;
var
  LPayload: TBytes;
begin
  AOut := nil;
  { 与阻塞 impl 的 ValidateClosePayload 同一规则；reason 上限 123 保证
    总负载 <= 125（2 字节 code + 123 字节 reason）。 }
  if not WsIsValidCloseCode(ACode) then
    Exit(nwsEncodeInvalid);
  if (Length(AReason) > 0) and
     (not UTF8IsValid(PByte(@AReason[1]), SizeUInt(Length(AReason)))) then
    Exit(nwsEncodeInvalid);
  if Length(AReason) > 123 then
    Exit(nwsEncodeInvalid);
  SetLength(LPayload, 2 + Length(AReason));
  LPayload[0] := Byte(ACode shr 8);
  LPayload[1] := Byte(ACode and $FF);
  if Length(AReason) > 0 then
    Move(AReason[1], LPayload[2], SizeUInt(Length(AReason)));
  Result := BuildFrame(Byte(WS_OPCODE_CLOSE), True, LPayload, ARole, AOut);
end;

end.
