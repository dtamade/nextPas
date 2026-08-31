program zip_roundtrip;
{**
 * nextpas.core.zip 最小示例：打包一个目录 -> python/标准解压器可读的归档 ->
 * 解包还原，并演示 deflate、Zip64、WithTime、AES 与总量守卫。
 *
 * 运行：make run
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.compress.intf,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.zip,
  nextpas.core.zip.base,
  nextpas.core.zip.sequential;

var
  LRoot, LOut, LAesZip: string;
  LW: IZipWriter;
  LR: IZipReader;
  LOpts: TZipWriteOptions;
  LStreamOpts, LAesOpts: TZipAddOptions;
  LROpts: TZipReadOptions;
  LI, LSize: Integer;
  LN: SizeUInt;
  LTotal: UInt64;
  LData, LGot, LArc: TBytes;
  LSink: ICompressWriter;
  LSrc: IDecompressReader;
  LFile: IFile;
  LChunk: array[0..255] of Byte;
  LSeqSrc: IReader;
  LSeq: ISequentialZipReader;
  LInfo: TZipEntryInfo;
  LCnt: Integer;
  LRs: IDecompressReader;
  LBld: IZipBuilder;
  LExtractOpts: TZipExtractOptions;
  LGuardDir: string;

function SameBytes(const A, B: TBytes): Boolean;
var
  LI: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then Exit;
  for LI := 0 to High(A) do
    if A[LI] <> B[LI] then Exit(False);
end;

function StrBytes(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;
begin
  LRoot := GetTempDir + '/zip_roundtrip_src';
  LOut := GetTempDir + '/zip_roundtrip_out';
  LAesZip := LOut + '.aes.zip';

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

  { Fluent Builder：同等字节的高级感链式门面 }
  WriteFile(LOut + '.builder.zip',
    ZipBuilder()
      .Reserve(4)
      .Add('hello-builder.txt', StrBytes('builder hello'))
      .AddDeflate('assets/data.bin', LData)
      .AddDirectory('builder-dir')
      .Finish);
  LR := NewZipReader(ReadFile(LOut + '.builder.zip'));
  WriteLn('builder    : entries=', LR.EntryCount, ' ok=', LR.EntryCount=3);
  DeleteFile(LOut + '.builder.zip');

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

  { 流式输出：归档逐字节直写文件，不经整档物化（任意大小内存恒定） }
  LW := NewZipWriter;
  LFile := nextpas.core.fs.Create(LOut + '.stream.zip');
  LW.StreamOutputTo(LFile as IWriter);
  ZipPackDirInto(LRoot, LW);
  LTotal := LW.FinishTo(LFile as IWriter);
  LFile.Close;
  WriteLn('piped      : ', LOut + '.stream.zip', ' bytes=', LTotal);

  { 流式读回：从文件源定位取数直接解析，不经整档载入 }
  LFile := nextpas.core.fs.Open(LOut + '.stream.zip', [fmRead]);
  LR := NewZipReaderFrom(LFile as IStream);
  LGot := LR.ExtractToBytesByName('hello.txt');
  WriteLn('piped read : ', BoolToStr(SameBytes(LGot, StrBytes('hello zip')),
    True));
  LFile.Close;

  { 顺序读（INV-16 对偶）：从纯顺序流逐条扫描，不整档 }
  LSeqSrc := nextpas.core.fs.Open(LOut + '.stream.zip', [fmRead]) as IReader;
  LSeq := NewZipSequentialReader(LSeqSrc);
  LCnt := 0;
  while LSeq.Next(LInfo) do
  begin
    Inc(LCnt);
    if LInfo.Name = 'hello.txt' then
    begin
      LRs := LSeq.Open;
      LRs.Close;
    end
    else
      LSeq.Skip;
  end;
  WriteLn('sequential : entries=', LCnt, ' piped ok');

  { Builder WithTime 对称演示：显式时间戳 }
  LBld := ZipBuilder();
  LBld.AddWithTime('timed.txt', StrBytes('timed'), 1700000000);
  LBld.AddDeflateWithTime('timed-def.txt', StrBytes('timed def'), 1700000000);
  LBld.AddDirectoryWithTime('timed-dir', 1700000000);
  WriteLn('builder WithTime: ', LBld.EntryCount, ' entries with explicit mtime');
  LBld.Finish;

  { AES 加密条目：AE-2 写入 + 口令读回 }
  LW := NewZipWriter;
  LAesOpts := DefaultZipAddOptions;
  LAesOpts.Method := zmDeflate;
  LAesOpts.Password := StrBytes('demo-password');
  LAesOpts.AesStrength := 3;
  LW.AddEntryWithOptions('secret.txt', StrBytes('encrypted hello'), LAesOpts);
  WriteFile(LAesZip, LW.Finish);

  LROpts := DefaultZipReadOptions;
  LROpts.Password := StrBytes('demo-password');
  LR := NewZipReaderWithOptions(ReadFile(LAesZip), LROpts);
  LGot := LR.ExtractToBytesByName('secret.txt');
  WriteLn('aes256 read: ',
    BoolToStr(SameBytes(LGot, StrBytes('encrypted hello')), True));

  { PByte 零拷贝直写演示（INV-18）：无 TBytes 物化，store/deflate 共享校验内核 }
  LW := NewZipWriter;
  SetLength(LGot, 1024);
  for LI := 0 to High(LGot) do LGot[LI] := Byte(LI and $FF);
  LW.AddEntry('pbyte.bin', LGot);
  LArc := LW.Finish;
  LR := NewZipReader(LArc);
  SetLength(LData, 1024);
  LN := LR.ExtractToBufferByName('pbyte.bin', @LData[0], SizeUInt(Length(LData)));
  WriteLn('pbyte      : bytes=', LN, ' ok=', SameBytes(LGot, LData) and (LN=1024));
  // 目录/空条目返回 0 且不触碰缓冲
  LW := NewZipWriter; LW.AddDirectory('empty-dir'); LArc := LW.Finish;
  LR := NewZipReader(LArc);
  LN := LR.ExtractToBufferByName('empty-dir/', nil, 0);
  WriteLn('pbyte dir  : bytes=', LN, ' ok=', LN=0);

  { AES 描述符对偶演示（INV-19）：DataDescriptor + AES 顺序读先集密文再解帧 }
  LW := NewZipWriter;
  LAesOpts := DefaultZipAddOptions; LAesOpts.Method := zmDeflate; LAesOpts.Password := StrBytes('desc-pw'); LAesOpts.AesStrength := 1; LAesOpts.DataDescriptor := True;
  LSink := LW.AddEntryStream('aes-desc.bin', LAesOpts);
  SetLength(LGot, 2048); for LI:=0 to High(LGot) do LGot[LI]:=Byte((LI*5) and $FF);
  LSink.Write(LGot[0], Length(LGot)); LSink.Close;
  WriteFile(LAesZip+'.desc', LW.Finish);
  LROpts := DefaultZipReadOptions; LROpts.Password := StrBytes('desc-pw');
  LR := NewZipReaderWithOptions(ReadFile(LAesZip+'.desc'), LROpts);
  WriteLn('aes-desc random: ok=', SameBytes(LR.ExtractToBytesByName('aes-desc.bin'), LGot));
  LSeqSrc := CreateBytesStreamFrom(ReadFile(LAesZip+'.desc')) as IReader;
  LSeq := NewZipSequentialReaderWithOptions(LSeqSrc, LROpts);
  if LSeq.Next(LInfo) then begin LRs:=LSeq.Open; SetLength(LData,0); repeat LN:=LRs.Read(LChunk[0], SizeOf(LChunk)); if LN>0 then begin SetLength(LData, Length(LData)+Integer(LN)); Move(LChunk[0], LData[Length(LData)-Integer(LN)], LN); end; until LN=0; LRs.Close; WriteLn('aes-desc seq   : ok=', SameBytes(LData, LGot)); end;
  DeleteFile(LAesZip+'.desc');

  { 总量守卫演示（INV-17）：单条与跨条目双上限，入口+流中途双重拦截 }
  LW := NewZipWriter;
  LW.AddEntry('a.txt', StrBytes('12345')); // 5 bytes
  LW.AddEntry('b.txt', StrBytes('67890')); // total 10
  LArc := LW.Finish;
  LROpts := DefaultZipReadOptions;
  LROpts.MaxTotalOutputSize := 9; // 10 > 9 must fail-closed
  try
    LR := NewZipReaderWithOptions(LArc, LROpts);
    WriteLn('maxTotal guard: unexpected pass');
  except
    on E: EIOError do
      WriteLn('maxTotal guard: ', E.ClassName, ' ', E.Message);
    on E: Exception do
      WriteLn('maxTotal guard: ', E.ClassName, ' ', E.Message);
  end;
  LROpts.MaxTotalOutputSize := 10;
  LR := NewZipReaderWithOptions(LArc, LROpts);
  WriteLn('maxTotal ok  : entries=', LR.EntryCount, ' total=', LR.Entry(0).UncompressedSize + LR.Entry(1).UncompressedSize);
  { sequential 路径同受总量守卫（增量累计） }
  LSeqSrc := CreateBytesStreamFrom(LArc) as IReader;
  LROpts.MaxTotalOutputSize := 9;
  LSeq := NewZipSequentialReaderWithOptions(LSeqSrc, LROpts);
  try
    while LSeq.Next(LInfo) do
      LSeq.Skip;
    WriteLn('seq maxTotal guard: unexpected pass');
  except
    on E: EIOError do
      WriteLn('seq maxTotal guard: ', E.ClassName, ' ', E.Message);
    on E: Exception do
      WriteLn('seq maxTotal guard: ', E.ClassName, ' ', E.Message);
  end;
  { fs 落盘同透传总量上限 }
  LGuardDir := GetTempDir + '/zip_roundtrip_guard';
  RemoveAll(LGuardDir);
  LExtractOpts := DefaultZipExtractOptions;
  LExtractOpts.MaxTotalOutputSize := 9;
  try
    ZipExtractToDirWithOptions(LArc, LGuardDir, LExtractOpts);
    WriteLn('fs maxTotal guard: unexpected pass');
  except
    on E: EIOError do
      WriteLn('fs maxTotal guard: ', E.ClassName, ' ', E.Message);
    on E: Exception do
      WriteLn('fs maxTotal guard: ', E.ClassName, ' ', E.Message);
  end;
  LExtractOpts.MaxTotalOutputSize := 10;
  ZipExtractToDirWithOptions(LArc, LGuardDir, LExtractOpts);
  WriteLn('fs maxTotal ok  : ', ReadFileText(LGuardDir + '/a.txt') = '12345');
  RemoveAll(LGuardDir);

  { 单条上限：MaxOutputSize 入口即拦（store bomb） }
  LROpts := DefaultZipReadOptions;
  LROpts.MaxOutputSize := 4; // a.txt 5 > 4
  try
    LR := NewZipReaderWithOptions(LArc, LROpts);
    LR.ExtractToBytesByName('a.txt');
    WriteLn('maxOutput guard: unexpected pass');
  except
    on E: EIOError do
      WriteLn('maxOutput guard: ', E.ClassName, ' ', E.Message);
    on E: Exception do
      WriteLn('maxOutput guard: ', E.ClassName, ' ', E.Message);
  end;

  RemoveAll(LRoot);
  RemoveAll(LOut);
  DeleteFile(LOut + '.zip');
  DeleteFile(LOut + '.stream.zip');
  DeleteFile(LAesZip);
  WriteLn('zip_roundtrip: all demos ok');
end.
