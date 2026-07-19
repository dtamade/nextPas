program test_tui_buffer_wine;
{ Wine runtime smoke for TBuffer — pure memory, no TTY.
  truth=wine-runtime-smoke; not real Windows console evidence. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestCreateAndSetString;
var
  LBuf: TBuffer;
  LLines: TBufferLines;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 2));
  try
    LBuf.SetString(0, 0, 'hello', StyleDefault);
    LLines := LBuf.AsLines;
    Check(Pos('hello', LLines[0]) > 0, 'setstring');
  finally
    LBuf.Free;
  end;
end;

procedure TestDiffIdentical;
var
  A, B: TBuffer;
  LPatches: TDiffEntries;
  N: Integer;
begin
  A := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 4));
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 4));
  try
    A.SetString(0, 0, 'same', StyleDefault);
    B.SetString(0, 0, 'same', StyleDefault);
    N := A.DiffInto(B, LPatches);
    CheckEqual(0, N, 'identical patches=0');
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TestDiffDirty;
var
  A, B: TBuffer;
  LPatches: TDiffEntries;
  N: Integer;
begin
  A := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 4));
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 4));
  try
    A.SetString(0, 0, 'base', StyleDefault);
    B.SetString(0, 0, 'base', StyleDefault);
    B.SetString(0, 1, 'DIRT', StyleDefault);
    N := A.DiffInto(B, LPatches);
    Check(N > 0, 'dirty patches > 0');
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TestFillRect;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    LBuf.FillRect(TRect.Make(0, 0, 4, 2), '#', StyleDefault);
    CheckEqual('####', LBuf.AsLines[0], 'fill row0');
    CheckEqual('####', LBuf.AsLines[1], 'fill row1');
  finally
    LBuf.Free;
  end;
end;

procedure TestResize;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    LBuf.Resize(TRect.Make(0, 0, 6, 3));
    CheckEqual(6, LBuf.Area.Width, 'width');
    CheckEqual(3, LBuf.Area.Height, 'height');
  finally
    LBuf.Free;
  end;
end;

begin
  T := TTestSuite.Create('tui_buffer_wine');
  T.Test('create and setstring', @TestCreateAndSetString);
  T.Test('diff identical', @TestDiffIdentical);
  T.Test('diff dirty', @TestDiffDirty);
  T.Test('fill rect', @TestFillRect);
  T.Test('resize', @TestResize);
  if not T.Run then Halt(1);
end.
