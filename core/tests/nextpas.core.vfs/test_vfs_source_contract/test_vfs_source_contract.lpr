program test_vfs_source_contract;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.fs;

{ 源契约门禁：respack(5 单元) + vfs(9 单元) 的 uses 白名单锁定。
  1) 裸 FPC RTL 引用零容忍（复用仓库共享扫描器 fpc_rtl_uses_scan.inc，
     与 test_fs/test_path 同机制，不自造）
  2) L2→L2 seam 唯一性：除 vfs.os / respack.dirsource 外，
     任何模块单元不得引用 nextpas.core.fs
  3) 异常根纪律：全部异常类挂在 nextpas.core.exception }

{$I ../../fpc_rtl_uses_scan.inc}

var
  T: TTestSuite;

function LoadSourceText(const ARelativePath: string): string;
begin
  Result := nextpas.core.fs.ReadFileText(nextpas.core.fs.PathRealPath('../../../' + ARelativePath));
end;

procedure AssertSourceNoBareFpcRtlUses(const ALabel, ASource: string);
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

procedure ScanList(const ALabelPrefix: string;
  const AFiles: array of string);
var
  I: Integer;
begin
  for I := Low(AFiles) to High(AFiles) do
    AssertSourceNoBareFpcRtlUses(ALabelPrefix + ' ' + AFiles[I],
      LoadSourceText(AFiles[I]));
end;

{ seam 唯一性：白名单外不得出现 nextpas.core.fs 引用 }
procedure AssertNoFsSeam(const ALabel, ASource: string);
begin
  Check(Pos('nextpas.core.fs', ASource) = 0,
    ALabel + ' — must not reference nextpas.core.fs');
end;

{ embed 变体：允许 fs.glob（纯字符串匹配，非 IO），其余 fs 单元仍禁。
  不用 StringReplace（SysUtils 词汇），手写剔除 }
procedure AssertNoFsSeamExceptGlob(const ALabel, ASource: string);
var
  S: string;
  Hit: SizeInt;
begin
  S := ASource;
  repeat
    Hit := Pos('nextpas.core.fs.glob', S);
    if Hit > 0 then
      Delete(S, Hit, Length('nextpas.core.fs.glob'));
  until Hit = 0;
  Check(Pos('nextpas.core.fs', S) = 0,
    ALabel + ' — only nextpas.core.fs.glob allowed');
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
var
  I: Integer;
begin
  for I := Low(FILES) to High(FILES) do
    AssertSourceNoBareFpcRtlUses('respack src', LoadSourceText(FILES[I]));
end;

procedure TestVfsSourcesNoFpcRtl;
const
  FILES: array[0..12] of string = (
    'src/nextpas.core.vfs.pas',
    'src/nextpas.core.vfs.base.pas',
    'src/nextpas.core.vfs.intf.pas',
    'src/nextpas.core.vfs.errors.pas',
    'src/nextpas.core.vfs.memtree.pas',
    'src/nextpas.core.vfs.util.pas',
    'src/nextpas.core.vfs.os.pas',
    'src/nextpas.core.vfs.embedded.pas',
    'src/nextpas.core.vfs.sub.pas',
    'src/nextpas.core.vfs.mount.pas',
    'src/nextpas.core.vfs.overlay.pas',
    'src/nextpas.core.vfs.transform.pas',
    'src/nextpas.core.vfs.compressed.pas');
var
  I: Integer;
begin
  for I := Low(FILES) to High(FILES) do
    AssertSourceNoBareFpcRtlUses('vfs src', LoadSourceText(FILES[I]));
end;

procedure TestVfsGateSourcesNoFpcRtl;
const
  FILES: array[0..3] of string = (
    'tests/nextpas.core.vfs/test_vfs_memtree/test_vfs_memtree.lpr',
    'tests/nextpas.core.vfs/test_vfs_embedded/test_vfs_embedded.lpr',
    'tests/nextpas.core.vfs/test_vfs_conformance/test_vfs_conformance.lpr',
    'tests/nextpas.core.vfs/test_vfs_source_contract/test_vfs_source_contract.lpr');
var
  I: Integer;
begin
  for I := Low(FILES) to High(FILES) do
    AssertSourceNoBareFpcRtlUses('vfs gate', LoadSourceText(FILES[I]));
end;

procedure TestSeamUniqueness;
const
  NO_SEAM: array[0..16] of string = (
    'src/nextpas.core.respack.pas',
    'src/nextpas.core.respack.base.pas',
    'src/nextpas.core.respack.writer.pas',
    'src/nextpas.core.respack.reader.pas',
    'src/nextpas.core.respack.embed.pas',
    'src/nextpas.core.vfs.pas',
    'src/nextpas.core.vfs.base.pas',
    'src/nextpas.core.vfs.intf.pas',
    'src/nextpas.core.vfs.errors.pas',
    'src/nextpas.core.vfs.memtree.pas',
    'src/nextpas.core.vfs.util.pas',
    'src/nextpas.core.vfs.embedded.pas',
    'src/nextpas.core.vfs.sub.pas',
    'src/nextpas.core.vfs.mount.pas',
    'src/nextpas.core.vfs.overlay.pas',
    'src/nextpas.core.vfs.transform.pas',
    'src/nextpas.core.vfs.compressed.pas');
var
  I: Integer;
  Src: string;
begin
  { 白名单外的单元一律禁 fs 引用；os/dirsource 是仅有的两个 IO seam（L2→L2 registry 明示 + source-contract 门禁），
    embed 已收敛至 L1 text.strings/text.char/text.conv 三单源（GlobMatch/IsAlpha/IntToStr 各归一、PChar 零拷贝 + inline，fs.glob 薄转发同源），不再构成 L2→L2 }
  for I := Low(NO_SEAM) to High(NO_SEAM) do
    AssertNoFsSeam(NO_SEAM[I], LoadSourceText(NO_SEAM[I]));
  Check(Pos('nextpas.core.text.strings',
    LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.strings GlobMatch single source');
  Check(Pos('nextpas.core.text.char',
    LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.char IsAlpha single source');
  Check(Pos('nextpas.core.text.conv',
    LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.conv IntToStr single source');
  Check(Pos('nextpas.core.fs', LoadSourceText('src/nextpas.core.respack.embed.pas')) = 0,
    'embed must not reference fs (L1 single source)');

  { 正向断言：两个 seam 单元确实声明了 fs 依赖（防白名单失效漂移） }
  Src := LoadSourceText('src/nextpas.core.vfs.os.pas');
  Check(Pos('nextpas.core.fs,', Src) > 0, 'os unit declares fs dependency');
  Src := LoadSourceText('src/nextpas.core.respack.dirsource.pas');
  Check(Pos('nextpas.core.fs', Src) > 0,
    'dirsource declares fs dependency');

  { compress 缝隙：transform/compressed 唯一允许的 L2→L2 decorator 缝隙，登记于 module-registry }
  Src := LoadSourceText('src/nextpas.core.vfs.compressed.pas');
  Check(Pos('nextpas.core.compress', Src) > 0,
    'compressed declares compress dependency');
  Src := LoadSourceText('src/nextpas.core.vfs.transform.pas');
  Check(Pos('nextpas.core.fs', Src) = 0,
    'transform must not reference fs');
  { base 纯度：四件套最底层不得直连 compress.base，GZIP_MAX canonical 寄居 compress.base，vfs 侧字面量对齐 }
  Src := LoadSourceText('src/nextpas.core.vfs.base.pas');
  Check(Pos('nextpas.core.compress', Src) = 0,
    'vfs.base must not reference compress (L0 purity, no L2→L2)');
  Check(Pos('32 * 1024 * 1024', Src) > 0,
    'vfs.base VFS_DECOMPRESS_MAX_BYTES must be literal 32MiB aligned with compress GZIP_MAX');
  { 数值一致性：compressed 与 base 均以字面量数值对齐 canonical GZIP_MAX，接口层无 L2→L2 直连 compress.base，漂移由字面量一致性锁定 }
  Src := LoadSourceText('src/nextpas.core.vfs.compressed.pas');
  Check(Pos('32 * 1024 * 1024', Src) > 0,
    'compressed VFS_DECOMPRESS_MAX_BYTES must be literal 32MiB aligned with compress GZIP_MAX (no L2→L2 alias)');
  Check(Pos('nextpas.core.compress.base', Src) = 0,
    'compressed must not directly reference compress.base (L2→L2 decoupled, literal aligned via source-contract)');
  Check(Pos('nextpas.core.compress.gzip', Src) > 0,
    'compressed declares compress.gzip dependency for GzipDecompress');
  Check(Pos('COMPRESSED_HEADER_PEEK', Src) = 0,
    'compressed must not define COMPRESSED_HEADER_PEEK alias (single source via transform.TRANSFORM_HEADER_PEEK)');
end;

procedure TestExceptionRootDiscipline;
const
  FILES: array[0..1] of string = (
    'src/nextpas.core.respack.base.pas',
    'src/nextpas.core.vfs.errors.pas');
var
  I: Integer;
  Src: string;
begin
  { 错误族必须显式继承自 nextpas.core.exception.Exception 根。
    裸 RTL 引用已由扫描器覆盖；此处断言声明形态本身 }
  for I := Low(FILES) to High(FILES) do
  begin
    Src := LoadSourceText(FILES[I]);
    Check(Pos('nextpas.core.exception', Src) > 0,
      'references exception root: ' + FILES[I]);
    Check(Pos('= class(Exception)', Src) > 0,
      'errors inherit exception root: ' + FILES[I]);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.vfs.source.contract');
  T.Test('respack sources no bare FPC RTL', @TestRespackSourcesNoFpcRtl);
  T.Test('vfs sources no bare FPC RTL', @TestVfsSourcesNoFpcRtl);
  T.Test('vfs gate sources no bare FPC RTL', @TestVfsGateSourcesNoFpcRtl);
  T.Test('L2→L2 seam uniqueness', @TestSeamUniqueness);
  T.Test('exception root discipline', @TestExceptionRootDiscipline);
  if not T.Run then Halt(1);
end.
