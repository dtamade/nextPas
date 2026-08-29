program test_vfs_embedded;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.respack,
  nextpas.core.stopwatch,
  nextpas.core.vfs,
  nextpas.core.vfs.base;

{ embedded 后端专属用例：AOwnsBlob 双态生命期（heaptrc 判零泄漏）、
  损坏 pack 的 EResPackCorrupted 原样透传、空包合法 VFS、
  大内容切片边界、digest 区共存。 }

var
  T: TTestSuite;
  G_Owned: array of TBytes;   { 输入内容持活锚点 }

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(AA) = Length(AB);
  if not Result then
    Exit;
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then
      Exit(False);
end;

function MakeInputs(var AInputs: TResPackInputArray): Boolean;
var
  Slot: Integer;

  procedure Add(const APath: string; const AData: TBytes; const AMod: Int64);
  var
    N2: SizeInt;
  begin
    { 内容进 G_Owned 持活；Slot 为本轮固定槽位序号 }
    N2 := Length(G_Owned);
    SetLength(G_Owned, N2 + 1);
    G_Owned[N2] := AData;
    AInputs[Slot].Path := APath;
    if Length(G_Owned[N2]) > 0 then
      AInputs[Slot].Data := @G_Owned[N2][0]
    else
      AInputs[Slot].Data := nil;
    AInputs[Slot].DataSize := SizeUInt(Length(G_Owned[N2]));
    AInputs[Slot].ModTime := AMod;
    Inc(Slot);
  end;

begin
  Result := True;
  Slot := 0;
  SetLength(AInputs, 4);
  AInputs[0] := Default(TResPackInputEntry);
  AInputs[1] := Default(TResPackInputEntry);
  AInputs[2] := Default(TResPackInputEntry);
  AInputs[3] := Default(TResPackInputEntry);
  Add('big.bin', BytesOf('aaaa-bbbb-cccc-dddd-eeee-ffff-gggg-hhhh'), 111);
  Add('small.txt', BytesOf('bbbb'), 222);
  Add('empty.bin', nil, 333);
  Add('index.html', BytesOf('<html>ok</html>'), 444);
end;

{ ── AOwnsBlob=True：VFS 释放时归还 blob ── }

procedure TestOwnedBlobFreed;
var
  Inputs: TResPackInputArray;
  B: TResPackBlob;
  Fs: IVfs;
  SI: TStatInfo;
begin
  MakeInputs(Inputs);
  B := ResPackBuild(Inputs, ResPackDefaultOptions);
  Fs := CreateEmbeddedVfs(B.Data, B.Size, True);
  try
    SI := Fs.Stat('index.html');
    Check(SI.Info.Size = 15, 'owned: index.html readable');
  finally
    Fs := nil;   { 此处 FreeMem(blob)；heaptrc 终扫判零泄漏 }
  end;
  Check(True, 'owned blob freed without crash');
end;

{ ── AOwnsBlob=False：调用方保活，VFS 释放不动缓冲 ── }

procedure TestUnownedBlobStillUsableAfterVfsFree;
var
  Inputs: TResPackInputArray;
  B: TResPackBlob;
  Fs: IVfs;
begin
  MakeInputs(Inputs);
  B := ResPackBuild(Inputs, ResPackDefaultOptions);
  Fs := CreateEmbeddedVfs(B.Data, B.Size, False);
  try
    Check(Fs.Exists('small.txt'), 'unowned: exists before free');
  finally
    Fs := nil;   { 不释放缓冲 }
  end;
  { 缓冲仍归调用方：magic 与 blobTotal 未被动过 }
  Check((B.Data[0] = Ord('N')) and (B.Data[1] = Ord('P'))
    and (B.Data[2] = Ord('R')) and (B.Data[3] = Ord('S')),
    'unowned: buffer intact after vfs free');
  ResPackFreeBlob(B);
end;

{ ── 损坏 pack：EResPackCorrupted 原样透传 ── }

procedure CorruptMagicProc;
var
  Inputs: TResPackInputArray;
  B: TResPackBlob;
begin
  MakeInputs(Inputs);
  B := ResPackBuild(Inputs, ResPackDefaultOptions);
  try
    B.Data[0] := Byte('X');
    { 构造函数内 Open 抛 EResPackCorrupted；blob 经 finally 归还 }
    CreateEmbeddedVfs(B.Data, B.Size, False);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestCorruptedTransfersAsIs;
begin
  try
    CorruptMagicProc;
    Check(False, 'corrupt accepted');
  except
    on E: EResPackCorrupted do Check(True, 'EResPackCorrupted transfers as-is');
    on E: Exception do Check(False, 'wrong class: ' + E.ClassName);
  end;
end;

{ ── 空包 = 合法空根 VFS ── }

procedure TestEmptyPackEmptyRoot;
var
  Inputs: TResPackInputArray;
  B: TResPackBlob;
  Fs: IVfs;
  L: TEntryArray;
  GotNotFound: Boolean;
begin
  Inputs := nil;
  B := ResPackBuild(Inputs, ResPackDefaultOptions);
  Fs := CreateEmbeddedVfs(B.Data, B.Size, False);
  try
    Check(Fs.Exists('.'), 'empty: root exists');
    L := Fs.List('.');
    Check(Length(L) = 0, 'empty: root has no children');
    GotNotFound := False;
    try
      Fs.Stat('nothing');
    except
      on E: EVfsNotFound do GotNotFound := True;
    end;
    Check(GotNotFound, 'empty: stat raises not-found');
  finally
    Fs := nil;
    ResPackFreeBlob(B);
  end;
end;

{ ── 大内容切片边界：首尾字节精确 ── }

procedure TestBigContentBoundaries;
const
  BIG = 'aaaa-bbbb-cccc-dddd-eeee-ffff-gggg-hhhh';
var
  Inputs: TResPackInputArray;
  B: TResPackBlob;
  Fs: IVfs;
  S: IStream;
  Head, Tail: TBytes;
  LSize: Integer;
begin
  LSize := Length(BIG);
  MakeInputs(Inputs);
  B := ResPackBuild(Inputs, ResPackDefaultOptions);
  Fs := CreateEmbeddedVfs(B.Data, B.Size, False);
  try
    S := Fs.OpenRead('big.bin');
    try
      Check(S.Size = LSize, 'big: stream size');
      SetLength(Head, 8);
      Check(S.Read(Head[0], 8) = 8, 'big: read head');
      Check(SameBytes(Head, BytesOf(Copy(BIG, 1, 8))), 'big: head bytes');
      Check(S.Seek(-8, soEnd) = LSize - 8, 'big: seek tail');
      SetLength(Tail, 8);
      Check(S.Read(Tail[0], 8) = 8, 'big: read tail');
      Check(SameBytes(Tail, BytesOf(Copy(BIG, LSize - 7, 8))),
        'big: tail bytes');
    finally
      S.Close;
    end;
  finally
    Fs := nil;
    ResPackFreeBlob(B);
  end;
end;

{ ── 目录推导与去重共享槽位共存 ── }

function Num4(AValue: Integer): string;
begin
  Result := '0000';
  Result[4] := Char(Ord('0') + AValue mod 10); AValue := AValue div 10;
  Result[3] := Char(Ord('0') + AValue mod 10); AValue := AValue div 10;
  Result[2] := Char(Ord('0') + AValue mod 10); AValue := AValue div 10;
  Result[1] := Char(Ord('0') + AValue mod 10);
end;

procedure TestPerf10kEmbedded;
{ 零解码性能锁：10k 条目 Stat+OpenRead+首字节读必须在预算内完成。
  验证 FEntries 平行缓存已消除每请求 DecodeWire 与二次二分。
  阈值按 heaptrc -O2 慢路径留足余量，勿收紧当基准；回归为 O(n²) 会远超。 }
const
  ENTRY_COUNT = 10000;
  BUDGET_MS = 800;
var
  Store: array of TBytes;
  Inputs: TResPackInputArray;
  B: TResPackBlob;
  Fs: IVfs;
  SW: TStopwatch;
  I: Integer;
  SI: TStatInfo;
  S: IStream;
  FoundAll: Boolean;
  B1: Byte;
begin
  SetLength(Store, ENTRY_COUNT);
  SetLength(Inputs, ENTRY_COUNT);
  for I := 0 to ENTRY_COUNT - 1 do
  begin
    Store[I] := BytesOf(Num4(I) + '-0123456789abcdef0123456789abcdef');
    Inputs[I] := Default(TResPackInputEntry);
    Inputs[I].Path := 'gen/pack/' + Num4(I) + '.dat';
    if Length(Store[I]) > 0 then
      Inputs[I].Data := @Store[I][0]
    else
      Inputs[I].Data := nil;
    Inputs[I].DataSize := SizeUInt(Length(Store[I]));
  end;
  B := ResPackBuild(Inputs, ResPackDefaultOptions);
  Fs := CreateEmbeddedVfs(B.Data, B.Size, False);
  try
    FoundAll := True;
    SW := TStopwatch.StartNew;
    for I := 0 to ENTRY_COUNT - 1 do
    begin
      SI := Fs.Stat('gen/pack/' + Num4(I) + '.dat');
      if SI.Info.Size = 0 then FoundAll := False;
      S := Fs.OpenRead('gen/pack/' + Num4(I) + '.dat');
      if S.Read(B1, 1) <> 1 then FoundAll := False;
      S.Close;
    end;
    SW.Stop;
    Check(FoundAll, 'perf 10k embedded all found');
    Check(SW.ElapsedMs <= BUDGET_MS, 'perf 10k embedded Stat+OpenRead within budget');
  finally
    Fs := nil;
    ResPackFreeBlob(B);
  end;
end;

procedure TestDedupedEntriesListable;
var
  Inputs: TResPackInputArray;
  Opts: TResPackBuildOptions;
  BufA, BufB: TBytes;
  B: TResPackBlob;
  Fs: IVfs;
  L: TEntryArray;
begin
  BufA := BytesOf('same-bytes');
  BufB := BytesOf('same-bytes');
  SetLength(Inputs, 2);
  Inputs[0] := Default(TResPackInputEntry);
  Inputs[0].Path := 'x/one.js';
  Inputs[0].Data := @BufA[0];
  Inputs[0].DataSize := SizeUInt(Length(BufA));
  Inputs[1] := Default(TResPackInputEntry);
  Inputs[1].Path := 'x/two.js';
  Inputs[1].Data := @BufB[0];
  Inputs[1].DataSize := SizeUInt(Length(BufB));
  Opts := ResPackDefaultOptions;
  Opts.Deduplicate := True;
  B := ResPackBuild(Inputs, Opts);
  Fs := CreateEmbeddedVfs(B.Data, B.Size, False);
  try
    Check(Fs.Exists('x'), 'dedupe: dir x derived');
    L := Fs.List('x');
    Check(Length(L) = 2, 'dedupe: two children listed');
    Check(L[0].Name = 'x/one.js', 'dedupe: child [0]');
    Check(L[1].Name = 'x/two.js', 'dedupe: child [1]');
  finally
    Fs := nil;
    ResPackFreeBlob(B);
  end;
end;

{ ── VfsDeriveChildNames 纯函数直驱：零分配语义固化 ── }

procedure TestDeriveChildNamesPure;
var
  Paths: array of string;
  Got: TVfsNameArray;
begin
  { 根路径推导：3 文件含 2 同目录前缀，dedup 后应得 3 子项 }
  Paths := ['a/b/c.js', 'a/b/d.js', 'a/other.txt'];
  Got := VfsDeriveChildNames(Paths, 'a/');
  Check(Length(Got) = 2, 'derive a/ => 2 children');
  Check(Got[0] = 'a/b', 'derive a/ child 0 = a/b');
  Check(Got[1] = 'a/other.txt', 'derive a/ child 1 = a/other.txt');
  { 二级目录推导 }
  Got := VfsDeriveChildNames(Paths, 'a/b/');
  Check(Length(Got) = 2, 'derive a/b/ => 2 files');
  Check(Got[0] = 'a/b/c.js', 'derive a/b/ file 0');
  Check(Got[1] = 'a/b/d.js', 'derive a/b/ file 1');
  { 空前缀（根）推导：同前缀目录合并 }
  Paths := ['x/one.js', 'x/two.js', 'y/file.txt'];
  Got := VfsDeriveChildNames(Paths, '');
  Check(Length(Got) = 2, 'derive root => 2 top children');
  Check(Got[0] = 'x', 'derive root child 0 = x');
  Check(Got[1] = 'y', 'derive root child 1 = y');
  { 空输入 }
  Paths := nil;
  Got := VfsDeriveChildNames(Paths, '');
  Check(Length(Got) = 0, 'derive empty => 0');
end;

begin
  T := TTestSuite.Create('nextpas.core.vfs.embedded');
  T.Test('owned blob freed on release', @TestOwnedBlobFreed);
  T.Test('unowned buffer intact after vfs free', @TestUnownedBlobStillUsableAfterVfsFree);
  T.Test('corrupt pack transfers as-is', @TestCorruptedTransfersAsIs);
  T.Test('empty pack is empty root', @TestEmptyPackEmptyRoot);
  T.Test('big content boundaries', @TestBigContentBoundaries);
  T.Test('deduped entries listable', @TestDedupedEntriesListable);
  T.Test('perf 10k embedded zero-decode', @TestPerf10kEmbedded);
  T.Test('derive child names pure', @TestDeriveChildNamesPure);
  if not T.Run then Halt(1);
end.
