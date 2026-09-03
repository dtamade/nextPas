unit nextpas.core.db.pool.leak;

{** @desc db.pool 泄漏检测与簿记子模块（L2 基础设施，CONTRACT §2.7）。
       职责：Outstanding 租约簿记、到期扫描、快照格式化与 pending 积压。
       归属：leak 拥有 TPoolOutstanding/TPoolLeakSnap/TPoolLeakSnaps 与全部簿记原语，impl 仅薄委托；
       复用 bytes.ops 单源（GrowCap 经 BytesGrowCapacityWithMin 单源；格式化冷路径纯串拼接单次分配零 bytes 双转换/BytesAppend）与统一日志质感（ILogger.Warn 零 StdErr 裸写），性能 inline 零拷贝。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.collections.smallvec,
  nextpas.core.log.intf,
  nextpas.core.db.pool.base;



type
  TPoolOutstanding = record
    Obj: TObject;
    Tick: QWord;
    Warned: Boolean;
    IsWriter: Boolean;
    Frames: array[0..15] of CodePointer;
    FrameCount: Integer;
  end;
  TPoolOutstandingVec = specialize TSmallVec<TPoolOutstanding, 8>;
  TPoolOutstandingArray = array of TPoolOutstanding;

  TPoolLeakSnap = record
    HeldMs: QWord;
    Threshold: Integer;
    IsWriter: Boolean;
    FrameCount: Integer;
    Frames: array[0..15] of CodePointer;
  end;

  TPoolLeakSnaps = array of TPoolLeakSnap;

function PoolLeakGrowCap(const AOld, ARequired: SizeUInt): SizeUInt; inline;

procedure PoolLeaseRegisterLocked(var AOutstanding: TPoolOutstandingArray; var ACount: Integer;
  var ALeakNextDue: QWord; AObj: TObject; const ATick: QWord;
  const AIsWriter: Boolean; const AFrames: PCodePointer; const ACountFrames: Integer;
  const APolicy: TDbPoolPolicy);

procedure PoolLeaseUnregisterLocked(var AOutstanding: array of TPoolOutstanding; var ACount: Integer;
  var ALeakNextDue: QWord; AObj: TObject; const APolicy: TDbPoolPolicy);

procedure PoolLeakCollectDueLocked(var AOutstanding: array of TPoolOutstanding; var ACount: Integer;
  var ALeakNextDue: QWord; const ANow: QWord; out ASnaps: TPoolLeakSnaps; const APolicy: TDbPoolPolicy);
// collections 小容器复用：impl 改由 TSmallVec 单源（栈内联 8 + 堆 1.5x 增长，单 Move 零拷贝，零手算 GrowCap）
procedure PoolLeaseRegisterVec(var AVec: TPoolOutstandingVec;
  var ALeakNextDue: QWord; AObj: TObject; const ATick: QWord;
  const AIsWriter: Boolean; const AFrames: PCodePointer; const ACountFrames: Integer;
  const APolicy: TDbPoolPolicy); inline;
procedure PoolLeaseUnregisterVec(var AVec: TPoolOutstandingVec;
  var ALeakNextDue: QWord; AObj: TObject; const APolicy: TDbPoolPolicy);
procedure PoolLeakCollectDueVec(var AVec: TPoolOutstandingVec;
  var ALeakNextDue: QWord; const ANow: QWord; out ASnaps: TPoolLeakSnaps; const APolicy: TDbPoolPolicy);

{ 零拷贝：冷路径纯串拼接单次分配，逐帧 '  '+BackTrace 单分配，零 bytes 中间态/双转换/BytesAppend，多 Move 由 FPC 单次串分配内建保证，统一经 ILogger 质感 }
function PoolLeakFormatSnaps(const ASnaps: TPoolLeakSnaps): TDbPoolLeakReports;

procedure PoolLeakAppendPendingLocked(var APending: TDbPoolLeakReports; const AReports: TDbPoolLeakReports);
procedure PoolLeakTakePendingLocked(var APending: TDbPoolLeakReports; out AReports: TDbPoolLeakReports);
procedure PoolLeakFireReports(const AReports: TDbPoolLeakReports; const APolicy: TDbPoolPolicy);

implementation

uses
  nextpas.core.text.conv;

function PoolLeakGrowCap(const AOld, ARequired: SizeUInt): SizeUInt; inline;
begin
  Result := BytesGrowCapacityWithMin(AOld, ARequired, 4);
end;

procedure PoolLeaseRegisterLocked(var AOutstanding: TPoolOutstandingArray; var ACount: Integer;
  var ALeakNextDue: QWord; AObj: TObject; const ATick: QWord;
  const AIsWriter: Boolean; const AFrames: PCodePointer; const ACountFrames: Integer;
  const APolicy: TDbPoolPolicy);
var
  N, Cap, NewCap, K: Integer;
  LDue: QWord;
begin
  N := ACount;
  Cap := Length(AOutstanding);
  if N >= Cap then
  begin
    NewCap := Integer(PoolLeakGrowCap(SizeUInt(Cap), SizeUInt(N + 1)));
    SetLength(AOutstanding, NewCap);
    N := ACount;
  end;
  AOutstanding[N].Obj := AObj;
  AOutstanding[N].Tick := ATick;
  AOutstanding[N].Warned := False;
  AOutstanding[N].IsWriter := AIsWriter;
  AOutstanding[N].FrameCount := 0;
  if (AFrames <> nil) and (ACountFrames > 0) then
  begin
    K := ACountFrames;
    if K > Length(AOutstanding[N].Frames) then
      K := Length(AOutstanding[N].Frames);
    Move(AFrames^, AOutstanding[N].Frames, SizeOf(CodePointer) * K);
    AOutstanding[N].FrameCount := K;
  end;
  Inc(ACount);
  if APolicy.LeakDetectionThresholdMs > 0 then
  begin
    LDue := ATick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
    if LDue < ALeakNextDue then
      ALeakNextDue := LDue;
  end;
end;

procedure PoolLeaseUnregisterLocked(var AOutstanding: array of TPoolOutstanding; var ACount: Integer;
  var ALeakNextDue: QWord; AObj: TObject; const APolicy: TDbPoolPolicy);
var
  I, LLast: Integer;
  LRemovedTick: QWord;
  LRemovedDue: QWord;
  LNeedRecalc: Boolean;
begin
  LNeedRecalc := False;
  for I := ACount - 1 downto 0 do
    if AOutstanding[I].Obj = AObj then
    begin
      if (APolicy.LeakDetectionThresholdMs > 0) and not AOutstanding[I].Warned then
      begin
        LRemovedTick := AOutstanding[I].Tick;
        LRemovedDue := LRemovedTick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
        if LRemovedDue = ALeakNextDue then
          LNeedRecalc := True;
      end;
      LLast := ACount - 1;
      AOutstanding[I] := AOutstanding[LLast];
      AOutstanding[LLast] := Default(TPoolOutstanding);
      Dec(ACount);
      if LNeedRecalc then
      begin
        if ACount = 0 then
          ALeakNextDue := High(QWord)
        else
        begin
          ALeakNextDue := High(QWord);
          for LLast := 0 to ACount - 1 do
            if not AOutstanding[LLast].Warned then
            begin
              LRemovedDue := AOutstanding[LLast].Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
              if LRemovedDue < ALeakNextDue then
                ALeakNextDue := LRemovedDue;
            end;
        end;
      end;
      Exit;
    end;
end;

procedure PoolLeakCollectDueLocked(var AOutstanding: array of TPoolOutstanding; var ACount: Integer;
  var ALeakNextDue: QWord; const ANow: QWord; out ASnaps: TPoolLeakSnaps; const APolicy: TDbPoolPolicy);
var
  I, Need, FillIdx: Integer;
  LNextDue, LDue: QWord;
begin
  SetLength(ASnaps, 0);
  if APolicy.LeakDetectionThresholdMs <= 0 then
    Exit;
  if ANow < ALeakNextDue then
    Exit;
  LNextDue := High(QWord);
  Need := 0;
  for I := 0 to ACount - 1 do
  begin
    if AOutstanding[I].Warned then
      Continue;
    LDue := AOutstanding[I].Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
    if ANow < LDue then
    begin
      if LDue < LNextDue then
        LNextDue := LDue;
      Continue;
    end;
    Inc(Need);
  end;
  if Need = 0 then
  begin
    ALeakNextDue := LNextDue;
    Exit;
  end;
  SetLength(ASnaps, Need);
  FillIdx := 0;
  for I := 0 to ACount - 1 do
  begin
    if AOutstanding[I].Warned then
      Continue;
    LDue := AOutstanding[I].Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
    if ANow < LDue then
      Continue;
    ASnaps[FillIdx].HeldMs := (ANow - AOutstanding[I].Tick) div 1000000;
    ASnaps[FillIdx].Threshold := APolicy.LeakDetectionThresholdMs;
    ASnaps[FillIdx].IsWriter := AOutstanding[I].IsWriter;
    ASnaps[FillIdx].FrameCount := AOutstanding[I].FrameCount;
    if ASnaps[FillIdx].FrameCount > 0 then
      Move(AOutstanding[I].Frames, ASnaps[FillIdx].Frames,
        SizeOf(CodePointer) * ASnaps[FillIdx].FrameCount);
    AOutstanding[I].Warned := True;
    Inc(FillIdx);
  end;
  ALeakNextDue := LNextDue;
end;

function PoolLeakFormatSnaps(const ASnaps: TPoolLeakSnaps): TDbPoolLeakReports;
var
  I, J, Need, FillIdx: Integer;
  LRole: string;
begin
  Result := nil;
  if Length(ASnaps) = 0 then
    Exit;
  Need := 0;
  for I := 0 to High(ASnaps) do
    Need := Need + 1 + ASnaps[I].FrameCount;
  SetLength(Result, Need);
  FillIdx := 0;
  for I := 0 to High(ASnaps) do
  begin
    if ASnaps[I].IsWriter then
      LRole := 'writer'
    else
      LRole := 'read';
    // 冷路径零拷贝：纯串拼接单次分配，逐帧 '  '+BackTrace 单分配，零 bytes 中间态/双转换/BytesAppend 多次中小分配；单 Move 语义由 FPC 串拼接内建保证
    Result[FillIdx] := 'pool: lease leak suspected — held ' + IntToStr(Int64(ASnaps[I].HeldMs))
      + 'ms (threshold ' + IntToStr(Int64(ASnaps[I].Threshold)) + 'ms), ' + LRole + ' lease';
    Inc(FillIdx);
    for J := 0 to ASnaps[I].FrameCount - 1 do
    begin
      Result[FillIdx] := '  ' + BackTraceStrFunc(ASnaps[I].Frames[J]);
      Inc(FillIdx);
    end;
  end;
end;

procedure PoolLeakAppendPendingLocked(var APending: TDbPoolLeakReports; const AReports: TDbPoolLeakReports);
var
  OldLen, Need, I: Integer;
begin
  if Length(AReports) = 0 then
    Exit;
  OldLen := Length(APending);
  Need := OldLen + Length(AReports);
  if Need > Length(APending) then
    SetLength(APending, Need);
  for I := 0 to High(AReports) do
    APending[OldLen + I] := AReports[I];
end;

procedure PoolLeakTakePendingLocked(var APending: TDbPoolLeakReports; out AReports: TDbPoolLeakReports);
begin
  AReports := APending;
  APending := nil;
end;

procedure PoolLeakFireReports(const AReports: TDbPoolLeakReports; const APolicy: TDbPoolPolicy);
var
  I: Integer;
  LEvent: TDbPoolLeakEvent;
  LLogger: ILogger;
begin
  LEvent := APolicy.OnLeakDetected;
  LLogger := APolicy.LeakLogger;
  if LLogger = nil then
    LLogger := NullLogger;
  for I := 0 to High(AReports) do
  begin
    if Assigned(LEvent) then
      LEvent(AReports[I])
    else
      LLogger.Warn(AReports[I]);
  end;
end;

procedure PoolLeaseRegisterVec(var AVec: TPoolOutstandingVec;
  var ALeakNextDue: QWord; AObj: TObject; const ATick: QWord;
  const AIsWriter: Boolean; const AFrames: PCodePointer; const ACountFrames: Integer;
  const APolicy: TDbPoolPolicy); inline;
var
  E: TPoolOutstanding;
  K: Integer;
  LDue: QWord;
begin
  E.Obj := AObj;
  E.Tick := ATick;
  E.Warned := False;
  E.IsWriter := AIsWriter;
  E.FrameCount := 0;
  if (AFrames <> nil) and (ACountFrames > 0) then
  begin
    K := ACountFrames;
    if K > Length(E.Frames) then K := Length(E.Frames);
    Move(AFrames^, E.Frames, SizeOf(CodePointer) * K);
    E.FrameCount := K;
  end;
  AVec.Push(E);
  if APolicy.LeakDetectionThresholdMs > 0 then
  begin
    LDue := ATick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
    if LDue < ALeakNextDue then ALeakNextDue := LDue;
  end;
end;

procedure PoolLeaseUnregisterVec(var AVec: TPoolOutstandingVec;
  var ALeakNextDue: QWord; AObj: TObject; const APolicy: TDbPoolPolicy);
var
  I, N, LLast: Integer;
  LRemovedDue: QWord;
  LNeedRecalc: Boolean;
  E: TPoolOutstanding;
begin
  N := Integer(AVec.Count);
  LNeedRecalc := False;
  for I := N - 1 downto 0 do
    if AVec.Get(SizeUInt(I)).Obj = AObj then
    begin
      E := AVec.Get(SizeUInt(I));
      if (APolicy.LeakDetectionThresholdMs > 0) and not E.Warned then
      begin
        LRemovedDue := E.Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
        if LRemovedDue = ALeakNextDue then LNeedRecalc := True;
      end;
      LLast := N - 1;
      if I <> LLast then
      begin
        AVec.Put(SizeUInt(I), AVec.Get(SizeUInt(LLast)));
      end;
      AVec.Pop(E);
      if LNeedRecalc then
      begin
        if AVec.Count = 0 then ALeakNextDue := High(QWord)
        else
        begin
          ALeakNextDue := High(QWord);
          for LLast := 0 to Integer(AVec.Count) - 1 do
          begin
            E := AVec.Get(SizeUInt(LLast));
            if not E.Warned then
            begin
              LRemovedDue := E.Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
              if LRemovedDue < ALeakNextDue then ALeakNextDue := LRemovedDue;
            end;
          end;
        end;
      end;
      Exit;
    end;
end;

procedure PoolLeakCollectDueVec(var AVec: TPoolOutstandingVec;
  var ALeakNextDue: QWord; const ANow: QWord; out ASnaps: TPoolLeakSnaps; const APolicy: TDbPoolPolicy);
var
  I, Need, FillIdx, N: Integer;
  LNextDue, LDue: QWord;
  E: TPoolOutstanding;
begin
  SetLength(ASnaps, 0);
  if APolicy.LeakDetectionThresholdMs <= 0 then Exit;
  if ANow < ALeakNextDue then Exit;
  N := Integer(AVec.Count);
  LNextDue := High(QWord);
  Need := 0;
  for I := 0 to N - 1 do
  begin
    E := AVec.Get(SizeUInt(I));
    if E.Warned then Continue;
    LDue := E.Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
    if ANow < LDue then
    begin
      if LDue < LNextDue then LNextDue := LDue;
      Continue;
    end;
    Inc(Need);
  end;
  if Need = 0 then
  begin
    ALeakNextDue := LNextDue;
    Exit;
  end;
  SetLength(ASnaps, Need);
  FillIdx := 0;
  for I := 0 to N - 1 do
  begin
    E := AVec.Get(SizeUInt(I));
    if E.Warned then Continue;
    LDue := E.Tick + QWord(APolicy.LeakDetectionThresholdMs) * 1000000;
    if ANow < LDue then Continue;
    ASnaps[FillIdx].HeldMs := (ANow - E.Tick) div 1000000;
    ASnaps[FillIdx].Threshold := APolicy.LeakDetectionThresholdMs;
    ASnaps[FillIdx].IsWriter := E.IsWriter;
    ASnaps[FillIdx].FrameCount := E.FrameCount;
    if E.FrameCount > 0 then
      Move(E.Frames, ASnaps[FillIdx].Frames, SizeOf(CodePointer) * E.FrameCount);
    E.Warned := True;
    AVec.Put(SizeUInt(I), E);
    Inc(FillIdx);
  end;
  ALeakNextDue := LNextDue;
end;

end.
