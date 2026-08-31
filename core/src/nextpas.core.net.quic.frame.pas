unit nextpas.core.net.quic.frame;

{**
 * nextpas.core.net.quic.frame — QUIC 帧族编解码（RFC 9000 §12.4/§19）
 *
 * 最小面（hysteria2 客户端前置，Q3）：PADDING / PING / ACK(0x02+0x03) /
 * CRYPTO / STREAM / NEW_CONNECTION_ID / RETIRE_CONNECTION_ID /
 * PATH_CHALLENGE / PATH_RESPONSE / CONNECTION_CLOSE(0x1c+0x1d) /
 * HANDSHAKE_DONE。
 * Q5 扩面：流控与流管理族（RFC 9000 §19.4-19.5/§19.9-19.14）——
 * RESET_STREAM / STOP_SENDING / MAX_DATA / MAX_STREAM_DATA /
 * MAX_STREAMS(0x12+0x13) / DATA_BLOCKED / STREAM_DATA_BLOCKED /
 * STREAMS_BLOCKED(0x16+0x17)。
 *
 * fail-closed 语义（RFC 9000 §12.4 原文定案）：
 * - "MUST treat the receipt of a frame of unknown type as a connection
 *   error of type FRAME_ENCODING_ERROR"——未知类型一律拒；未实现的
 *   RFC 已定义类型（NEW_TOKEN 0x07 等）同样返回 False；
 * - 结构非法（截断、LEN 越界、NCID 长度 ∉[1,20]、ACK range 下溢、
 *   range 数超界）一律 False，不产出半解析态。
 *
 * 解码零拷贝：STREAM/CRYPTO 数据与 CLOSE reason 不复制，以
 * DataOfs/DataLen（ReasonOfs/ReasonLen）区间指向输入载荷缓冲，
 * 消费方须在缓冲生命周期内读取。
 *
 * ACK 明细二次拉取：TQuicFrame 只承载 LargestAcked/DelayRaw/RangeCount，
 * ranges 经 TryQuicAckRangesParse 拉取（迭代公式 RFC §19.3.1：
 * largest = previous_smallest - gap - 2）。DelayRaw 为线上 raw 值，
 * 缩放（×2^exponent，exponent 取自对端 transport params）归调用方。
 *
 * @note Thread safety: 纯函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.quic.varint;

const
  { 帧类型常量（RFC 9000 §12.4 Table 3 + §19） }
  cQfPadding = $00;
  cQfPing = $01;
  cQfAckV1 = $02;          { 无 ECN counts }
  cQfAckEcn = $03;         { 带 ECN counts }
  cQfResetStream = $04;    { §19.4 }
  cQfStopSending = $05;    { §19.5 }
  cQfCrypto = $06;
  cQfNewToken = $07;       { §19.7 }
  cQfMaxData = $10;        { §19.9 }
  cQfMaxStreamData = $11;  { §19.10 }
  cQfMaxStreamsBidi = $12; { §19.11 双向 }
  cQfMaxStreamsUni = $13;  { §19.11 单向 }
  cQfDataBlocked = $14;    { §19.12 }
  cQfStreamDataBlocked = $15;   { §19.13 }
  cQfStreamsBlockedBidi = $16;  { §19.14 双向 }
  cQfStreamsBlockedUni = $17;   { §19.14 单向 }
  cQfDatagram = $30;            { RFC 9221 §4：LEN=0 数据延伸到包尾 }
  cQfDatagramWithLength = $31;  { RFC 9221 §4：LEN=1 显式长度 }
  cQfStreamBase = $08;     { 0x08..0x0f：OFF=$04 LEN=$02 FIN=$01 }
  cQfNewConnectionId = $18;
  cQfRetireConnectionId = $19;
  cQfPathChallenge = $1a;
  cQfPathResponse = $1b;
  cQfConnCloseTransport = $1c;
  cQfConnCloseApp = $1d;
  cQfHandshakeDone = $1e;

  { STREAM 类型位（§19.8） }
  cQfStreamOffBit = $04;
  cQfStreamLenBit = $02;
  cQfStreamFinBit = $01;

  { 解码侧 ACK ranges 上界：单帧 range 数超过即拒收（S2 有界纪律；
    合法实现受包尺寸约束远低于此值） }
  cQuicMaxAckRanges = 64;

  { NCID 约束（§19.15：Length <1 或 >20 为 FRAME_ENCODING_ERROR） }
  cQuicMaxCidLen = 20;

type
  TQuicFrameKind = (
    qfkPadding, qfkPing, qfkAck, qfkCrypto, qfkNewToken, qfkStream,
    qfkResetStream, qfkStopSending,
    qfkMaxData, qfkMaxStreamData, qfkMaxStreams,
    qfkDataBlocked, qfkStreamDataBlocked, qfkStreamsBlocked,
    qfkNewConnectionId, qfkRetireConnectionId, qfkPathChallenge,
    qfkPathResponse, qfkConnectionClose, qfkHandshakeDone, qfkDatagram);

  { ACK range：闭区间 [Lo..Hi]，降序排列 }
  TQuicAckRange = record
    Lo: UInt64;
    Hi: UInt64;
  end;
  TQuicAckRangeArray = array of TQuicAckRange;

  TQuicCloseSpace = (qcsTransport, qcsApplication);

  TQuicFrame = record
    Kind: TQuicFrameKind;
    FrameType: UInt64;        { 原始类型值（STREAM 位型保留原样） }
    Consumed: Integer;        { 本帧线上总字节数 }

    { STREAM / CRYPTO：数据区在输入载荷内的零拷贝区间 }
    StreamId: UInt64;
    Offset: UInt64;
    DataOfs: Integer;
    DataLen: Integer;
    Fin: Boolean;

    { ACK raw 字段 }
    LargestAcked: UInt64;
    AckDelayRaw: UInt64;
    AckExtraCount: Integer;   { 额外 range 数（不含 first） }
    FirstAckRange: UInt64;    { largest 之前连续确认数 }
    EcnEct0: UInt64;          { 仅 0x03 变体携带 }
    EcnEct1: UInt64;
    EcnCe: UInt64;

    { NEW_CONNECTION_ID }
    SeqNum: UInt64;
    RetirePriorTo: UInt64;
    CidLen: Integer;
    Cid: array[0..cQuicMaxCidLen - 1] of Byte;
    ResetToken: array[0..15] of Byte;

    { CONNECTION_CLOSE }
    CloseSpace: TQuicCloseSpace;
    ErrorCode: UInt64;
    CloseFrameType: UInt64;   { 仅 transport 形态；app 形态恒 0 }
    ReasonOfs: Integer;
    ReasonLen: Integer;

    { RETIRE_CONNECTION_ID 序号 / PATH_* 数据区（8B 零拷贝） }
    RetireSeq: UInt64;
    PathDataOfs: Integer;

    { 流控/流管理族（Q5）：MaxValue 承载 MAX_DATA/MAX_STREAM_DATA/
      MAX_STREAMS/DATA_BLOCKED/STREAM_DATA_BLOCKED/STREAMS_BLOCKED 的
      「Maximum ...」字段；FinalSize 仅 RESET_STREAM（§19.4）；
      ErrorCode 复用承载 RESET/STOP 的应用错误码 }
    MaxValue: UInt64;
    FinalSize: UInt64;
  end;

{** @desc 从 APayload[AOffset..AEnd_) 解析一帧；失败返回 False。
 *       ACK 帧的 ranges 一并消费进 ARanges（Consumed 含全部续段），
 *       载荷迭代语义由此保持完整 *}
function TryQuicFrameParse(const APayload: TBytes; AOffset, AEnd_: Integer;
  out AFrame: TQuicFrame;
  out ARanges: TQuicAckRangeArray): Boolean; overload;

{** @desc 同上；不关心 ACK 明细时使用 *}
function TryQuicFrameParse(const APayload: TBytes; AOffset, AEnd_: Integer;
  out AFrame: TQuicFrame): Boolean; overload;

{**
 * @desc 独立拉取 ACK 帧的 ranges 续段（gap/len 交替，不含 first）。
 *       AOffset 为帧头（含 FirstAckRange 与 ECN 之前的续段起点）；
 *       迭代公式 RFC §19.3.1：largest = previous_smallest - gap - 2。
 *       AExtraCount > cQuicMaxAckRanges 拒绝。输出闭区间降序、含 first
 *       共 AExtraCount+1 项。
 *}
function TryQuicAckRangesParse(const APayload: TBytes; AOffset, AEnd_: Integer;
  ALargestAcked, AFirstRange: UInt64; AExtraCount: Integer;
  out ARanges: TQuicAckRangeArray; out ACount: Integer): Boolean;

procedure QuicPaddingAppend(var ABuf: TBytes; ACount: Integer);
procedure QuicPingAppend(var ABuf: TBytes);
procedure QuicHandshakeDoneAppend(var ABuf: TBytes);

{** @desc ACK 编码：ARanges 降序、互斥、相邻间隔 ≥1 未确认包，
 *       且首 range 上沿必须等于 ALargestAcked；违反返回 False 不写入 *}
function QuicAckAppend(var ABuf: TBytes; ALargestAcked, ADelayRaw: UInt64;
  const ARanges: array of TQuicAckRange): Boolean;

{** @desc CRYPTO 帧：type + offset + length + data 全带形态 *}
procedure QuicCryptoAppend(var ABuf: TBytes; AOffset: UInt64;
  const AData: TBytes);

{** @desc STREAM 帧：AWantLen=False 时 ALen 必须为实际数据长度且帧即
 *       包尾帧（LEN 位省略=线上语义延伸到包尾）；AWantLen=True 显式带长 *}
procedure QuicStreamAppend(var ABuf: TBytes; AStreamId, AOffset: UInt64;
  const AData: TBytes; AFin, AWantLen: Boolean);

{ ---- 流控/流管理族编码助手（§19.4-§19.5/§19.9-§19.14，Q5）---- }
procedure QuicResetStreamAppend(var ABuf: TBytes; AStreamId,
  AErrorCode, AFinalSize: UInt64);
procedure QuicStopSendingAppend(var ABuf: TBytes; AStreamId,
  AErrorCode: UInt64);
procedure QuicMaxDataAppend(var ABuf: TBytes; AMaxData: UInt64);
procedure QuicMaxStreamDataAppend(var ABuf: TBytes; AStreamId,
  AMaxStreamData: UInt64);
procedure QuicMaxStreamsAppend(var ABuf: TBytes; ABidi: Boolean;
  AMaxStreams: UInt64);
procedure QuicDataBlockedAppend(var ABuf: TBytes; AMaxData: UInt64);
procedure QuicStreamDataBlockedAppend(var ABuf: TBytes; AStreamId,
  AMaxStreamData: UInt64);
procedure QuicStreamsBlockedAppend(var ABuf: TBytes; ABidi: Boolean;
  AMaxStreams: UInt64);

{** @desc DATAGRAM（RFC 9221 §4）编码：0x31 WITH_LENGTH 形态，可与其他
 *       帧共包；空数据报合法 *}
procedure QuicDatagramAppend(var ABuf: TBytes; const AData: TBytes);

{** @desc 0x30 裸形态：数据延伸至包尾，仅可作包内最后一帧 *}
procedure QuicDatagramTailAppend(var ABuf: TBytes; const AData: TBytes);

{** @desc ACidLen ∈[1,20]、AResetToken 须恰 16 元素；违反返回 False *}
function QuicNewConnectionIdAppend(var ABuf: TBytes; ASeq,
  ARetirePriorTo: UInt64; const ACid: array of Byte;
  const AResetToken: array of Byte): Boolean;

procedure QuicRetireConnectionIdAppend(var ABuf: TBytes; ASeq: UInt64);

{** @desc PATH_CHALLENGE/RESPONSE：AData 须恰 8 元素（§19.17/19.18） *}
function QuicPathChallengeAppend(var ABuf: TBytes;
  const AData: array of Byte): Boolean;
function QuicPathResponseAppend(var ABuf: TBytes;
  const AData: array of Byte): Boolean;

procedure QuicConnCloseTransportAppend(var ABuf: TBytes; AErrorCode,
  ATriggeredFrameType: UInt64; const AReason: TBytes);
procedure QuicConnCloseAppAppend(var ABuf: TBytes; AErrorCode: UInt64;
  const AReason: TBytes);

implementation

uses
  nextpas.core.bytes.ops;

procedure AppendTailBytes(var ABuf: TBytes; const ATail: TBytes); inline;
begin
  BytesAppend(ABuf, ATail);
end;

{ 内部：从 APos 读 AExtraCount 组 gap/len 续段，构建含 first 的完整
  降序 ranges；APos 推进到续段结束。迭代公式 RFC §19.3.1：
  largest = previous_smallest - gap - 2，下溢即 FRAME_ENCODING_ERROR }
function WalkAckRanges(const APayload: TBytes; var APos: Integer;
  AEnd_: Integer; ALargestAcked, AFirstRange: UInt64; AExtraCount: Integer;
  out ARanges: TQuicAckRangeArray): Boolean;
var
  LConsumed: Integer;
  LGap, LLen, LHi, LLo: UInt64;
  LI: Integer;
begin
  ARanges := nil;
  Result := False;
  if (AExtraCount < 0) or (AExtraCount > cQuicMaxAckRanges) then
    Exit;
  { first range：[largest-first .. largest]（§19.3） }
  if ALargestAcked < AFirstRange then
    Exit;
  SetLength(ARanges, AExtraCount + 1);
  ARanges[0].Hi := ALargestAcked;
  ARanges[0].Lo := ALargestAcked - AFirstRange;
  LLo := ARanges[0].Lo;

  for LI := 1 to AExtraCount do
  begin
    if not QuicVarintDecode(APayload, APos, LGap, LConsumed) then
      Exit;
    Inc(APos, LConsumed);
    if not QuicVarintDecode(APayload, APos, LLen, LConsumed) then
      Exit;
    Inc(APos, LConsumed);
    if APos > AEnd_ then
      Exit;
    if (LLo < LGap) or (LLo - LGap < 2) then
      Exit;   { previous_smallest - gap - 2 下溢 }
    LHi := LLo - LGap - 2;
    if LHi < LLen then
      Exit;
    ARanges[LI].Hi := LHi;
    ARanges[LI].Lo := LHi - LLen;
    LLo := ARanges[LI].Lo;
  end;
  Result := True;
end;

function TryQuicFrameParse(const APayload: TBytes; AOffset, AEnd_: Integer;
  out AFrame: TQuicFrame;
  out ARanges: TQuicAckRangeArray): Boolean;
var
  LPos, LConsumed: Integer;
  LType, LVal: UInt64;
begin
  AFrame := Default(TQuicFrame);
  Result := False;
  if (AOffset < 0) or (AEnd_ > Length(APayload)) or (AOffset >= AEnd_) then
    Exit;
  LPos := AOffset;
  if not QuicVarintDecode(APayload, LPos, LType, LConsumed) then
    Exit;
  Inc(LPos, LConsumed);
  AFrame.FrameType := LType;

  case LType of
    cQfPadding:
      begin
        AFrame.Kind := qfkPadding;
        AFrame.Consumed := 1;
      end;

    cQfPing:
      begin
        AFrame.Kind := qfkPing;
        AFrame.Consumed := 1;
      end;

    cQfHandshakeDone:
      begin
        AFrame.Kind := qfkHandshakeDone;
        AFrame.Consumed := 1;
      end;

    cQfAckV1, cQfAckEcn:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.LargestAcked, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if not QuicVarintDecode(APayload, LPos, AFrame.AckDelayRaw, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if not QuicVarintDecode(APayload, LPos, LVal, LConsumed) then
          Exit;
        if LVal > UInt64(High(Integer)) then
          Exit;
        Inc(LPos, LConsumed);
        AFrame.AckExtraCount := Integer(LVal);
        if not QuicVarintDecode(APayload, LPos, AFrame.FirstAckRange, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);

        { ranges 续段先于 ECN（RFC §19.3 线上布局），一并计入 Consumed }
        ARanges := nil;
        if not WalkAckRanges(APayload, LPos, AEnd_, AFrame.LargestAcked,
          AFrame.FirstAckRange, AFrame.AckExtraCount, ARanges) then
          Exit;

        if LType = cQfAckEcn then
        begin
          if not QuicVarintDecode(APayload, LPos, AFrame.EcnEct0, LConsumed) then
            Exit;
          Inc(LPos, LConsumed);
          if not QuicVarintDecode(APayload, LPos, AFrame.EcnEct1, LConsumed) then
            Exit;
          Inc(LPos, LConsumed);
          if not QuicVarintDecode(APayload, LPos, AFrame.EcnCe, LConsumed) then
            Exit;
          Inc(LPos, LConsumed);
        end;
        AFrame.Kind := qfkAck;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfCrypto:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.Offset, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if not QuicVarintDecode(APayload, LPos, LVal, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if LVal > UInt64(AEnd_ - LPos) then
          Exit;   { 声明长度越过载荷尾 }
        if AFrame.Offset > cQuicVarintMaxValue - LVal then
          Exit;   { offset+len ≤ 2^62-1（§19.6） }
        AFrame.DataOfs := LPos;
        AFrame.DataLen := Integer(LVal);
        AFrame.Kind := qfkCrypto;
        AFrame.Consumed := LPos - AOffset + AFrame.DataLen;
      end;

    cQfNewToken:
      begin
        { §19.7：varint 长度 + 不透明 token。客户端 MAY 不存储
          （本栈无重连场景）；正确消费整帧而非视为未知帧 }
        if not QuicVarintDecode(APayload, LPos, LVal, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if LVal > UInt64(AEnd_ - LPos) then
          Exit;   { 声明长度越过载荷尾 }
        Inc(LPos, Integer(LVal));
        AFrame.Kind := qfkNewToken;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfStreamBase..cQfStreamBase + 7:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.StreamId, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        AFrame.Fin := (LType and cQfStreamFinBit) <> 0;
        if (LType and cQfStreamOffBit) <> 0 then
        begin
          if not QuicVarintDecode(APayload, LPos, AFrame.Offset, LConsumed) then
            Exit;
          Inc(LPos, LConsumed);
        end
        else
          AFrame.Offset := 0;
        if (LType and cQfStreamLenBit) <> 0 then
        begin
          if not QuicVarintDecode(APayload, LPos, LVal, LConsumed) then
            Exit;
          Inc(LPos, LConsumed);
          if LVal > UInt64(AEnd_ - LPos) then
            Exit;
          AFrame.DataLen := Integer(LVal);
        end
        else
          AFrame.DataLen := AEnd_ - LPos;   { LEN 缺省=延伸到包尾（§19.8） }
        AFrame.DataOfs := LPos;
        AFrame.Kind := qfkStream;
        AFrame.Consumed := LPos - AOffset + AFrame.DataLen;
      end;

    { ---- 流控/流管理族（§19.4/§19.5/§19.9-19.14，Q5）----
      布局原文定案：
      RESET_STREAM   = 0x04 + StreamID(i) + AppErr(i) + FinalSize(i)
      STOP_SENDING   = 0x05 + StreamID(i) + AppErr(i)
      MAX_DATA       = 0x10 + Maximum Data(i)
      MAX_STREAM_DATA= 0x11 + StreamID(i) + Maximum Stream Data(i)
      MAX_STREAMS    = 0x12|0x13 + Maximum Streams(i)
      DATA_BLOCKED   = 0x14 + Maximum Data(i)
      STREAM_DATA_BLOCKED = 0x15 + StreamID(i) + Maximum Stream Data(i)
      STREAMS_BLOCKED= 0x16|0x17 + Maximum Streams(i) }
    cQfResetStream:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.StreamId, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if not QuicVarintDecode(APayload, LPos, AFrame.ErrorCode, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if not QuicVarintDecode(APayload, LPos, AFrame.FinalSize, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        AFrame.Kind := qfkResetStream;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfStopSending:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.StreamId, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if not QuicVarintDecode(APayload, LPos, AFrame.ErrorCode, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        AFrame.Kind := qfkStopSending;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfMaxData, cQfDataBlocked:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.MaxValue, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if LType = cQfMaxData then
          AFrame.Kind := qfkMaxData
        else
          AFrame.Kind := qfkDataBlocked;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfMaxStreamData, cQfStreamDataBlocked:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.StreamId, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if not QuicVarintDecode(APayload, LPos, AFrame.MaxValue, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if LType = cQfMaxStreamData then
          AFrame.Kind := qfkMaxStreamData
        else
          AFrame.Kind := qfkStreamDataBlocked;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfMaxStreamsBidi, cQfMaxStreamsUni,
    cQfStreamsBlockedBidi, cQfStreamsBlockedUni:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.MaxValue, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        case LType of
          cQfMaxStreamsBidi:     AFrame.Kind := qfkMaxStreams;
          cQfMaxStreamsUni:      AFrame.Kind := qfkMaxStreams;
          cQfStreamsBlockedBidi: AFrame.Kind := qfkStreamsBlocked;
        else
          AFrame.Kind := qfkStreamsBlocked;
        end;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfNewConnectionId:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.SeqNum, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if not QuicVarintDecode(APayload, LPos, AFrame.RetirePriorTo, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if AEnd_ - LPos < 1 then
          Exit;
        AFrame.CidLen := APayload[LPos];
        Inc(LPos);
        if (AFrame.CidLen < 1) or (AFrame.CidLen > cQuicMaxCidLen) then
          Exit;   { §19.15 fail-closed }
        if AEnd_ - LPos < AFrame.CidLen + 16 then
          Exit;
        Move(APayload[LPos], AFrame.Cid[0], AFrame.CidLen);
        Inc(LPos, AFrame.CidLen);
        Move(APayload[LPos], AFrame.ResetToken[0], 16);
        Inc(LPos, 16);
        AFrame.Kind := qfkNewConnectionId;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfRetireConnectionId:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.RetireSeq, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        AFrame.Kind := qfkRetireConnectionId;
        AFrame.Consumed := LPos - AOffset;
      end;

    cQfPathChallenge, cQfPathResponse:
      begin
        if AEnd_ - LPos < 8 then
          Exit;   { §19.17/§19.18：8 字节定长数据 }
        AFrame.PathDataOfs := LPos;
        if LType = cQfPathResponse then
          AFrame.Kind := qfkPathResponse
        else
          AFrame.Kind := qfkPathChallenge;
        AFrame.Consumed := (LPos - AOffset) + 8;
      end;

    cQfConnCloseTransport, cQfConnCloseApp:
      begin
        if not QuicVarintDecode(APayload, LPos, AFrame.ErrorCode, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if LType = cQfConnCloseTransport then
        begin
          if not QuicVarintDecode(APayload, LPos, AFrame.CloseFrameType, LConsumed) then
            Exit;
          Inc(LPos, LConsumed);
          AFrame.CloseSpace := qcsTransport;
        end
        else
          AFrame.CloseSpace := qcsApplication;
        if not QuicVarintDecode(APayload, LPos, LVal, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if LVal > UInt64(AEnd_ - LPos) then
          Exit;
        AFrame.ReasonOfs := LPos;
        AFrame.ReasonLen := Integer(LVal);
        AFrame.Kind := qfkConnectionClose;
        AFrame.Consumed := (LPos - AOffset) + AFrame.ReasonLen;
      end;
    { DATAGRAM（RFC 9221 §4）：0x30 LEN=0 数据延伸到包尾（仅限包内
      最后一帧）；0x31 显式长度可与其他帧共包。数据区零拷贝
      （DataOfs/DataLen）；空数据报合法（Length=0）。
      流控语义：不占任何流控窗口（§5.3），走拥塞控制器（§5.4） }
    cQfDatagram:
      begin
        AFrame.DataOfs := LPos;
        AFrame.DataLen := AEnd_ - LPos;
        AFrame.Consumed := AEnd_ - AOffset;
        AFrame.Kind := qfkDatagram;
      end;

    cQfDatagramWithLength:
      begin
        if not QuicVarintDecode(APayload, LPos, LVal, LConsumed) then
          Exit;
        Inc(LPos, LConsumed);
        if LVal > UInt64(AEnd_ - LPos) then
          Exit;   { 声明长度越过载荷尾 }
        AFrame.DataOfs := LPos;
        AFrame.DataLen := Integer(LVal);
        AFrame.Consumed := (LPos - AOffset) + AFrame.DataLen;
        AFrame.Kind := qfkDatagram;
      end;

  else
    Exit;   { 未知/未实现类型：fail-closed（§12.4 FRAME_ENCODING_ERROR） }
  end;

  Result := True;
end;

function TryQuicFrameParse(const APayload: TBytes; AOffset, AEnd_: Integer;
  out AFrame: TQuicFrame): Boolean;
var
  LDummy: TQuicAckRangeArray;
begin
  Result := TryQuicFrameParse(APayload, AOffset, AEnd_, AFrame, LDummy);
end;

function TryQuicAckRangesParse(const APayload: TBytes; AOffset,
  AEnd_: Integer; ALargestAcked, AFirstRange: UInt64; AExtraCount: Integer;
  out ARanges: TQuicAckRangeArray; out ACount: Integer): Boolean;
var
  LPos: Integer;
begin
  ARanges := nil;
  ACount := 0;
  if (AOffset < 0) or (AEnd_ > Length(APayload)) or (AOffset > AEnd_) then
    Exit(False);
  LPos := AOffset;
  Result := WalkAckRanges(APayload, LPos, AEnd_, ALargestAcked, AFirstRange,
    AExtraCount, ARanges);
  if Result then
    ACount := AExtraCount + 1;
end;

procedure QuicPaddingAppend(var ABuf: TBytes; ACount: Integer);
var
  LN, LI: Integer;
begin
  if ACount <= 0 then
    Exit;
  LN := Length(ABuf);
  SetLength(ABuf, LN + ACount);
  for LI := 0 to ACount - 1 do
    ABuf[LN + LI] := cQfPadding;
end;

procedure QuicPingAppend(var ABuf: TBytes);
begin
  QuicBufAppendByte(ABuf, cQfPing);
end;

procedure QuicHandshakeDoneAppend(var ABuf: TBytes);
begin
  QuicBufAppendByte(ABuf, cQfHandshakeDone);
end;

function QuicAckAppend(var ABuf: TBytes; ALargestAcked, ADelayRaw: UInt64;
  const ARanges: array of TQuicAckRange): Boolean;
var
  LI: Integer;
  LGap: UInt64;
begin
  Result := False;
  if Length(ARanges) < 1 then
    Exit;
  if Length(ARanges) - 1 > cQuicMaxAckRanges then
    Exit;
  { 首 range 上沿必须等于 largest（first range 从 largest 起算） }
  if ARanges[0].Hi <> ALargestAcked then
    Exit;
  if ARanges[0].Lo > ARanges[0].Hi then
    Exit;
  for LI := 1 to High(ARanges) do
  begin
    { 降序、互斥、间隔 ≥1 未确认包（gap 公式要求后一 range 上沿
      ≤ 前一 range 下沿减 2） }
    if ARanges[LI].Lo > ARanges[LI].Hi then
      Exit;
    if ARanges[LI].Hi + 2 > ARanges[LI - 1].Lo then
      Exit;
  end;

  QuicBufAppendByte(ABuf, cQfAckV1);
  if not QuicVarintAppend(ABuf, ALargestAcked) or
     not QuicVarintAppend(ABuf, ADelayRaw) or
     not QuicVarintAppend(ABuf, UInt64(Length(ARanges) - 1)) or
     not QuicVarintAppend(ABuf, ARanges[0].Hi - ARanges[0].Lo) then
    Exit;
  for LI := 1 to High(ARanges) do
  begin
    LGap := ARanges[LI - 1].Lo - ARanges[LI].Hi - 2;
    if not QuicVarintAppend(ABuf, LGap) or
       not QuicVarintAppend(ABuf, ARanges[LI].Hi - ARanges[LI].Lo) then
      Exit;
  end;
  Result := True;
end;

procedure QuicCryptoAppend(var ABuf: TBytes; AOffset: UInt64;
  const AData: TBytes);
begin
  if not QuicVarintAppend(ABuf, cQfCrypto) or
     not QuicVarintAppend(ABuf, AOffset) or
     not QuicVarintAppend(ABuf, UInt64(Length(AData))) then
    Exit;
  AppendTailBytes(ABuf, AData);
end;

procedure QuicDatagramAppend(var ABuf: TBytes; const AData: TBytes);
begin
  if not QuicVarintAppend(ABuf, cQfDatagramWithLength) or
     not QuicVarintAppend(ABuf, UInt64(Length(AData))) then
    Exit;
  AppendTailBytes(ABuf, AData);
end;

procedure QuicDatagramTailAppend(var ABuf: TBytes; const AData: TBytes);
begin
  if not QuicVarintAppend(ABuf, cQfDatagram) then
    Exit;
  AppendTailBytes(ABuf, AData);
end;

procedure QuicStreamAppend(var ABuf: TBytes; AStreamId, AOffset: UInt64;
  const AData: TBytes; AFin, AWantLen: Boolean);
var
  LType: Byte;
begin
  if (not AWantLen) and (Length(AData) = 0) and not AFin then
    Exit;   { 无 LEN 无数据无 FIN 的空帧非法 }
  LType := cQfStreamBase;
  if AOffset > 0 then
    LType := LType or cQfStreamOffBit;
  if AWantLen then
    LType := LType or cQfStreamLenBit;
  if AFin then
    LType := LType or cQfStreamFinBit;
  if not QuicVarintAppend(ABuf, LType) or
     not QuicVarintAppend(ABuf, AStreamId) then
    Exit;
  if AOffset > 0 then
    if not QuicVarintAppend(ABuf, AOffset) then
      Exit;
  if AWantLen then
    if not QuicVarintAppend(ABuf, UInt64(Length(AData))) then
      Exit;
  AppendTailBytes(ABuf, AData);
end;

procedure QuicResetStreamAppend(var ABuf: TBytes; AStreamId,
  AErrorCode, AFinalSize: UInt64);
begin
  if not QuicVarintAppend(ABuf, cQfResetStream) or
     not QuicVarintAppend(ABuf, AStreamId) or
     not QuicVarintAppend(ABuf, AErrorCode) or
     not QuicVarintAppend(ABuf, AFinalSize) then
    Exit;
end;

procedure QuicStopSendingAppend(var ABuf: TBytes; AStreamId,
  AErrorCode: UInt64);
begin
  if not QuicVarintAppend(ABuf, cQfStopSending) or
     not QuicVarintAppend(ABuf, AStreamId) or
     not QuicVarintAppend(ABuf, AErrorCode) then
    Exit;
end;

procedure QuicMaxDataAppend(var ABuf: TBytes; AMaxData: UInt64);
begin
  if not QuicVarintAppend(ABuf, cQfMaxData) or
     not QuicVarintAppend(ABuf, AMaxData) then
    Exit;
end;

procedure QuicMaxStreamDataAppend(var ABuf: TBytes; AStreamId,
  AMaxStreamData: UInt64);
begin
  if not QuicVarintAppend(ABuf, cQfMaxStreamData) or
     not QuicVarintAppend(ABuf, AStreamId) or
     not QuicVarintAppend(ABuf, AMaxStreamData) then
    Exit;
end;

procedure QuicMaxStreamsAppend(var ABuf: TBytes; ABidi: Boolean;
  AMaxStreams: UInt64);
var
  LType: Byte;
begin
  if ABidi then
    LType := cQfMaxStreamsBidi
  else
    LType := cQfMaxStreamsUni;
  if not QuicVarintAppend(ABuf, LType) or
     not QuicVarintAppend(ABuf, AMaxStreams) then
    Exit;
end;

procedure QuicDataBlockedAppend(var ABuf: TBytes; AMaxData: UInt64);
begin
  if not QuicVarintAppend(ABuf, cQfDataBlocked) or
     not QuicVarintAppend(ABuf, AMaxData) then
    Exit;
end;

procedure QuicStreamDataBlockedAppend(var ABuf: TBytes; AStreamId,
  AMaxStreamData: UInt64);
begin
  if not QuicVarintAppend(ABuf, cQfStreamDataBlocked) or
     not QuicVarintAppend(ABuf, AStreamId) or
     not QuicVarintAppend(ABuf, AMaxStreamData) then
    Exit;
end;

procedure QuicStreamsBlockedAppend(var ABuf: TBytes; ABidi: Boolean;
  AMaxStreams: UInt64);
var
  LType: Byte;
begin
  if ABidi then
    LType := cQfStreamsBlockedBidi
  else
    LType := cQfStreamsBlockedUni;
  if not QuicVarintAppend(ABuf, LType) or
     not QuicVarintAppend(ABuf, AMaxStreams) then
    Exit;
end;

function QuicNewConnectionIdAppend(var ABuf: TBytes; ASeq,
  ARetirePriorTo: UInt64; const ACid: array of Byte;
  const AResetToken: array of Byte): Boolean;
var
  LN, LCidLen: Integer;
begin
  Result := False;
  LCidLen := Length(ACid);
  if (LCidLen < 1) or (LCidLen > cQuicMaxCidLen) or
     (Length(AResetToken) <> 16) then
    Exit;
  if not QuicVarintAppend(ABuf, cQfNewConnectionId) or
     not QuicVarintAppend(ABuf, ASeq) or
     not QuicVarintAppend(ABuf, ARetirePriorTo) then
    Exit;
  QuicBufAppendByte(ABuf, Byte(LCidLen));
  LN := Length(ABuf);
  SetLength(ABuf, LN + LCidLen + 16);
  for LN := 0 to LCidLen - 1 do
    ABuf[Length(ABuf) - LCidLen - 16 + LN] := ACid[LN];
  for LN := 0 to 15 do
    ABuf[Length(ABuf) - 16 + LN] := AResetToken[LN];
  Result := True;
end;

procedure QuicRetireConnectionIdAppend(var ABuf: TBytes; ASeq: UInt64);
begin
  if QuicVarintAppend(ABuf, cQfRetireConnectionId) then
    QuicVarintAppend(ABuf, ASeq);
end;

function QuicPathChallengeAppend(var ABuf: TBytes;
  const AData: array of Byte): Boolean;
var
  LN: Integer;
begin
  Result := False;
  if Length(AData) <> 8 then
    Exit;
  QuicBufAppendByte(ABuf, cQfPathChallenge);
  LN := Length(ABuf);
  SetLength(ABuf, LN + 8);
  for LN := 0 to 7 do
    ABuf[Length(ABuf) - 8 + LN] := AData[LN];
  Result := True;
end;

function QuicPathResponseAppend(var ABuf: TBytes;
  const AData: array of Byte): Boolean;
var
  LN: Integer;
begin
  Result := False;
  if Length(AData) <> 8 then
    Exit;
  QuicBufAppendByte(ABuf, cQfPathResponse);
  LN := Length(ABuf);
  SetLength(ABuf, LN + 8);
  for LN := 0 to 7 do
    ABuf[Length(ABuf) - 8 + LN] := AData[LN];
  Result := True;
end;

procedure QuicConnCloseTransportAppend(var ABuf: TBytes; AErrorCode,
  ATriggeredFrameType: UInt64; const AReason: TBytes);
begin
  if not QuicVarintAppend(ABuf, cQfConnCloseTransport) or
     not QuicVarintAppend(ABuf, AErrorCode) or
     not QuicVarintAppend(ABuf, ATriggeredFrameType) or
     not QuicVarintAppend(ABuf, UInt64(Length(AReason))) then
    Exit;
  AppendTailBytes(ABuf, AReason);
end;

procedure QuicConnCloseAppAppend(var ABuf: TBytes; AErrorCode: UInt64;
  const AReason: TBytes);
begin
  if not QuicVarintAppend(ABuf, cQfConnCloseApp) or
     not QuicVarintAppend(ABuf, AErrorCode) or
     not QuicVarintAppend(ABuf, UInt64(Length(AReason))) then
    Exit;
  AppendTailBytes(ABuf, AReason);
end;

end.
