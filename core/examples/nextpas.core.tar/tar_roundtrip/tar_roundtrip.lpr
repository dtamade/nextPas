program tar_roundtrip;
{**
 * nextpas.core.tar 最小示例：内存打包 -> system tar 可读 -> 目录落盘还原。
 * 演示 writer/reader/fs/builder 与 bomb 守卫。
 * 运行：make run
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.tar,
  nextpas.core.tar.base,
  nextpas.core.tar.reader,
  nextpas.core.tar.writer,
  nextpas.core.tar.builder,
  nextpas.core.fs,
  nextpas.core.io.memory;

function BytesOf(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(S[1], Result[0], Length(S));
end;

function SameBytes(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

var
  Root, OutDir: string;
  Arc, Arc2: TBytes;
  R: TTarReader;
  H: TTarHeader;
  B: ITarBuilder;
  S: IStream;
  W: TTarWriter;
  Opts: TTarAddOptions;
begin
  Root := GetTempDir + '/tar_roundtrip_src';
  OutDir := GetTempDir + '/tar_roundtrip_out';
  RemoveAll(Root); RemoveAll(OutDir);
  MkdirAll(Root + '/assets', PermDirDefault);
  WriteFile(Root + '/hello.txt', BytesOf('hello tar'));
  WriteFile(Root + '/assets/data.bin', BytesOf('0123456789'));

  { 1. IWriter 路径 }
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  W.AddFile('hello.txt', BytesOf('hello tar'), $1A4, 1700000000);
  W.AddDir('assets');
  W.AddFile('assets/data.bin', BytesOf('0123456789'));
  W.Finish; W.Free;
  SetLength(Arc, S.Size);
  S.Seek(0, soBeginning);
  S.Read(Arc[0], Length(Arc));
  WriteLn('writer bytes: ', Length(Arc), ' block-aligned=', (Length(Arc) mod 512 = 0));

  { 2. Builder 路径 — 同字节、更高高级感（显式同 mtime/mode 保证 bytes 级一致） }
  Opts := DefaultTarAddOptions; Opts.Mode := $1A4; Opts.MTimeUnix := 1700000000;
  Arc2 := TarBuilder.AddWithOptions('hello.txt', BytesOf('hello tar'), Opts)
                    .AddDirectory('assets')
                    .Add('assets/data.bin', BytesOf('0123456789'))
                    .Finish;
  WriteLn('builder same: ', SameBytes(Arc, Arc2));

  { 3. 目录打包 }
  Arc := TarPackDir(Root);
  WriteLn('pack dir: ', Length(Arc));

  { 4. 解包还原 }
  TarExtractToDir(Arc, OutDir);
  WriteLn('out hello: ', SameBytes(ReadFile(OutDir + '/hello.txt'), BytesOf('hello tar')));
  WriteLn('out data: ', SameBytes(ReadFile(OutDir + '/assets/data.bin'), BytesOf('0123456789')));

  { 5. 读端浏览 }
  R := TTarReader.Create(Arc);
  try
    while R.Next(H) do
      WriteLn('entry ', H.Name, ' size=', H.Size, ' kind=', Ord(H.Kind));
  finally R.Free; end;

  RemoveAll(Root); RemoveAll(OutDir);
  WriteLn('done');
end.
