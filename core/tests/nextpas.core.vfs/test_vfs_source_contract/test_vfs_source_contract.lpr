program test_vfs_source_contract;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.fs;

{ 源契约门禁：respack(6 单元) + vfs(13 单元) 的 uses 白名单锁定。
  1) 裸 FPC RTL 引用零容忍（复用仓库共享扫描器 fpc_rtl_uses_scan.inc，
     与 test_fs/test_path 同机制，不自造）
  2) L2→L2 seam 唯一性：vfs 持有 embedded→respack.reader 与 os→fs/path 两处 L2→L2 allowlist 单向缝（超出默认 L0-L1，需门禁防循环，registry+design-conventions 双锁）；除 vfs.os / respack.dirsource 外，任何模块单元不得引用 nextpas.core.fs；除 vfs.embedded 外，任何 vfs 单元不得引用 respack
  3) 单向防循环：respack/fs 侧禁反向引用 vfs，mount/overlay 纯复合零额外依赖，transform/compressed 为 L3 单缝寄居白名单过渡
  4) 异常根纪律：全部异常类挂在 nextpas.core.exception
  5) 单源与性能：embedded 复用 bytes.ops 单源 inline 零拷贝，资源释放不丢（SpinLock 池 TryPushPool） }

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

procedure AssertNoRespackSeam(const ALabel, ASource: string);
begin
  Check(Pos('nextpas.core.respack', ASource) = 0,
    ALabel + ' — must not reference nextpas.core.respack (only embedded allowed)');
end;

procedure AssertNoVfsSeam(const ALabel, ASource: string);
begin
  Check(Pos('nextpas.core.vfs', ASource) = 0,
    ALabel + ' — must not reference nextpas.core.vfs (one-way, no cycle)');
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
  // vfs 侧除 embedded 外禁 respack（单向 embedded→respack.reader allowlist）
  NO_RESPACK: array[0..11] of string = (
    'src/nextpas.core.vfs.pas',
    'src/nextpas.core.vfs.base.pas',
    'src/nextpas.core.vfs.intf.pas',
    'src/nextpas.core.vfs.errors.pas',
    'src/nextpas.core.vfs.memtree.pas',
    'src/nextpas.core.vfs.util.pas',
    'src/nextpas.core.vfs.os.pas',
    'src/nextpas.core.vfs.sub.pas',
    'src/nextpas.core.vfs.mount.pas',
    'src/nextpas.core.vfs.overlay.pas',
    'src/nextpas.core.vfs.transform.pas',
    'src/nextpas.core.vfs.compressed.pas');
  // Cycle：respack 侧禁反向 vfs 引用（单向防循环）
  RESPACK_CYCLE: array[0..5] of string = (
    'src/nextpas.core.respack.pas',
    'src/nextpas.core.respack.base.pas',
    'src/nextpas.core.respack.writer.pas',
    'src/nextpas.core.respack.reader.pas',
    'src/nextpas.core.respack.dirsource.pas',
    'src/nextpas.core.respack.embed.pas');
  // Cycle：fs 侧禁反向 vfs 引用
  FS_CYCLE: array[0..3] of string = (
    'src/nextpas.core.fs.pas',
    'src/nextpas.core.fs.base.pas',
    'src/nextpas.core.fs.intf.pas',
    'src/nextpas.core.fs.util.pas');
var
  I: Integer;
  Src: string;
begin
  { 白名单外的单元一律禁 fs 引用；os/dirsource 是仅有的两个 fs IO seam（L2→L2 registry 明示 + source-contract 门禁），
    embed 已收敛至 L1 text.strings/text.char/text.conv 三单源（GlobMatch/IsAlpha/IntToStr 各归一、PChar 零拷贝 + inline，fs.glob 薄转发同源），不再构成 L2→L2 }
  for I := Low(NO_SEAM) to High(NO_SEAM) do
    AssertNoFsSeam(NO_SEAM[I], LoadSourceText(NO_SEAM[I]));
  // vfs→respack 单向：仅 embedded 允许，其余 vfs 单元禁 respack（超出默认 L0-L1 的单向 allowlist，需门禁防循环）
  for I := Low(NO_RESPACK) to High(NO_RESPACK) do
    AssertNoRespackSeam(NO_RESPACK[I], LoadSourceText(NO_RESPACK[I]));
  Check(Pos('nextpas.core.respack.reader',
    LoadSourceText('src/nextpas.core.vfs.embedded.pas')) > 0,
    'embedded declares respack.reader seam (allowlist one-way)');
  // Cycle：respack 侧禁 vfs 反向
  for I := Low(RESPACK_CYCLE) to High(RESPACK_CYCLE) do
    AssertNoVfsSeam(RESPACK_CYCLE[I], LoadSourceText(RESPACK_CYCLE[I]));
  // Cycle：fs 侧禁 vfs 反向（fs 不应依赖 vfs，避免 L2 循环）
  for I := Low(FS_CYCLE) to High(FS_CYCLE) do
    AssertNoVfsSeam(FS_CYCLE[I], LoadSourceText(FS_CYCLE[I]));
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

  { 正向断言：两个 seam 单元确实声明了 fs/respack 依赖（防白名单失效漂移） }
  Src := LoadSourceText('src/nextpas.core.vfs.os.pas');
  Check(Pos('nextpas.core.fs', Src) > 0, 'os unit declares fs seam (allowlist one-way)');
  Check(Pos('nextpas.core.respack', Src) = 0, 'os must not reference respack (seam isolation)');
  Src := LoadSourceText('src/nextpas.core.vfs.embedded.pas');
  Check(Pos('nextpas.core.respack', Src) > 0, 'embedded declares respack seam');
  Check(Pos('nextpas.core.fs', Src) = 0, 'embedded must not reference fs (seam isolation)');
  Src := LoadSourceText('src/nextpas.core.respack.dirsource.pas');
  Check(Pos('nextpas.core.fs', Src) > 0,
    'dirsource declares fs dependency');
  // embedded bytes.ops 单源 + inline/零拷贝证据 + 资源释放不丢证据
  Src := LoadSourceText('src/nextpas.core.vfs.embedded.pas');
  Check(Pos('nextpas.core.bytes.ops', Src) > 0, 'embedded declares bytes.ops single source');
  Check(Pos('inline', Src) > 0, 'embedded has inline hot path');
  Check(Pos('SpinLock', Src) > 0, 'embedded has SpinLock pool stability');
  Check(Pos('TryPushPool', Src) > 0, 'embedded has TryPushPool release gate');
  Check(Pos('FPoolLock', Src) > 0, 'embedded has FPoolLock resource guard');

  { compress 缝隙：transform/compressed 唯一允许的 L2→L2 decorator 缝隙，登记于 module-registry }
  Src := LoadSourceText('src/nextpas.core.vfs.compressed.pas');
  Check(Pos('nextpas.core.compress', Src) > 0,
    'compressed declares compress dependency');
  Src := LoadSourceText('src/nextpas.core.vfs.transform.pas');
  Check(Pos('nextpas.core.fs', Src) = 0,
    'transform must not reference fs');
  Check(Pos('nextpas.core.respack', Src) = 0,
    'transform must not reference respack');
  { base 纯度：四件套最底层不得直连 compress.base，GZIP_MAX canonical 仅寄居 compressed 薄门面 }
  Src := LoadSourceText('src/nextpas.core.vfs.base.pas');
  Check(Pos('nextpas.core.compress', Src) = 0,
    'vfs.base must not reference compress (L0 purity, no L2→L2)');
  Check(Pos('32 * 1024 * 1024', Src) > 0,
    'vfs.base VFS_DECOMPRESS_MAX_BYTES must be literal 32MiB aligned with compress GZIP_MAX');
  { 数值一致性：compressed 仍为别名单源，base 为字面量对齐，防漂移 }
  Src := LoadSourceText('src/nextpas.core.vfs.compressed.pas');
  Check(Pos('GZIP_MAX_DECOMPRESS_BYTES', Src) > 0,
    'compressed keeps GZIP_MAX single-source alias');
  // mount/overlay 纯复合零额外依赖：禁 fs/respack/compress
  for I := 0 to 1 do
  begin
    if I = 0 then Src := LoadSourceText('src/nextpas.core.vfs.mount.pas')
    else Src := LoadSourceText('src/nextpas.core.vfs.overlay.pas');
    Check(Pos('nextpas.core.fs', Src) = 0, 'mount/overlay must not reference fs (pure composite)');
    Check(Pos('nextpas.core.respack', Src) = 0, 'mount/overlay must not reference respack');
    Check(Pos('nextpas.core.compress', Src) = 0, 'mount/overlay must not reference compress');
  end;
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
