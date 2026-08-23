unit nextpas.core.net.quic.stream;

{**
 * nextpas.core.net.quic.stream — QUIC 流多路复用器（RFC 9000 §2/§3/§4，Q5）
 *
 * 职责：流号分配（客户端 bidi 0x00 步进 4 / uni 0x02 步进 4）、收发两
 * 侧流状态机、按偏移有序重组、RESET/STOP 语义、流控账本接线（连接级
 * + 流级，见 net.quic.flow）、STREAM 字节区间的可靠发送簿记（span 按
 * 包号登记 → ACK 结算裁剪 → 判丢入重发队）。
 *
 * 内存纪律（S2 对齐）：单流发送保留区上界 cQuicStreamSendBufCap
 * （已确认前缀随 ACK 裁剪推进 WriteBase）；收侧乱序暂存段数上界
 * cQuicStreamHoldBound；复用表容量上界 cQuicMaxStreamsPerConn——
 * 三处越界一律 fail-closed 上抛连接错误。
 *
 * 计费模型：发送预算按「已发最大偏移」前沿计费（net.quic.flow），重
 * 发同偏移不重复计费；连接级预算按累计字节计费（FConnBilled 单调计
 * 数器）。CollectFrames 只暂存产出（staged），conn 封包成功后
 * CommitSent(APn) 落账并登记 span，构建失败 RollbackStaged 恢复原状。
 *
 * @note Thread safety: 单实例单线程使用（事件循环内驱动）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.quic.frame,
  nextpas.core.net.quic.flow;

const
  cQuicMaxStreamsPerConn = 256;    { 复用表容量上界（fail-closed） }
  cQuicStreamHoldBound = 32;       { 单流收侧乱序暂存段数上界 }
  cQuicStreamSendBufCap = 262144;  { 单流发送保留区字节上界 }
  cQuicStreamChunkReserve = 16;    { STREAM 帧头最坏 varint 开销预留 }

type
  TQuicStreamDir = (qsdBidi, qsdUni);

  { 在途未确认区间（按包号） }
  TQuicStreamSpan = record
    Pn: UInt64;
    Lo, Hi: UInt64;   { 流内绝对区间 [Lo..Hi) }
  end;

  { 判丢待重发区间 }
  TQuicResendRange = record
    Lo, Hi: UInt64;
  end;

  { 收侧乱序暂存段（互斥不重叠、按 Ofs 升序） }
  TQuicRecvSeg = record
    Ofs: Int64;
    Data: TBytes;
  end;

  TQuicStream = class
    Id: UInt64;
    Dir: TQuicStreamDir;
    { ---- 发送侧 ---- }
    WriteBase: UInt64;       { SendBuf[0] 对应的流内绝对偏移 }
    SendBuf: TBytes;         { [WriteBase..) 待发+在途数据（ACK 裁剪） }
    FinQueued: Boolean;      { 应用已请求 FIN（此后禁止再写） }
    FinSent: Boolean;
    SendFinalOffset: UInt64; { FIN 形态=流总长；RESET 形态=已发总量 }
    SentHi: UInt64;          { 已发最大偏移（流级计费前沿） }
    SendAborted: Boolean;    { RESET/STOP 后终止发送 }
    Spans: array of TQuicStreamSpan;
    ResendQ: array of TQuicResendRange;
    Budget: TQuicFlowBudget;
    BlockedAnnounced: Boolean;
    { ---- 接收侧 ---- }
    ConsumedHi: UInt64;      { 连续可交付前沿 }
    RecvHi: UInt64;          { 已收最大偏移上沿（final size 校验用） }
    Holds: array of TQuicRecvSeg;
    HasFinalSize: Boolean;
    PeerFinalSize: UInt64;
    RecvFinDelivered: Boolean;
    RecvAborted: Boolean;    { 收到 RESET 后丢弃后续 }
    RxCtl: TQuicFlowRecvCtl;
  end;

  TOnStreamData = procedure(AStreamId: UInt64; const AData: TBytes;
    AFin: Boolean) of object;
  TOnStreamReset = procedure(AStreamId, AErrorCode: UInt64) of object;
  TOnMuxFatal = procedure(const AReason: string) of object;

  { CollectFrames 的单条产出暂存：封包成功后一次性落账 }
  TQuicStagedChunk = record
    StreamIdx: Integer;
    Lo, Hi: UInt64;      { 本 chunk 覆盖的流内区间 }
    IsNewData: Boolean;  { 新数据才推进计费前沿 }
    Fin: Boolean;
  end;

  TQuicStreamMux = class
  private
    FStreams: array of TQuicStream;
    FNextLocalBidi: UInt64;      { 下一个本地 bidi 流号（0x00 步进 4） }
    FNextLocalUni: UInt64;       { 下一个本地 uni 流号（0x02 步进 4） }
    FPeerGrantBidi: UInt64;      { 对端 MAX_STREAMS 授予的本地可开流数 }
    FPeerGrantUni: UInt64;
    FGrantBidiLocal: UInt64;     { 我方发起 bidi 流的流级发送授权 }
    FGrantBidiRemote: UInt64;    { 对端发起 bidi 流的流级发送授权 }
    FGrantUni: UInt64;           { 我方发起 uni 流的流级发送授权 }
    FConnBudget: TQuicFlowBudget;
    FConnRx: TQuicFlowRecvCtl;
    FStreamWindow: UInt64;       { 新建流的接收窗口 }
    FConnBilled: UInt64;         { 连接级累计计费字节 }
    FConnBlockedAnnounced: Boolean;
    FControlOut: TBytes;         { 控制帧输出队列（MAX_*/BLOCKED/RESET） }
    FStaged: array of TQuicStagedChunk;
    FOnStreamData: TOnStreamData;
    FOnStreamReset: TOnStreamReset;
    FOnFatal: TOnMuxFatal;
    function GetStreamCount: Integer;
    function FindStream(AStreamId: UInt64; out AIdx: Integer): Boolean;
    function CreateStream(AStreamId: UInt64;
      out AIdx: Integer): Boolean;
    procedure Fatal(const AReason: string);
    procedure QueueControl(const AFrame: TBytes);
    procedure MaybeAdvertiseWindows(AIdx: Integer);
    procedure DeliverContiguous(AIdx: Integer);
    procedure TrimStream(AIdx: Integer);
    procedure AbortSendSide(AIdx: Integer; AErrorCode: UInt64);
    function EnsurePeerOrigin(AStreamId: UInt64;
      out AIdx: Integer): Boolean;
    procedure StageAndAppend(var ABuf: TBytes; AIdx: Integer;
      AOffset: UInt64; const AData: TBytes; AFin, ANewData: Boolean);
  public
    constructor Create(AConnWindow, AStreamWindow: UInt64);
    destructor Destroy; override;

    {** 对端传输参数授予值落地。AStreamDataBidiLocal 为我方发起的双向
      *  流发送预算、BidiRemote 为对端发起的双向流（§18.2 语义） *}
    procedure ApplyPeerGrants(AInitialMaxData,
      AStreamDataBidiLocal, AStreamDataBidiRemote, AStreamDataUni,
      AMaxStreamsBidi, AMaxStreamsUni: UInt64);

    function OpenBidi(out AStreamId: UInt64): Boolean;
    function OpenUni(out AStreamId: UInt64): Boolean;

    {** 入队待发数据；AFin=True 后禁止续写。缓冲越界/流不可写返回 False *}
    function StreamWrite(AStreamId: UInt64; const AData: TBytes;
      AFin: Boolean): Boolean;

    {** 应用请求复位发送侧（排队 RESET_STREAM） *}
    function ResetLocal(AStreamId, AErrorCode: UInt64): Boolean;

    { ---- 对端帧入口（conn 分派；致命语义经 OnFatal 上抛）---- }
    procedure HandleMaxData(AValue: UInt64);
    procedure HandleMaxStreamData(AStreamId, AValue: UInt64);
    procedure HandleMaxStreams(ABidi: Boolean; AValue: UInt64);
    procedure HandleStreamData(AStreamId, AOffset: UInt64;
      const AData: TBytes; AFin: Boolean);
    procedure HandleResetStream(AStreamId, AErrorCode,
      AFinalSize: UInt64);
    procedure HandleStopSending(AStreamId, AErrorCode: UInt64);

    { ---- 可靠性联动（conn 封包生命周期调用）---- }
    procedure CommitSent(APn: UInt64);
    procedure RollbackStaged;
    procedure OnAckRanges(const ARanges: TQuicAckRangeArray);
    {** 判丢包号列表（开放数组：与 reliable.TQuicPnArray 兼容） *}
    procedure OnLostPns(const ALostPns: array of UInt64);

    {** 产出控制帧+重发+新数据至多 AMaxLen 字节；无产出返回 False。
      *  产出仅暂存，须以 CommitSent/RollbackStaged 收尾 *}
    function CollectFrames(var ABuf: TBytes; AMaxLen: Integer): Boolean;

    property OnStreamData: TOnStreamData read FOnStreamData
      write FOnStreamData;
    property OnStreamReset: TOnStreamReset read FOnStreamReset
      write FOnStreamReset;
    property OnFatal: TOnMuxFatal read FOnFatal write FOnFatal;
    property ConnBudget: TQuicFlowBudget read FConnBudget;
    property ConnRx: TQuicFlowRecvCtl read FConnRx;
    property StreamCount: Integer read GetStreamCount;
  end;

implementation

procedure CopyTailInto(var ADst: TBytes; const ASrc: TBytes);
var
  LN, LI: Integer;
begin
  LN := Length(ADst);
  SetLength(ADst, LN + Length(ASrc));
  for LI := 0 to Length(ASrc) - 1 do
    ADst[LN + LI] := ASrc[LI];
end;

function SliceCopy(const ABuf: TBytes; AStart, ACount: Integer): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  if (ACount <= 0) or (AStart < 0) or (AStart + ACount > Length(ABuf)) then
    Exit;
  SetLength(Result, ACount);
  for LI := 0 to ACount - 1 do
    Result[LI] := ABuf[AStart + LI];
end;

function TQuicStreamMux.GetStreamCount: Integer;
begin
  Result := Length(FStreams);
end;

constructor TQuicStreamMux.Create(AConnWindow, AStreamWindow: UInt64);
begin
  inherited Create;
  QuicBudgetInit(FConnBudget, 0);   { 对端授予值由 ApplyPeerGrants 注入 }
  QuicRecvInit(FConnRx, AConnWindow);
  FStreamWindow := AStreamWindow;
  FNextLocalBidi := 0;
  FNextLocalUni := 2;
end;

destructor TQuicStreamMux.Destroy;
var
  LI: Integer;
begin
  for LI := 0 to High(FStreams) do
    FStreams[LI].Free;
  FStreams := nil;
  inherited Destroy;
end;

procedure TQuicStreamMux.Fatal(const AReason: string);
begin
  if Assigned(FOnFatal) then
    FOnFatal(AReason);
end;

procedure TQuicStreamMux.QueueControl(const AFrame: TBytes);
begin
  CopyTailInto(FControlOut, AFrame);
end;

function TQuicStreamMux.FindStream(AStreamId: UInt64;
  out AIdx: Integer): Boolean;
var
  LI: Integer;
begin
  for LI := 0 to High(FStreams) do
    if FStreams[LI].Id = AStreamId then
    begin
      AIdx := LI;
      Exit(True);
    end;
  AIdx := -1;
  Result := False;
end;

function TQuicStreamMux.CreateStream(AStreamId: UInt64;
  out AIdx: Integer): Boolean;
var
  LS: TQuicStream;
begin
  Result := False;
  if Length(FStreams) >= cQuicMaxStreamsPerConn then
    Exit;   { 容量上界 fail-closed（S2 纪律） }
  LS := TQuicStream.Create;
  LS.Id := AStreamId;
  case AStreamId mod 4 of
    0, 1: LS.Dir := qsdBidi;
  else
    LS.Dir := qsdUni;
  end;
  QuicRecvInit(LS.RxCtl, FStreamWindow);
  AIdx := Length(FStreams);
  SetLength(FStreams, AIdx + 1);
  FStreams[AIdx] := LS;
  Result := True;
end;

procedure TQuicStreamMux.ApplyPeerGrants(AInitialMaxData,
  AStreamDataBidiLocal, AStreamDataBidiRemote, AStreamDataUni,
  AMaxStreamsBidi, AMaxStreamsUni: UInt64);
var
  LI: Integer;
  LS: TQuicStream;
begin
  QuicBudgetGrant(FConnBudget, AInitialMaxData);
  FPeerGrantBidi := AMaxStreamsBidi;
  FPeerGrantUni := AMaxStreamsUni;
  FGrantBidiLocal := AStreamDataBidiLocal;
  FGrantBidiRemote := AStreamDataBidiRemote;
  FGrantUni := AStreamDataUni;
  { 存量流的流级授权按发起方向套用对应参数 }
  for LI := 0 to High(FStreams) do
  begin
    LS := FStreams[LI];
    if LS.Dir = qsdUni then
      QuicBudgetGrant(LS.Budget, AStreamDataUni)
    else if (LS.Id mod 4) = 0 then
      QuicBudgetGrant(LS.Budget, AStreamDataBidiLocal)
    else
      QuicBudgetGrant(LS.Budget, AStreamDataBidiRemote);
  end;
end;

function TQuicStreamMux.OpenBidi(out AStreamId: UInt64): Boolean;
var
  LIdx: Integer;
begin
  Result := False;
  AStreamId := 0;
  if FNextLocalBidi div 4 >= FPeerGrantBidi then
    Exit;   { 超 MAX_STREAMS 授予 }
  if not CreateStream(FNextLocalBidi, LIdx) then
    Exit;
  QuicBudgetInit(FStreams[LIdx].Budget, FGrantBidiLocal);
  AStreamId := FNextLocalBidi;
  FNextLocalBidi := FNextLocalBidi + 4;
  Result := True;
end;

function TQuicStreamMux.OpenUni(out AStreamId: UInt64): Boolean;
var
  LIdx: Integer;
begin
  Result := False;
  AStreamId := 0;
  if FNextLocalUni div 4 >= FPeerGrantUni then
    Exit;
  if not CreateStream(FNextLocalUni, LIdx) then
    Exit;
  QuicBudgetInit(FStreams[LIdx].Budget, FGrantUni);
  AStreamId := FNextLocalUni;
  FNextLocalUni := FNextLocalUni + 4;
  Result := True;
end;

function TQuicStreamMux.StreamWrite(AStreamId: UInt64;
  const AData: TBytes; AFin: Boolean): Boolean;
var
  LIdx: Integer;
  LS: TQuicStream;
begin
  Result := False;
  if not FindStream(AStreamId, LIdx) then
    Exit;
  LS := FStreams[LIdx];
  if LS.SendAborted or LS.FinQueued then
    Exit;   { 复位/FIN 之后禁止续写 }
  if Length(LS.SendBuf) + Length(AData) > cQuicStreamSendBufCap then
    Exit;   { 有界纪律 }
  if (not AFin) and (Length(AData) = 0) then
    Exit(True);   { 空 非 FIN 写幂等 }
  CopyTailInto(LS.SendBuf, AData);
  if AFin then
  begin
    LS.FinQueued := True;
    LS.SendFinalOffset := LS.WriteBase + UInt64(Length(LS.SendBuf));
  end;
  Result := True;
end;

procedure TQuicStreamMux.AbortSendSide(AIdx: Integer; AErrorCode: UInt64);
var
  LS: TQuicStream;
  LF: TBytes;
begin
  LS := FStreams[AIdx];
  if LS.SendAborted then
    Exit;
  LS.SendAborted := True;
  LS.SendFinalOffset := LS.SentHi;   { §19.4 Final Size=已发总量 }
  LS.SendBuf := nil;
  LS.Spans := nil;
  LS.ResendQ := nil;
  LF := nil;
  QuicResetStreamAppend(LF, LS.Id, AErrorCode, LS.SendFinalOffset);
  QueueControl(LF);
end;

function TQuicStreamMux.ResetLocal(AStreamId, AErrorCode: UInt64): Boolean;
var
  LIdx: Integer;
begin
  Result := False;
  if not FindStream(AStreamId, LIdx) then
    Exit;
  AbortSendSide(LIdx, AErrorCode);
  Result := True;
end;

procedure TQuicStreamMux.HandleMaxData(AValue: UInt64);
begin
  QuicBudgetGrant(FConnBudget, AValue);
  FConnBlockedAnnounced := False;
end;

procedure TQuicStreamMux.HandleMaxStreamData(AStreamId, AValue: UInt64);
var
  LIdx: Integer;
begin
  if not FindStream(AStreamId, LIdx) then
    Exit;   { 未知名引用忽略（最小面；严格状态错误属后续批） }
  QuicBudgetGrant(FStreams[LIdx].Budget, AValue);
  FStreams[LIdx].BlockedAnnounced := False;
end;

procedure TQuicStreamMux.HandleMaxStreams(ABidi: Boolean; AValue: UInt64);
begin
  if ABidi then
  begin
    if AValue > FPeerGrantBidi then
      FPeerGrantBidi := AValue;
  end
  else
  begin
    if AValue > FPeerGrantUni then
      FPeerGrantUni := AValue;
  end;
end;

function TQuicStreamMux.EnsurePeerOrigin(AStreamId: UInt64;
  out AIdx: Integer): Boolean;
begin
  Result := False;
  if FindStream(AStreamId, AIdx) then
    Exit(True);
  { 对端发起的流号：本端为客户端，owner 位恒为 1（即 id mod 2 取一） }
  if (AStreamId mod 2) <> 1 then
  begin
    Fatal('stream id not peer-originated');
    Exit;
  end;
  if not CreateStream(AStreamId, AIdx) then
  begin
    Fatal('stream table beyond bound');
    Exit;
  end;
  { 对端发起 bidi 流的我方发送授权 = bidi_remote（uni 流我方只收不发） }
  if (AStreamId mod 4) = 1 then
    QuicBudgetInit(FStreams[AIdx].Budget, FGrantBidiRemote);
  Result := True;
end;

procedure TQuicStreamMux.DeliverContiguous(AIdx: Integer);
var
  LS: TQuicStream;
  LSeg: TQuicRecvSeg;
  LI: Integer;
begin
  LS := FStreams[AIdx];
  while Length(LS.Holds) > 0 do
  begin
    if UInt64(LS.Holds[0].Ofs) <> LS.ConsumedHi then
      Break;
    LSeg := LS.Holds[0];
    { 弹出首段（含 TBytes 的记录禁裸 Move：逐位搬移） }
    for LI := 0 to Length(LS.Holds) - 2 do
      LS.Holds[LI] := LS.Holds[LI + 1];
    SetLength(LS.Holds, Length(LS.Holds) - 1);

    QuicRecvConsume(LS.RxCtl, UInt64(Length(LSeg.Data)));
    QuicRecvConsume(FConnRx, UInt64(Length(LSeg.Data)));
    LS.ConsumedHi := LS.ConsumedHi + UInt64(Length(LSeg.Data));
    if Assigned(FOnStreamData) then
      FOnStreamData(LS.Id, LSeg.Data, False);
  end;
  { FIN 恰在连续前沿到达时交付（含零长 FIN 形态） }
  if (not LS.RecvFinDelivered) and LS.HasFinalSize and
     (LS.ConsumedHi = LS.PeerFinalSize) then
  begin
    LS.RecvFinDelivered := True;
    if Assigned(FOnStreamData) then
      FOnStreamData(LS.Id, nil, True);
  end;
end;

procedure TQuicStreamMux.MaybeAdvertiseWindows(AIdx: Integer);
var
  LF: TBytes;
begin
  { 流级升窗 }
  if QuicRecvShouldAdvertise(FStreams[AIdx].RxCtl) and
     QuicRecvAdvertise(FStreams[AIdx].RxCtl,
       QuicRecvNextLimit(FStreams[AIdx].RxCtl)) then
  begin
    LF := nil;
    QuicMaxStreamDataAppend(LF, FStreams[AIdx].Id,
      FStreams[AIdx].RxCtl.Advertised);
    QueueControl(LF);
  end;
  { 连接级升窗 }
  if QuicRecvShouldAdvertise(FConnRx) and
     QuicRecvAdvertise(FConnRx, QuicRecvNextLimit(FConnRx)) then
  begin
    LF := nil;
    QuicMaxDataAppend(LF, FConnRx.Advertised);
    QueueControl(LF);
  end;
end;

procedure TQuicStreamMux.HandleStreamData(AStreamId, AOffset: UInt64;
  const AData: TBytes; AFin: Boolean);
var
  LIdx: Integer;
  LS: TQuicStream;
  LLen: UInt64;
  LViewLo, LViewHi, LHeldLo, LHeldHi, LPieceLo, LPieceHi: UInt64;
  LPieces: array[0..cQuicStreamHoldBound + 1] of TQuicRecvSeg;
  LPieceCount, LI, LM: Integer;
  LSeg: TQuicRecvSeg;
  LInsPos: Integer;
begin
  if not EnsurePeerOrigin(AStreamId, LIdx) then
    Exit;
  LS := FStreams[LIdx];
  if LS.RecvAborted then
    Exit;   { RESET 之后的数据静默丢弃 }

  LLen := UInt64(Length(AData));
  { final size 登记/一致性（§4.5） }
  if AFin then
  begin
    if LS.HasFinalSize and
       (AOffset + LLen <> LS.PeerFinalSize) then
    begin
      Fatal('conflicting final size');
      Exit;
    end;
    LS.HasFinalSize := True;
    LS.PeerFinalSize := AOffset + LLen;
  end;
  if LS.HasFinalSize and (AOffset + LLen > LS.PeerFinalSize) then
  begin
    Fatal('data beyond final size');
    Exit;
  end;
  if AOffset + LLen > LS.RecvHi then
    LS.RecvHi := AOffset + LLen;

  { 与消费前沿裁剪：完全重复直接忽略 }
  LViewLo := AOffset;
  LViewHi := AOffset + LLen;
  if LViewHi > LS.ConsumedHi then
  begin
    if LViewLo < LS.ConsumedHi then
      LViewLo := LS.ConsumedHi;
    if LViewHi > LViewLo then   { 裁剪后仍有新字节才暂存 }
    begin
    { 与既有暂存段求差集（最多碎成 HoldBound+1 片） }
    LPieceCount := 1;
    LPieces[0].Ofs := Int64(LViewLo);
    LPieces[0].Data := SliceCopy(AData, Integer(LViewLo - AOffset),
      Integer(LViewHi - LViewLo));
    for LI := 0 to High(LS.Holds) do
    begin
      LHeldLo := UInt64(LS.Holds[LI].Ofs);
      LHeldHi := LHeldLo + UInt64(Length(LS.Holds[LI].Data));
      LM := 0;
      for LInsPos := 0 to LPieceCount - 1 do
      begin
        LPieceLo := UInt64(LPieces[LInsPos].Ofs);
        LPieceHi := LPieceLo + UInt64(Length(LPieces[LInsPos].Data));
        if (LPieceLo >= LHeldHi) or (LHeldLo >= LPieceHi) then
        begin
          LPieces[LM] := LPieces[LInsPos];   { 无重叠保留 }
          Inc(LM);
        end
        else
        begin
          if LPieceLo < LHeldLo then   { 左残片 }
          begin
            LPieces[LM].Ofs := Int64(LPieceLo);
            LPieces[LM].Data := SliceCopy(LPieces[LInsPos].Data, 0,
              Integer(LHeldLo - LPieceLo));
            Inc(LM);
          end;
          if LPieceHi > LHeldHi then   { 右残片 }
          begin
            LPieces[LM].Ofs := Int64(LHeldHi);
            LPieces[LM].Data := SliceCopy(LPieces[LInsPos].Data,
              Integer(LHeldHi - LPieceLo),
              Integer(LPieceHi - LHeldHi));
            Inc(LM);
          end;
        end;
      end;
      LPieceCount := LM;
      if LPieceCount = 0 then
        Break;
    end;

    if LPieceCount > 0 then
    begin
      if Length(LS.Holds) + LPieceCount > cQuicStreamHoldBound then
      begin
        Fatal('stream reorder beyond bound');
        Exit;
      end;
      for LI := 0 to LPieceCount - 1 do
      begin
        LSeg := LPieces[LI];
        LInsPos := Length(LS.Holds);
        while (LInsPos > 0) and
              (UInt64(LS.Holds[LInsPos - 1].Ofs) >
               UInt64(LSeg.Ofs)) do
          Dec(LInsPos);
        SetLength(LS.Holds, Length(LS.Holds) + 1);
        for LM := Length(LS.Holds) - 1 downto LInsPos + 1 do
          LS.Holds[LM] := LS.Holds[LM - 1];
        LS.Holds[LInsPos] := LSeg;
      end;
    end;
    end;   { LViewHi > LViewLo }
  end;

  DeliverContiguous(LIdx);
  if LS.HasFinalSize and (LS.ConsumedHi > LS.PeerFinalSize) then
  begin
    Fatal('consumed beyond final size');
    Exit;
  end;
  MaybeAdvertiseWindows(LIdx);
end;

procedure TQuicStreamMux.HandleResetStream(AStreamId, AErrorCode,
  AFinalSize: UInt64);
var
  LIdx: Integer;
  LS: TQuicStream;
begin
  if not EnsurePeerOrigin(AStreamId, LIdx) then
    Exit;
  LS := FStreams[LIdx];
  if LS.RecvAborted then
    Exit;
  if LS.HasFinalSize and (AFinalSize <> LS.PeerFinalSize) then
  begin
    Fatal('reset conflicts final size');
    Exit;
  end;
  if LS.RecvHi > AFinalSize then
  begin
    Fatal('reset below received data');
    Exit;
  end;
  { 消费前沿跳到 final：被弃字节照常记账防窗口卡死 }
  if AFinalSize > LS.ConsumedHi then
  begin
    QuicRecvConsume(LS.RxCtl, AFinalSize - LS.ConsumedHi);
    QuicRecvConsume(FConnRx, AFinalSize - LS.ConsumedHi);
    LS.ConsumedHi := AFinalSize;
  end;
  LS.RecvAborted := True;
  LS.HasFinalSize := True;
  LS.PeerFinalSize := AFinalSize;
  LS.Holds := nil;
  if Assigned(FOnStreamReset) then
    FOnStreamReset(AStreamId, AErrorCode);
  MaybeAdvertiseWindows(LIdx);
end;

procedure TQuicStreamMux.HandleStopSending(AStreamId, AErrorCode: UInt64);
var
  LIdx: Integer;
begin
  if FindStream(AStreamId, LIdx) then
    AbortSendSide(LIdx, AErrorCode)
  else if (AStreamId mod 2) = 0 then
    Fatal('stop sending for unknown local stream');
end;

procedure TQuicStreamMux.CommitSent(APn: UInt64);
var
  LI: Integer;
  LS: TQuicStream;
  LN: Integer;
begin
  for LI := 0 to High(FStaged) do
  begin
    LS := FStreams[FStaged[LI].StreamIdx];
    if FStaged[LI].Hi > FStaged[LI].Lo then
    begin
      LN := Length(LS.Spans);
      SetLength(LS.Spans, LN + 1);
      LS.Spans[LN].Pn := APn;
      LS.Spans[LN].Lo := FStaged[LI].Lo;
      LS.Spans[LN].Hi := FStaged[LI].Hi;
    end;
    if FStaged[LI].IsNewData then
    begin
      LS.SentHi := FStaged[LI].Hi;
      QuicBillingAdvance(LS.Budget, LS.SentHi);
      FConnBilled := FConnBilled + (FStaged[LI].Hi - FStaged[LI].Lo);
      QuicBillingAdvance(FConnBudget, FConnBilled);
    end;
    if FStaged[LI].Fin then
      LS.FinSent := True;
  end;
  FStaged := nil;
end;

procedure TQuicStreamMux.RollbackStaged;
begin
  FStaged := nil;
end;

procedure TQuicStreamMux.OnAckRanges(const ARanges: TQuicAckRangeArray);
var
  LI, LM, LR, LA: Integer;
  LS: TQuicStream;
  LAcked: Boolean;
begin
  for LI := 0 to High(FStreams) do
  begin
    LS := FStreams[LI];
    if (Length(LS.Spans) = 0) and (Length(LS.ResendQ) = 0) then
      Continue;
    { 剔除已确认 span }
    LM := 0;
    for LR := 0 to High(LS.Spans) do
    begin
      LAcked := False;
      for LA := 0 to High(ARanges) do
        if (LS.Spans[LR].Pn >= ARanges[LA].Lo) and
           (LS.Spans[LR].Pn <= ARanges[LA].Hi) then
        begin
          LAcked := True;
          Break;
        end;
      if not LAcked then
      begin
        LS.Spans[LM] := LS.Spans[LR];
        Inc(LM);
      end;
    end;
    SetLength(LS.Spans, LM);
    TrimStream(LI);
  end;
end;

procedure TQuicStreamMux.OnLostPns(const ALostPns: array of UInt64);
var
  LI, LR, LP, LX: Integer;
  LS: TQuicStream;
  LDup: Boolean;
  LRange: TQuicResendRange;
begin
  if Length(ALostPns) = 0 then
    Exit;
  for LI := 0 to High(FStreams) do
  begin
    LS := FStreams[LI];
    for LR := 0 to High(LS.Spans) do
    begin
      LDup := False;
      for LP := 0 to High(ALostPns) do
        if LS.Spans[LR].Pn = ALostPns[LP] then
        begin
          LDup := True;
          Break;
        end;
      if not LDup then
        Continue;
      { 判丢区间入重发队（含于既有区间的跳过） }
      LRange.Lo := LS.Spans[LR].Lo;
      LRange.Hi := LS.Spans[LR].Hi;
      LDup := False;
      for LP := 0 to High(LS.ResendQ) do
        if (LS.ResendQ[LP].Lo <= LRange.Lo) and
           (LS.ResendQ[LP].Hi >= LRange.Hi) then
        begin
          LDup := True;
          Break;
        end;
      if LDup then
        Continue;
      { 与既有区间相交则扩张之（保守合并防重复重传） }
      for LP := 0 to High(LS.ResendQ) do
        if (LS.ResendQ[LP].Lo <= LRange.Hi) and
           (LRange.Lo <= LS.ResendQ[LP].Hi) then
        begin
          if LRange.Lo < LS.ResendQ[LP].Lo then
            LS.ResendQ[LP].Lo := LRange.Lo;
          if LRange.Hi > LS.ResendQ[LP].Hi then
            LS.ResendQ[LP].Hi := LRange.Hi;
          LDup := True;
          Break;
        end;
      if not LDup then
      begin
        LX := Length(LS.ResendQ);
        SetLength(LS.ResendQ, LX + 1);
        LS.ResendQ[LX] := LRange;
      end;
    end;
  end;
end;

procedure TQuicStreamMux.TrimStream(AIdx: Integer);
var
  LS: TQuicStream;
  LKeep: UInt64;
  LI, LDrop: Integer;
begin
  LS := FStreams[AIdx];
  LKeep := LS.SentHi;
  for LI := 0 to High(LS.ResendQ) do
    if LS.ResendQ[LI].Lo < LKeep then
      LKeep := LS.ResendQ[LI].Lo;
  if LKeep <= LS.WriteBase then
    Exit;
  LDrop := Integer(LKeep - LS.WriteBase);
  if LDrop >= Length(LS.SendBuf) then
    LS.SendBuf := nil
  else
  begin
    for LI := 0 to Length(LS.SendBuf) - LDrop - 1 do
      LS.SendBuf[LI] := LS.SendBuf[LI + LDrop];
    SetLength(LS.SendBuf, Length(LS.SendBuf) - LDrop);
  end;
  LS.WriteBase := LKeep;
end;

procedure TQuicStreamMux.StageAndAppend(var ABuf: TBytes; AIdx: Integer;
  AOffset: UInt64; const AData: TBytes; AFin, ANewData: Boolean);
var
  LN: Integer;
begin
  QuicStreamAppend(ABuf, FStreams[AIdx].Id, AOffset, AData, AFin, True);
  LN := Length(FStaged);
  SetLength(FStaged, LN + 1);
  FStaged[LN].StreamIdx := AIdx;
  FStaged[LN].Lo := AOffset;
  FStaged[LN].Hi := AOffset + UInt64(Length(AData));
  FStaged[LN].IsNewData := ANewData;
  FStaged[LN].Fin := AFin;
end;

function TQuicStreamMux.CollectFrames(var ABuf: TBytes;
  AMaxLen: Integer): Boolean;
var
  LRoom, LTake, LI, LJ: Integer;
  LS: TQuicStream;
  LPending, LAvail, LN, LNewPos: UInt64;
  LConnInUse, LStreamInUse: UInt64;
  LFin: Boolean;
  LCtrlF: TBytes;

  function AvailLeft(AAvail, AUsed: UInt64): UInt64;
  begin
    if AAvail > AUsed then
      Result := AAvail - AUsed
    else
      Result := 0;
  end;

begin
  Result := False;
  LRoom := AMaxLen;

  { 1. 控制帧队列优先清空（单帧超房量则截断留队下次） }
  while (Length(FControlOut) > 0) and (LRoom > 0) do
  begin
    if Length(FControlOut) <= LRoom then
    begin
      CopyTailInto(ABuf, FControlOut);
      Dec(LRoom, Length(FControlOut));
      FControlOut := nil;
    end
    else
    begin
      LTake := LRoom;
      CopyTailInto(ABuf, SliceCopy(FControlOut, 0, LTake));
      Dec(LRoom, LTake);
      for LJ := 0 to Length(FControlOut) - LTake - 1 do
        FControlOut[LJ] := FControlOut[LJ + LTake];
      SetLength(FControlOut, Length(FControlOut) - LTake);
    end;
    Result := True;
  end;

  { 2. 重发优先（同偏移不计费） }
  for LI := 0 to High(FStreams) do
  begin
    LS := FStreams[LI];
    while (Length(LS.ResendQ) > 0) and
          (LRoom > cQuicStreamChunkReserve) do
    begin
      if LS.ResendQ[0].Lo < LS.WriteBase then
      begin
        { 缓冲已被裁剪越过该重发源（理论不可达）：丢弃该区间 }
        for LJ := 0 to Length(LS.ResendQ) - 2 do
          LS.ResendQ[LJ] := LS.ResendQ[LJ + 1];
        SetLength(LS.ResendQ, Length(LS.ResendQ) - 1);
        Continue;
      end;
      LTake := Integer(LS.ResendQ[0].Hi - LS.ResendQ[0].Lo);
      if LTake > LRoom - cQuicStreamChunkReserve then
        LTake := LRoom - cQuicStreamChunkReserve;
      StageAndAppend(ABuf, LI, LS.ResendQ[0].Lo,
        SliceCopy(LS.SendBuf, Integer(LS.ResendQ[0].Lo - LS.WriteBase),
          LTake), False, False);
      Dec(LRoom, LTake);
      LS.ResendQ[0].Lo := LS.ResendQ[0].Lo + UInt64(LTake);
      if LS.ResendQ[0].Lo >= LS.ResendQ[0].Hi then
      begin
        for LJ := 0 to Length(LS.ResendQ) - 2 do
          LS.ResendQ[LJ] := LS.ResendQ[LJ + 1];
        SetLength(LS.ResendQ, Length(LS.ResendQ) - 1);
      end;
      Result := True;
    end;
  end;

  { 3. 新数据（受流级+连接级预算双重钳制）。
    提交前不回写前沿，故以局部游标 LNewPos 记进度、以 *InUse 记本次
    收集的预算占用，防同包双发与同区间重复产出 }
  LConnInUse := 0;
  for LI := 0 to High(FStreams) do
  begin
    LS := FStreams[LI];
    if LS.SendAborted then
      Continue;
    LNewPos := LS.SentHi;
    LStreamInUse := 0;
    while LRoom > cQuicStreamChunkReserve do
    begin
      LPending := LS.WriteBase + UInt64(Length(LS.SendBuf)) - LNewPos;
      if LPending = 0 then
      begin
        LS.BlockedAnnounced := False;
        Break;
      end;
      LAvail := AvailLeft(QuicBudgetAvailable(LS.Budget),
        LStreamInUse);
      if AvailLeft(QuicBudgetAvailable(FConnBudget), LConnInUse) <
         LAvail then
        LAvail := AvailLeft(QuicBudgetAvailable(FConnBudget),
          LConnInUse);
      if LAvail = 0 then
      begin
        { 阻塞通告：每阻塞期一次；房量足则随本包直出，否则留队 }
        if AvailLeft(QuicBudgetAvailable(FConnBudget),
           LConnInUse) = 0 then
        begin
          if not FConnBlockedAnnounced then
          begin
            FConnBlockedAnnounced := True;
            LCtrlF := nil;
            QuicDataBlockedAppend(LCtrlF, FConnBudget.Granted);
            if Length(LCtrlF) <= LRoom then
            begin
              CopyTailInto(ABuf, LCtrlF);
              Dec(LRoom, Length(LCtrlF));
              Result := True;
            end
            else
              QueueControl(LCtrlF);
          end;
        end
        else if not LS.BlockedAnnounced then
        begin
          LS.BlockedAnnounced := True;
          LCtrlF := nil;
          QuicStreamDataBlockedAppend(LCtrlF, LS.Id,
            LS.Budget.Granted);
          if Length(LCtrlF) <= LRoom then
          begin
            CopyTailInto(ABuf, LCtrlF);
            Dec(LRoom, Length(LCtrlF));
            Result := True;
          end
          else
            QueueControl(LCtrlF);
        end;
        Break;
      end;
      LN := LPending;
      if LAvail < LN then
        LN := LAvail;
      if LN > UInt64(LRoom - cQuicStreamChunkReserve) then
        LN := UInt64(LRoom - cQuicStreamChunkReserve);
      LFin := LS.FinQueued and (not LS.FinSent) and
        (LNewPos + LN = LS.WriteBase + UInt64(Length(LS.SendBuf)));
      StageAndAppend(ABuf, LI, LNewPos,
        SliceCopy(LS.SendBuf, Integer(LNewPos - LS.WriteBase),
          Integer(LN)), LFin, True);
      LNewPos := LNewPos + LN;
      LStreamInUse := LStreamInUse + LN;
      LConnInUse := LConnInUse + LN;
      Dec(LRoom, Integer(LN));
      Result := True;
      if LFin then
        Break;
    end;
  end;
end;

end.
