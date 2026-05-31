program test_io_killer;
{$I nextpas.core.settings.inc}
{$R+}{$Q+}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory;

var
  T: TTestRunner;

procedure TestStreamSeekBeyondSize;
var LS: IStream; LBuf: array[0..9] of Byte; LRead: SizeUInt;
begin
  LS := CreateBytesStream(64);
  LS.Write(LBuf, 10);
  LS.Seek(100, soBeginning);
  LRead := LS.Read(LBuf, 10);
  CheckEqual(Int64(0), Int64(LRead));
end;

procedure TestStreamEmptyRead;
var LS: IStream; LBuf: array[0..9] of Byte; LRead: SizeUInt;
begin
  LS := CreateBytesStream(0);
  LRead := LS.Read(LBuf, 10);
  CheckEqual(Int64(0), Int64(LRead));
end;

procedure TestStreamWriteGrow;
var LS: IStream; LBuf: array[0..255] of Byte; LI: Integer;
begin
  LS := CreateBytesStream(4);
  for LI := 0 to 255 do LBuf[LI] := Byte(LI);
  LS.Write(LBuf, 256);
  LS.Seek(0, soBeginning);
  FillChar(LBuf, 256, 0);
  LS.Read(LBuf, 256);
  for LI := 0 to 255 do
    if LBuf[LI] <> Byte(LI) then
    begin
      Check(False, 'mismatch at ' + IntToStr(LI));
      Exit;
    end;
  Check(True, '256 bytes survive grow');
end;

begin
  T := TTestRunner.Create('nextpas.core.io.killer');
  T.Run('Stream seek beyond size', @TestStreamSeekBeyondSize);
  T.Run('Stream empty read', @TestStreamEmptyRead);
  T.Run('Stream write grow', @TestStreamWriteGrow);
  T.Summary;
end.
