program test_quic_streams;

{ QUIC 流多路复用器单元测试（RFC 9000 §2/§3/§4，Q5）：
  - 流号分配：客户端 bidi 0x00 步进 4、uni 0x02 步进 4、MAX_STREAMS
    授予门禁逐点断言；
  - 发送路径：STREAM 帧线格式往返对拍、FIN 终结语义、流控双重钳制
    （连接级+流级）、DATA_BLOCKED/STREAM_DATA_BLOCKED 阻塞通告、
    MAX_DATA 解除；
  - 可靠性簿记：CommitSent/RollbackStaged 暂存语义、判丢重发同偏移
    不重复计费、ACK 结算裁剪缓冲排空重发队；
  - 接收路径：乱序重组按偏移有序交付、重叠去重、零长 FIN 恰在连续
    前沿交付、RESET 弃读/final size 冲突 fail-closed、STOP_SENDING
    触发 RESET_STREAM 回帧；
  - 有界纪律：发送保留区上界拒写、乱序暂存段数上界 fatal。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.frame,
  nextpas.core.net.quic.stream,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

type
  TDataRec = record
    Id: UInt64;
    Data: string;
    Fin: Boolean;
  end;

{ 回调收集器 }
type
  TCollector = class
  public
    Items: array[0..63] of TDataRec;
    Count: Integer;
    ResetIds: array[0..15] of UInt64;
    ResetErrs: array[0..15] of UInt64;
    ResetCount: Integer;
    Fatals: Integer;
    LastFatal: string;
    procedure OnData(AStreamId: UInt64; const AData: TBytes;
      AFin: Boolean);
    procedure OnReset(AStreamId, AErrorCode: UInt64);
    procedure OnFatal(const AReason: string);
    procedure Clear;
  end;

procedure TCollector.OnData(AStreamId: UInt64; const AData: TBytes;
  AFin: Boolean);
var
  LI: Integer;
begin
  if Count <= High(Items) then
  begin
    Items[Count].Id := AStreamId;
    Items[Count].Data := '';
    for LI := 0 to Length(AData) - 1 do
      Items[Count].Data := Items[Count].Data + Chr(AData[LI]);
    Items[Count].Fin := AFin;
    Inc(Count);
  end;
end;

procedure TCollector.OnReset(AStreamId, AErrorCode: UInt64);
begin
  if ResetCount <= High(ResetIds) then
  begin
    ResetIds[ResetCount] := AStreamId;
    ResetErrs[ResetCount] := AErrorCode;
    Inc(ResetCount);
  end;
end;

procedure TCollector.OnFatal(const AReason: string);
begin
  Inc(Fatals);
  LastFatal := AReason;
end;

procedure TCollector.Clear;
begin
  Count := 0;
  ResetCount := 0;
  Fatals := 0;
  LastFatal := '';
end;

function StrBytes(const AText: string): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, Length(AText));
  for LI := 1 to Length(AText) do
    Result[LI - 1] := Byte(Ord(AText[LI]));
end;

function MkRanges(ALo, AHi: UInt64): TQuicAckRangeArray;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0].Lo := ALo;
  Result[0].Hi := AHi;
end;

{ 解析 APayload 首帧并断言为期望的 STREAM 帧 }
procedure CheckStreamFrame(const APayload: TBytes; AExpId,
  AExpOffset: UInt64; const AExpText: string; AExpFin: Boolean);
var
  LF: TQuicFrame;
  LI: Integer;
  LText: string;
begin
  CheckTrue(TryQuicFrameParse(APayload, 0, Length(APayload), LF),
    'frame parse');
  CheckEqual(Int64(Ord(qfkStream)), Int64(Ord(LF.Kind)));
  CheckEqual(UInt64(AExpId), LF.StreamId);
  CheckEqual(UInt64(AExpOffset), LF.Offset);
  CheckEqual(Length(AExpText), LF.DataLen);
  CheckEqual(AExpFin, LF.Fin);
  LText := '';
  for LI := 0 to LF.DataLen - 1 do
    LText := LText + Chr(APayload[LF.DataOfs + LI]);
  CheckTrue(LText = AExpText, 'payload text');
end;

function MkMux: TQuicStreamMux;
begin
  Result := TQuicStreamMux.Create(65536, 65536);
  Result.ApplyPeerGrants(65536, 4096, 4096, 4096, 8, 8);
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
  GColl: TCollector;

begin
  GColl := TCollector.Create;

  LSuite := TTestSuite.Create('quic_streams');

  { ---------- 流号分配 ---------- }
  LSuite.Test('stream id allocation and max streams gate', procedure
  var
    LMux: TQuicStreamMux;
    LId: UInt64;
  begin
    LMux := TQuicStreamMux.Create(65536, 65536);
    try
      CheckFalse(LMux.OpenBidi(LId), 'no grant yet');
      CheckFalse(LMux.OpenUni(LId), 'no uni grant yet');
      LMux.ApplyPeerGrants(65536, 4096, 4096, 4096, 2, 1);
      CheckTrue(LMux.OpenBidi(LId));
      CheckEqual(UInt64(0), LId);
      CheckTrue(LMux.OpenBidi(LId));
      CheckEqual(UInt64(4), LId);
      CheckFalse(LMux.OpenBidi(LId), 'bidi grant exhausted');
      CheckTrue(LMux.OpenUni(LId));
      CheckEqual(UInt64(2), LId);
      CheckFalse(LMux.OpenUni(LId), 'uni grant exhausted');
      LMux.HandleMaxStreams(True, 3);
      CheckTrue(LMux.OpenBidi(LId));
      CheckEqual(UInt64(8), LId);
      LMux.HandleMaxStreams(False, 5);
      CheckTrue(LMux.OpenUni(LId));
      CheckEqual(UInt64(6), LId);
    finally
      LMux.Free;
    end;
  end);

  { ---------- 发送路径 ---------- }
  LSuite.Test('stream frame wire format roundtrip with fin', procedure
  var
    LMux: TQuicStreamMux;
    LBuf: TBytes;
    LId: UInt64;
  begin
    LMux := MkMux;
    try
      CheckTrue(LMux.OpenBidi(LId));
      CheckTrue(LMux.StreamWrite(0, nil, False));   { 空非 FIN 幂等 }
      CheckTrue(LMux.StreamWrite(0, StrBytes('hello'), False));
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 512));
      CheckStreamFrame(LBuf, 0, 0, 'hello', False);
      LMux.CommitSent(7);
      CheckTrue(LMux.StreamWrite(0, StrBytes('world'), True));
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 512));
      CheckStreamFrame(LBuf, 0, 5, 'world', True);
      LMux.CommitSent(8);
      CheckFalse(LMux.StreamWrite(0, StrBytes('x'), False),
        'write after fin rejected');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('connection level clamp with blocked announce', procedure
  var
    LMux: TQuicStreamMux;
    LBuf: TBytes;
    LId: UInt64;
    LF: TQuicFrame;
    LPos: Integer;
    LBlockedAt: Integer;
  begin
    LMux := TQuicStreamMux.Create(65536, 65536);
    try
      LMux.ApplyPeerGrants(10, 100, 100, 100, 8, 8);  { 连接级仅 10B }
      LMux.OpenBidi(LId);
      LMux.StreamWrite(0, StrBytes('abcdefghijklmnopqrst'), False);
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 4096));
      { 首 chunk 恰 10 字节，同包直出 DATA_BLOCKED(10) }
      CheckStreamFrame(LBuf, 0, 0, 'abcdefghij', False);
      LPos := 0;
      CheckTrue(TryQuicFrameParse(LBuf, LPos, Length(LBuf), LF));
      Inc(LPos, LF.Consumed);
      LBlockedAt := -1;
      while LPos < Length(LBuf) do
      begin
        if TryQuicFrameParse(LBuf, LPos, Length(LBuf), LF) then
        begin
          if Ord(LF.Kind) = Ord(qfkDataBlocked) then
          begin
            LBlockedAt := LPos;
            CheckEqual(UInt64(10), LF.MaxValue);
            Break;
          end;
          Inc(LPos, LF.Consumed);
        end
        else
          Break;
      end;
      CheckTrue(LBlockedAt >= 0, 'DATA_BLOCKED inline');
      LMux.CommitSent(1);
      CheckEqual(UInt64(10), LMux.ConnBudget.Frontier);
      { 已通告过且无预算：再次收集无产出 }
      LBuf := nil;
      CheckFalse(LMux.CollectFrames(LBuf, 4096), 'announced once');
      { 授权扩到 30：续发剩余 10 字节 }
      LMux.HandleMaxData(30);
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 4096));
      CheckStreamFrame(LBuf, 0, 10, 'klmnopqrst', False);
      LMux.CommitSent(2);
      CheckEqual(UInt64(20), LMux.ConnBudget.Frontier);
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('stream clamp queues stream data blocked', procedure
  var
    LMux: TQuicStreamMux;
    LBuf: TBytes;
    LId: UInt64;
    LF: TQuicFrame;
    LPos: Integer;
    LFound, LChunkOk: Boolean;
  begin
    LMux := TQuicStreamMux.Create(65536, 65536);
    try
      LMux.ApplyPeerGrants(1024, 6, 6, 6, 8, 8);   { 流级仅 6B }
      LMux.OpenBidi(LId);
      CheckEqual(UInt64(0), LId);
      CheckTrue(LMux.StreamWrite(0, StrBytes('0123456789'), False));
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 4096));
      { 首 chunk 恰 6 字节，同包直出 STREAM_DATA_BLOCKED(6) }
      LFound := False;
      LChunkOk := False;
      LPos := 0;
      while LPos < Length(LBuf) do
      begin
        if TryQuicFrameParse(LBuf, LPos, Length(LBuf), LF) then
        begin
          if Ord(LF.Kind) = Ord(qfkStreamDataBlocked) then
          begin
            LFound := True;
            CheckEqual(UInt64(0), LF.StreamId);
            CheckEqual(UInt64(6), LF.MaxValue);
            Break;
          end
          else if Ord(LF.Kind) = Ord(qfkStream) then
          begin
            LChunkOk := True;
            CheckEqual(UInt64(0), LF.Offset);
            CheckEqual(6, LF.DataLen);
          end;
          Inc(LPos, LF.Consumed);
        end
        else
          Break;
      end;
      CheckTrue(LChunkOk, 'six byte chunk emitted');
      CheckTrue(LFound, 'STREAM_DATA_BLOCKED inline');
      LMux.CommitSent(1);
      { 已通告过：再次收集无产出；流级扩容后续发余量 }
      LBuf := nil;
      CheckFalse(LMux.CollectFrames(LBuf, 4096), 'announced once');
      LMux.HandleMaxStreamData(0, 20);
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 4096));
      CheckStreamFrame(LBuf, 0, 6, '6789', False);
      LMux.CommitSent(2);
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('rollback staged restores send state', procedure
  var
    LMux: TQuicStreamMux;
    LBuf: TBytes;
    LId: UInt64;
  begin
    LMux := MkMux;
    try
      LMux.OpenBidi(LId);
      LMux.StreamWrite(0, StrBytes('hello'), True);
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 512));
      LMux.RollbackStaged;   { 封包失败形态 }
      CheckEqual(UInt64(0), LMux.ConnBudget.Frontier,
        'billing not committed');
      { 重收集产出同一区间（含 FIN） }
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 512));
      CheckStreamFrame(LBuf, 0, 0, 'hello', True);
      LMux.CommitSent(3);
      CheckEqual(UInt64(5), LMux.ConnBudget.Frontier);
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('loss retransmit same offsets without rebilling', procedure
  var
    LMux: TQuicStreamMux;
    LBuf: TBytes;
    LId: UInt64;
  begin
    LMux := MkMux;
    try
      LMux.OpenBidi(LId);
      LMux.StreamWrite(0, StrBytes('abcdefghij'), False);
      LBuf := nil;
      LMux.CollectFrames(LBuf, 512);
      LMux.CommitSent(9);
      CheckEqual(UInt64(10), LMux.ConnBudget.Frontier);
      { PN=9 判丢 → 重发同偏移且不计费 }
      LMux.OnLostPns([UInt64(9)]);
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 512));
      CheckStreamFrame(LBuf, 0, 0, 'abcdefghij', False);
      LMux.CommitSent(11);
      CheckEqual(UInt64(10), LMux.ConnBudget.Frontier,
        'retransmit not billed');
      { ACK 全部 → 重发源消失、缓冲裁剪，再收集无产出 }
      LMux.OnAckRanges(MkRanges(0, 11));
      LBuf := nil;
      CheckFalse(LMux.CollectFrames(LBuf, 512),
        'all settled, nothing to emit');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('multi stream chunks interleave in one collect', procedure
  var
    LMux: TQuicStreamMux;
    LBuf: TBytes;
    LIdA, LIdB: UInt64;
    LF: TQuicFrame;
    LSeenA, LSeenB: Boolean;
    LPos: Integer;
    LText: string;
    LI: Integer;
  begin
    LMux := MkMux;
    try
      LMux.OpenBidi(LIdA);
      LMux.OpenBidi(LIdB);
      LMux.StreamWrite(0, StrBytes('aaaa'), False);
      LMux.StreamWrite(4, StrBytes('bbbbbb'), False);
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 4096));
      LSeenA := False;
      LSeenB := False;
      LPos := 0;
      while LPos < Length(LBuf) do
      begin
        CheckTrue(TryQuicFrameParse(LBuf, LPos, Length(LBuf), LF));
        if LF.StreamId = 0 then
        begin
          LSeenA := True;
          CheckEqual(4, LF.DataLen, 'stream0 chunk');
        end
        else
        begin
          LSeenB := True;
          CheckEqual(6, LF.DataLen, 'stream4 chunk');
          LText := '';
          for LI := 0 to LF.DataLen - 1 do
            LText := LText + Chr(LBuf[LF.DataOfs + LI]);
          CheckTrue(LText = 'bbbbbb', 'stream4 text');
        end;
        Inc(LPos, LF.Consumed);
      end;
      CheckTrue(LSeenA, 'both streams emitted');
      CheckTrue(LSeenB, 'both streams emitted (b)');
    finally
      LMux.Free;
    end;
  end);

  { ---------- 接收路径 ---------- }
  LSuite.Test('out of order reassembly delivers in order', procedure
  var
    LMux: TQuicStreamMux;
    LId: UInt64;
  begin
    GColl.Clear;
    LMux := MkMux;
    try
      LMux.OnStreamData := @GColl.OnData;
      { 服务端发起 bidi 流 id=1 }
      LMux.HandleStreamData(1, 10, StrBytes('KLMNO'), False);
      CheckEqual(0, GColl.Count, 'gap holds delivery');
      LMux.HandleStreamData(1, 0, StrBytes('ABCDE'), False);
      CheckEqual(1, GColl.Count);
      CheckTrue(GColl.Items[0].Data = 'ABCDE', 'first window');
      CheckEqual(UInt64(1), GColl.Items[0].Id);
      LMux.HandleStreamData(1, 5, StrBytes('FGHIJ'), False);
      CheckEqual(3, GColl.Count);
      CheckTrue(GColl.Items[1].Data = 'FGHIJ', 'second window');
      CheckTrue(GColl.Items[2].Data = 'KLMNO', 'drained gap');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('duplicate and overlap clipped against frontier', procedure
  var
    LMux: TQuicStreamMux;
  begin
    GColl.Clear;
    LMux := MkMux;
    try
      LMux.OnStreamData := @GColl.OnData;
      LMux.HandleStreamData(3, 0, StrBytes('ABCD'), False);   { uni 流 }
      CheckEqual(1, GColl.Count);
      LMux.HandleStreamData(3, 0, StrBytes('ABCD'), False);   { 全重复 }
      CheckEqual(1, GColl.Count, 'dup ignored');
      LMux.HandleStreamData(3, 2, StrBytes('CDEF'), False);   { 部分重叠 }
      CheckEqual(2, GColl.Count);
      CheckTrue(GColl.Items[1].Data = 'EF', 'only novel suffix');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('fin delivered exactly at contiguous frontier', procedure
  var
    LMux: TQuicStreamMux;
  begin
    GColl.Clear;
    LMux := MkMux;
    try
      LMux.OnStreamData := @GColl.OnData;
      LMux.OnFatal := @GColl.OnFatal;
      LMux.HandleStreamData(1, 0, StrBytes('ab'), True);
      CheckEqual(2, GColl.Count);
      CheckTrue(GColl.Items[0].Data = 'ab', 'data first');
      CheckFalse(GColl.Items[0].Fin);
      CheckTrue(GColl.Items[1].Fin, 'fin second');
      CheckEqual(0, Length(GColl.Items[1].Data), 'zero length fin');
      { 数据越过 final size → 连接错误 }
      LMux.HandleStreamData(1, 2, StrBytes('cd'), False);
      CheckEqual(1, GColl.Fatals, 'data beyond final size is fatal');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('out of order fin delivered after gap fill', procedure
  var
    LMux: TQuicStreamMux;
  begin
    GColl.Clear;
    LMux := MkMux;
    try
      LMux.OnStreamData := @GColl.OnData;
      LMux.HandleStreamData(1, 3, StrBytes('XYZ'), True);   { final=6 }
      CheckEqual(0, GColl.Count);
      LMux.HandleStreamData(1, 0, StrBytes('abc'), False);
      CheckEqual(3, GColl.Count);
      CheckTrue(GColl.Items[0].Data = 'abc', 'first');
      CheckTrue(GColl.Items[1].Data = 'XYZ', 'held');
      CheckTrue(GColl.Items[2].Fin, 'fin last');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('reset stream discards buffered and aborts', procedure
  var
    LMux: TQuicStreamMux;
  begin
    GColl.Clear;
    LMux := MkMux;
    try
      LMux.OnStreamData := @GColl.OnData;
      LMux.OnStreamReset := @GColl.OnReset;
      LMux.HandleStreamData(1, 0, StrBytes('hello'), False);
      CheckEqual(1, GColl.Count);
      LMux.HandleResetStream(1, 42, 12);
      CheckEqual(1, GColl.ResetCount);
      CheckEqual(UInt64(1), GColl.ResetIds[0]);
      CheckEqual(UInt64(42), GColl.ResetErrs[0]);
      { RESET 之后的数据静默丢弃 }
      LMux.HandleStreamData(1, 5, StrBytes('world'), False);
      CheckEqual(1, GColl.Count, 'post-reset data dropped');
      CheckEqual(0, GColl.Fatals, 'post-reset not fatal');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('reset conflicts are fail closed', procedure
  var
    LMux: TQuicStreamMux;
  begin
    GColl.Clear;
    LMux := MkMux;
    try
      LMux.OnStreamData := @GColl.OnData;
      LMux.OnFatal := @GColl.OnFatal;
      { final size 冲突：先 FIN 定 5 再 RESET 定 7 }
      LMux.HandleStreamData(1, 0, StrBytes('abcde'), True);
      LMux.HandleResetStream(1, 9, 7);
      CheckEqual(1, GColl.Fatals, 'final size conflict');
      { RESET 终点低于已收数据 }
      LMux.HandleStreamData(3, 0, StrBytes('01234567'), False);
      LMux.HandleResetStream(3, 9, 5);
      CheckEqual(2, GColl.Fatals, 'reset below received');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('stop sending queues reset stream reply', procedure
  var
    LMux: TQuicStreamMux;
    LBuf: TBytes;
    LId: UInt64;
    LF: TQuicFrame;
  begin
    LMux := MkMux;
    try
      LMux.OpenBidi(LId);
      LMux.StreamWrite(0, StrBytes('abc'), False);
      LBuf := nil;
      LMux.CollectFrames(LBuf, 512);
      LMux.CommitSent(1);   { SentHi=3 }
      LMux.HandleStopSending(0, 99);
      LBuf := nil;
      CheckTrue(LMux.CollectFrames(LBuf, 512));
      CheckTrue(TryQuicFrameParse(LBuf, 0, Length(LBuf), LF));
      CheckEqual(Int64(Ord(qfkResetStream)), Int64(Ord(LF.Kind)));
      CheckEqual(UInt64(0), LF.StreamId);
      CheckEqual(UInt64(99), LF.ErrorCode);
      CheckEqual(UInt64(3), LF.FinalSize, 'final size equals sent');
      { 复位后禁止续写 }
      CheckFalse(LMux.StreamWrite(0, StrBytes('x'), False),
        'write after reset rejected');
    finally
      LMux.Free;
    end;
  end);

  { ---------- 有界纪律 ---------- }
  LSuite.Test('send buffer cap enforced', procedure
  var
    LMux: TQuicStreamMux;
    LBig: TBytes;
    LId: UInt64;
    LI: Integer;
  begin
    LMux := MkMux;
    try
      LMux.OpenBidi(LId);
      SetLength(LBig, 200000);
      for LI := 0 to High(LBig) do
        LBig[LI] := Byte(LI and $FF);
      CheckTrue(LMux.StreamWrite(0, LBig, False));
      CheckFalse(LMux.StreamWrite(0, LBig, False),
        'second write exceeds cap');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('reorder hold bound fails closed', procedure
  var
    LMux: TQuicStreamMux;
    LOne: TBytes;
    LI: Integer;
  begin
    GColl.Clear;
    LMux := MkMux;
    try
      LMux.OnStreamData := @GColl.OnData;
      LMux.OnFatal := @GColl.OnFatal;
      SetLength(LOne, 1);
      LOne[0] := Ord('z');
      { 34 个互不相邻单字节段：offset 0 首段即时交付，其余滞留；
        第 33 个滞留段触发 HoldBound=32 fail-closed }
      for LI := 0 to 33 do
        LMux.HandleStreamData(1, UInt64(LI * 2), LOne, False);
      CheckEqual(1, GColl.Fatals, 'reorder beyond bound fatal');
      CheckEqual(1, GColl.Count, 'only offset-0 byte delivered');
    finally
      LMux.Free;
    end;
  end);

  LSuite.Test('non peer originated id rejected', procedure
  var
    LMux: TQuicStreamMux;
  begin
    GColl.Clear;
    LMux := MkMux;
    try
      LMux.OnFatal := @GColl.OnFatal;
      LMux.HandleStreamData(0, 0, StrBytes('x'), False);   { 本端号 }
      CheckEqual(1, GColl.Fatals, 'client-owned id from peer');
    finally
      LMux.Free;
    end;
  end);

  { ---------- 源码契约 ---------- }
  LSuite.Test('source contract: no bare FPC RTL in stream unit', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..', 'src', 'nextpas.core.net.quic.stream.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'no bare FPC RTL (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.streams');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  GColl.Free;
  if not LRunner.AllPassed then Halt(1);
end.
