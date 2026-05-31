program test_bufferpool;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.bufferpool;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure TestAcquireRelease;
var
  LPool: TSSLBufferPool;
  LBuf: TBytes;
begin
  WriteLn('TestAcquireRelease');
  LPool := TSSLBufferPool.Create(4096, 4);
  try
    LBuf := LPool.Acquire;
    Check(Length(LBuf) = 4096, 'Acquired buffer has correct size');
    Check(LPool.BufferSize = 4096, 'BufferSize property');
    LPool.Release(LBuf);
    Check(LBuf = nil, 'Buffer nil after release');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolReuse;
var
  LPool: TSSLBufferPool;
  LBuf1, LBuf2: TBytes;
  LPtr1: Pointer;
begin
  WriteLn('TestPoolReuse');
  LPool := TSSLBufferPool.Create(1024, 4);
  try
    LBuf1 := LPool.Acquire;
    LBuf1[0] := $42;
    LPtr1 := @LBuf1[0];
    LPool.Release(LBuf1);
    Check(LBuf1 = nil, 'Released buffer is nil');

    LBuf2 := LPool.Acquire;
    Check(@LBuf2[0] = LPtr1, 'Reused same buffer from pool');
    Check(LBuf2[0] = $42, 'Data preserved in pooled buffer');
    LPool.Release(LBuf2);
  finally
    LPool.Free;
  end;
end;

procedure TestPoolOverflow;
var
  LPool: TSSLBufferPool;
  LBufs: array[0..4] of TBytes;
  I: Integer;
begin
  WriteLn('TestPoolOverflow');
  LPool := TSSLBufferPool.Create(512, 2);
  try
    for I := 0 to 4 do
      LBufs[I] := LPool.Acquire;
    for I := 0 to 4 do
      LPool.Release(LBufs[I]);
    Check(True, 'No crash on overflow release');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolWrongSize;
var
  LPool: TSSLBufferPool;
  LBuf: TBytes;
begin
  WriteLn('TestPoolWrongSize');
  LPool := TSSLBufferPool.Create(256, 4);
  try
    SetLength(LBuf, 128);
    LPool.Release(LBuf);
    Check(Length(LBuf) = 0, 'Wrong-size buffer freed, not pooled');
  finally
    LPool.Free;
  end;
end;

procedure TestGlobalBufferPool;
var
  LBuf: TBytes;
begin
  WriteLn('TestGlobalBufferPool');
  Check(GlobalBufferPool <> nil, 'GlobalBufferPool exists');
  LBuf := GlobalBufferPool.Acquire;
  Check(Length(LBuf) = 16384, 'Global pool default size 16384');
  GlobalBufferPool.Release(LBuf);
end;

begin
  
  LTotal := 0;
  LPassed := 0;

  TestAcquireRelease;
  TestPoolReuse;
  TestPoolOverflow;
  TestPoolWrongSize;
  TestGlobalBufferPool;

  WriteLn;
  WriteLn('BufferPool tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
