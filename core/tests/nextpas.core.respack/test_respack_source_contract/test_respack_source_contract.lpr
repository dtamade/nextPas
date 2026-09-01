program test_respack_source_contract;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.fs;

{ 源契约门禁：respack(6 单元) uses 白名单锁定。
  1) 裸 FPC RTL 引用零容忍（复用仓库共享扫描器 fpc_rtl_uses_scan.inc，
     与 test_fs/test_vfs_source_contract 同机制，不自造）
  2) L2→L2 seam 唯一性：除 respack.dirsource 外，
     任何 respack 单元不得引用 nextpas.core.fs
  3) 异常根纪律：错误族挂在 nextpas.core.exception
  4) 单源收敛：bytes.ops/bytes.binary 等零拷贝单源 }

{$I ../../fpc_rtl_uses_scan.inc}

var
  T: TTestSuite;

function LoadSourceText(const ARelativePath: string): string; inline;
begin
  Result := nextpas.core.fs.ReadFileText(nextpas.core.fs.PathRealPath('../../../' + ARelativePath));
end;

procedure AssertSourceNoBareFpcRtlUses(const ALabel, ASource: string); inline;
var
  LHit: string;
  LOk: Boolean;
  LMsg: string;
begin
  LOk := not FindBareFpcRtlInUses(ASource, LHit);
  LMsg := ALabel + ' — no bare FPC RTL in uses';
  if not LOk then
    LMsg := LMsg + ' (hit: ' + LHit + ')';
  Check(LOk, LMsg);
end;

procedure ScanList(const ALabelPrefix: string; const AFiles: array of string);
var
  I: Integer;
begin
  for I := Low(AFiles) to High(AFiles) do
    AssertSourceNoBareFpcRtlUses(ALabelPrefix + ' ' + AFiles[I], LoadSourceText(AFiles[I]));
end;

{ seam 唯一性：白名单外不得出现 nextpas.core.fs 引用 }
procedure AssertNoFsSeam(const ALabel, ASource: string); inline;
begin
  Check(Pos('nextpas.core.fs', ASource) = 0, ALabel + ' — must not reference nextpas.core.fs');
end;

procedure TestRespackSourcesNoFpcRtl;
const
  FILES: array[0..5] of string = (
    'src/nextpas.core.respack.pas',
    'src/nextpas.core.respack.base.pas',
    'src/nextpas.core.respack.writer.pas',
    'src/nextpas.core.respack.reader.pas',
    'src/nextpas.core.respack.dirsource.pas',
    'src/nextpas.core.respack.embed.pas');
begin
  ScanList('respack src', FILES);
end;

procedure TestRespackGateSourcesNoFpcRtl;
const
  FILES: array[0..5] of string = (
    'tests/nextpas.core.respack/test_respack_reader/test_respack_reader.lpr',
    'tests/nextpas.core.respack/test_respack_writer/test_respack_writer.lpr',
    'tests/nextpas.core.respack/test_respack_roundtrip/test_respack_roundtrip.lpr',
    'tests/nextpas.core.respack/test_respack_dirsource/test_respack_dirsource.lpr',
    'tests/nextpas.core.respack/test_respack_embed/test_respack_embed.lpr',
    'tests/nextpas.core.respack/test_respack_source_contract/test_respack_source_contract.lpr');
begin
  ScanList('respack gate', FILES);
end;

procedure TestSeamUniqueness;
const
  NO_SEAM: array[0..4] of string = (
    'src/nextpas.core.respack.pas',
    'src/nextpas.core.respack.base.pas',
    'src/nextpas.core.respack.writer.pas',
    'src/nextpas.core.respack.reader.pas',
    'src/nextpas.core.respack.embed.pas');
var
  I: Integer;
  Src: string;
begin
  { 白名单外的单元一律禁 fs 引用；dirsource 是唯一的 L2→L2 IO seam（registry 明示 + source-contract 门禁，同 vfs.os 范式） }
  for I := Low(NO_SEAM) to High(NO_SEAM) do
    AssertNoFsSeam(NO_SEAM[I], LoadSourceText(NO_SEAM[I]));
  { embed 已收敛至 L1 text.strings/text.char/text.conv 三单源（GlobMatch/IsAlpha/IntToStr 各归一、PChar 零拷贝 + inline，fs.glob 薄转发同源），不再构成 L2→L2 }
  Check(Pos('nextpas.core.text.strings', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.strings GlobMatch single source');
  Check(Pos('nextpas.core.text.char', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.char IsAlpha single source');
  Check(Pos('nextpas.core.text.conv', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.conv IntToStr single source');
  Check(Pos('nextpas.core.fs', LoadSourceText('src/nextpas.core.respack.embed.pas')) = 0,
    'embed must not reference fs (L1 single source)');

  { 正向断言：seam 单元确实声明了 fs 依赖（防白名单失效漂移） }
  Src := LoadSourceText('src/nextpas.core.respack.dirsource.pas');
  Check(Pos('nextpas.core.fs', Src) > 0, 'dirsource declares fs dependency');
  { 依赖白名单：reader/writer 仅依赖 base/bytes；唯一 fs 缝隙已锁定 }
  Src := LoadSourceText('src/nextpas.core.respack.base.pas');
  Check(Pos('nextpas.core.fs', Src) = 0, 'base must not reference fs');
  Src := LoadSourceText('src/nextpas.core.respack.reader.pas');
  Check(Pos('nextpas.core.fs', Src) = 0, 'reader must not reference fs');
  Src := LoadSourceText('src/nextpas.core.respack.writer.pas');
  Check(Pos('nextpas.core.fs', Src) = 0, 'writer must not reference fs');
end;

procedure TestExceptionRootDiscipline;
var
  Src: string;
begin
  { 错误族必须显式继承自 nextpas.core.exception.Exception 根。
    裸 RTL 引用已由扫描器覆盖；此处断言声明形态本身 }
  Src := LoadSourceText('src/nextpas.core.respack.base.pas');
  Check(Pos('nextpas.core.exception', Src) > 0, 'references exception root: base');
  Check(Pos('= class(Exception)', Src) > 0, 'errors inherit exception root: base');
  Check(Pos('nextpas.core.bytes.binary', Src) > 0, 'base declares bytes.binary single source');
  Check(Pos('nextpas.core.bytes.pathvalid', Src) > 0, 'base declares bytes.pathvalid single source');
  Check(Pos('nextpas.core.checksum.fnv32', Src) > 0, 'base declares checksum.fnv32 single source');
end;

begin
  T := TTestSuite.Create('nextpas.respack.source.contract');
  T.Test('respack sources no bare FPC RTL', @TestRespackSourcesNoFpcRtl);
  T.Test('respack gate sources no bare FPC RTL', @TestRespackGateSourcesNoFpcRtl);
  T.Test('L2→L2 seam uniqueness', @TestSeamUniqueness);
  T.Test('exception root discipline', @TestExceptionRootDiscipline);
  if not T.Run then Halt(1);
end.
