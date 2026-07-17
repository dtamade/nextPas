{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_timeseries_ringbuffer;

uses
  nextpas.core.text.conv,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.lockfree.timeseries_ringbuffer;

var
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure Test_Empty;
var
  LBuf: TTimeSeriesRingBuffer;
  LEntry: TTSRingEntry;
begin
  WriteLn('--- Empty ---');
  LBuf := TTimeSeriesRingBuffer.Create(10, 60000);
  try
    Check(LBuf.Count = 0, 'empty count = 0');
    Check(LBuf.IsEmpty, 'empty is empty');
    Check(not LBuf.IsFull, 'empty not full');
    Check(LBuf.Latest(LEntry) = tsrEmpty, 'empty latest = empty');
    Check(LBuf.GetCapacity = 10, 'capacity = 10');
  finally
    LBuf.Free;
  end;
end;

procedure Test_Append;
var
  LBuf: TTimeSeriesRingBuffer;
  LEntry: TTSRingEntry;
begin
  WriteLn('--- Append ---');
  LBuf := TTimeSeriesRingBuffer.Create(10, 60000);
  try
    Check(LBuf.Append('hello') = tsrOk, 'append hello');
    Check(LBuf.Count = 1, 'count = 1');
    Check(not LBuf.IsEmpty, 'not empty');
    Check(LBuf.Latest(LEntry) = tsrOk, 'latest ok');
    Check(LEntry.Value = 'hello', 'latest = hello');
  finally
    LBuf.Free;
  end;
end;

procedure Test_WrapAround;
var
  LBuf: TTimeSeriesRingBuffer;
  LEntry: TTSRingEntry;
  I: Int32;
begin
  WriteLn('--- WrapAround ---');
  LBuf := TTimeSeriesRingBuffer.Create(5, 60000);
  try
    for I := 1 to 10 do
      LBuf.Append('val' + IntToStr(I));
    Check(LBuf.Count = 5, 'count = 5 after wrap');
    Check(LBuf.IsFull, 'is full');
    Check(LBuf.Latest(LEntry) = tsrOk, 'latest ok');
    Check(LEntry.Value = 'val10', 'latest = val10');
  finally
    LBuf.Free;
  end;
end;

procedure Test_GetRecent;
var
  LBuf: TTimeSeriesRingBuffer;
  LEntries: array[0..4] of TTSRingEntry;
  LCount, I: Int32;
begin
  WriteLn('--- GetRecent ---');
  LBuf := TTimeSeriesRingBuffer.Create(10, 60000);
  try
    for I := 1 to 5 do
      LBuf.Append('val' + IntToStr(I));
    LCount := LBuf.GetRecent(3, LEntries);
    Check(LCount = 3, 'recent count = 3');
    Check(LEntries[0].Value = 'val5', 'most recent = val5');
    Check(LEntries[1].Value = 'val4', 'second = val4');
    Check(LEntries[2].Value = 'val3', 'third = val3');
  finally
    LBuf.Free;
  end;
end;

procedure Test_GetRange;
var
  LBuf: TTimeSeriesRingBuffer;
  LEntries: array[0..9] of TTSRingEntry;
  LCount: Int32;
  LNow: Int64;
begin
  WriteLn('--- GetRange ---');
  LBuf := TTimeSeriesRingBuffer.Create(10, 0);
  try
    LNow := Int64(platform_monotonic_ns div 1000000);
    LBuf.Append('a');
    LBuf.Append('b');
    LBuf.Append('c');
    LCount := LBuf.GetRange(LNow - 1000, LNow + 1000, LEntries);
    Check(LCount = 3, 'range count = 3');
    Check(LEntries[0].Value = 'a', 'first = a');
    Check(LEntries[2].Value = 'c', 'last = c');
  finally
    LBuf.Free;
  end;
end;

procedure Test_Clear;
var
  LBuf: TTimeSeriesRingBuffer;
begin
  WriteLn('--- Clear ---');
  LBuf := TTimeSeriesRingBuffer.Create(10, 60000);
  try
    LBuf.Append('a');
    LBuf.Append('b');
    LBuf.Clear;
    Check(LBuf.Count = 0, 'clear count = 0');
    Check(LBuf.IsEmpty, 'clear is empty');
  finally
    LBuf.Free;
  end;
end;

procedure Test_CustomTTLExpiry;
var
  LBuf: TTimeSeriesRingBuffer;
  LEntry: TTSRingEntry;
begin
  WriteLn('--- CustomTTLExpiry ---');
  LBuf := TTimeSeriesRingBuffer.Create(10, 0);
  try
    Check(LBuf.AppendWithTTL('short', 5) = tsrOk, 'append short ttl');
    Check(LBuf.AppendWithTTL('forever', 0) = tsrOk, 'append infinite ttl');
    platform_thread_sleep_ms(15);
    Check(LBuf.Count = 1, 'expired entry removed from count');
    Check(LBuf.Latest(LEntry) = tsrOk, 'latest survives expiry sweep');
    Check(LEntry.Value = 'forever', 'infinite ttl entry survives');
  finally
    LBuf.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  Test_Empty;
  Test_Append;
  Test_WrapAround;
  Test_GetRecent;
  Test_GetRange;
  Test_Clear;
  Test_CustomTTLExpiry;

  WriteLn;
  WriteLn('=== TimeSeriesRingBuffer: ', GPassed, ' passed, ', GFailed, ' failed ===');
  if GFailed > 0 then
    Halt(1);
end.
