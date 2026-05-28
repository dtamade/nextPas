program nextpas.core.simd.concurrent;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

const
  NUM_THREADS = 8;
  ITERATIONS = 10000;
  ARRAY_SIZE = 256;

type
  TWorkerThread = class(TThread)
  private
    FWorkerId: Integer;
    FFailures: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(aId: Integer);
    property Failures: Integer read FFailures;
  end;

constructor TWorkerThread.Create(aId: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerId := aId;
  FFailures := 0;
end;

procedure TWorkerThread.Execute;
var
  LSrc1, LSrc2, LDst: array[0..ARRAY_SIZE-1] of Single;
  LExpected, LActual, LSum: Single;
  i, iter: Integer;
begin
  for i := 0 to ARRAY_SIZE - 1 do
  begin
    LSrc1[i] := Sin((FWorkerId * 100 + i) * 0.1) * 50;
    LSrc2[i] := Cos((FWorkerId * 100 + i) * 0.1) * 30 + 1;
  end;

  for iter := 0 to ITERATIONS - 1 do
  begin
    FillChar(LDst, SizeOf(LDst), 0);
    ArrayAddF32(@LSrc1[0], @LSrc2[0], @LDst[0], ARRAY_SIZE);

    LExpected := LSrc1[0] + LSrc2[0];
    if Abs(LDst[0] - LExpected) > 1e-5 then
    begin
      Inc(FFailures);
      Break;
    end;

    LExpected := LSrc1[ARRAY_SIZE-1] + LSrc2[ARRAY_SIZE-1];
    if Abs(LDst[ARRAY_SIZE-1] - LExpected) > 1e-5 then
    begin
      Inc(FFailures);
      Break;
    end;

    LSum := ReduceSumF32(@LSrc1[0], ARRAY_SIZE);
    if IsNan(LSum) or IsInfinite(LSum) then
    begin
      Inc(FFailures);
      Break;
    end;

    ArrayMulF32(@LSrc1[0], @LSrc2[0], @LDst[0], ARRAY_SIZE);
    ArrayAbsF32(@LSrc1[0], @LDst[0], ARRAY_SIZE);
    ArraySqrtF32(@LDst[0], @LDst[0], ARRAY_SIZE);
  end;
end;

var
  LThreads: array[0..NUM_THREADS-1] of TWorkerThread;
  LTotalFailures: Integer;
  i: Integer;
begin
  WriteLn('[Concurrent Dispatch Test]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn(Format('Threads: %d, Iterations: %d, ArraySize: %d',
    [NUM_THREADS, ITERATIONS, ARRAY_SIZE]));
  WriteLn('');

  for i := 0 to NUM_THREADS - 1 do
    LThreads[i] := TWorkerThread.Create(i);

  for i := 0 to NUM_THREADS - 1 do
    LThreads[i].Start;

  for i := 0 to NUM_THREADS - 1 do
    LThreads[i].WaitFor;

  LTotalFailures := 0;
  for i := 0 to NUM_THREADS - 1 do
  begin
    LTotalFailures := LTotalFailures + LThreads[i].Failures;
    LThreads[i].Free;
  end;

  WriteLn(Format('Total operations: %d', [NUM_THREADS * ITERATIONS * 5]));
  WriteLn(Format('Failures: %d', [LTotalFailures]));
  if LTotalFailures > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
