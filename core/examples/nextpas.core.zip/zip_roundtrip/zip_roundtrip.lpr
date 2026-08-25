program zip_roundtrip;
{**
 * nextpas.core.zip 最小示例：打包一个目录 -> python/标准解压器可读的归档 ->
 * 解包还原，并演示 deflate 条目与 Zip64 选项。
 *
 * 运行：make run
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.compress.intf,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.zip,
  nextpas.core.zip.base;

var
  LRoot, LOut: string;
  LW: IZipWriter;
  LR: IZipReader;
  LOpts: TZipWriteOptions;
  LStreamOpts: TZipAddOptions;
  LI, LSize: Integer;
  LN: SizeUInt;
  LData, LGot: TBytes;
  LSink: ICompressWriter;
  LSrc: IDecompressReader;
  LChunk: array[0..255] of Byte;

function SameBytes(const A, B: TBytes): Boolean;
var
  LI: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then Exit;
  for LI := 0 to High(A) do
    if A[LI] <> B[LI] then Exit(False);
end;
begin
  LRoot := GetTempDir + '/zip_roundtrip_src';
  LOut := GetTempDir + '/zip_roundtrip_out';

  { 准备示例树 }
  RemoveAll(LRoot);
  MkdirAll(LRoot + '/assets', PermDirDefault);
  WriteFileText(LRoot + '/hello.txt', 'hello zip');
  SetLength(LData, 4096);
  for LI := 0 to High(LData) do
    LData[LI] := Byte(LI mod 13);
  WriteFile(LRoot + '/assets/data.bin', LData);

  { 打包目录 }
  LW := NewZipWriter;
  ZipPackDirInto(LRoot, LW);
  { 额外演示：deflate 压缩条目（method=8） }
  LW.AddEntryDeflate('data.bin.deflated', LData);
  WriteFile(LOut + '.zip', LW.Finish);
  WriteLn('packed   : ', LOut + '.zip');

  { 解包还原 }
  RemoveAll(LOut);
  ZipExtractToDir(ReadFile(LOut + '.zip'), LOut);
  WriteLn('restored : ', ReadFileText(LOut + '/hello.txt'));
  LGot := ReadFile(LOut + '/assets/data.bin');
  WriteLn('same bin : ', BoolToStr(SameBytes(LGot, LData), True));

  { 读端元数据浏览 }
  LR := NewZipReader(ReadFile(LOut + '.zip'));
  for LI := 0 to LR.EntryCount - 1 do
  begin
    LSize := Integer(LR.Entry(LI).UncompressedSize);
    WriteLn('entry [', LR.Entry(LI).Name, '] method=',
      LR.Entry(LI).MethodCode, ' size=', LSize);
  end;

  { 强制 Zip64 结构（预知超大归档时使用） }
  LOpts.ForceZip64 := True;
  LW := NewZipWriterWithOptions(LOpts);
  SetLength(LGot, 4);
  LGot[0] := Ord('t');
  LGot[1] := Ord('i');
  LGot[2] := Ord('n');
  LGot[3] := Ord('y');
  LW.AddEntry('small-but-zip64.txt', LGot);
  WriteLn('zip64 archive bytes = ', Length(LW.Finish));

  { 流式条目：分块写入不必整体物化，读端增量解压 }
  LW := NewZipWriter;
  LStreamOpts := DefaultZipAddOptions;
  LStreamOpts.Method := zmDeflate;
  LSink := LW.AddEntryStream('streamed.bin', LStreamOpts);
  for LI := 0 to 31 do
    LSink.Write(LData[LI * 128], 128);   { 分块推入 4096 字节 }
  LSink.Close;
  LR := NewZipReader(LW.Finish);
  LSrc := LR.OpenEntryByName('streamed.bin');
  SetLength(LGot, 0);
  repeat
    LN := LSrc.Read(LChunk[0], SizeOf(LChunk));
    if LN > 0 then
      for LI := 0 to Integer(LN) - 1 do
      begin
        SetLength(LGot, Length(LGot) + 1);
        LGot[Length(LGot) - 1] := LChunk[LI];
      end;
  until LN = 0;
  WriteLn('streamed   : ', BoolToStr(SameBytes(LGot, LData), True));

  RemoveAll(LRoot);
  RemoveAll(LOut);
  DeleteFile(LOut + '.zip');
end.
