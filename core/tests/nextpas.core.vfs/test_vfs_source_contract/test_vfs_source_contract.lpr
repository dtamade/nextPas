program test_vfs_source_contract;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.fs;

{ 源契约门禁：respack(5 单元) + vfs(9 单元) 的 uses 白名单锁定。
  1) 裸 FPC RTL 引用零容忍（复用仓库共享扫描器 fpc_rtl_uses_scan.inc，
     与 test_fs/test_path 同机制，不自造）
  2) L2→L2 seam 单点：仅 vfs.backends 持有跨模块 L2 依赖（fs / respack.reader），
     embedded/os 经 backends 间接复用，消除 L2 同层多点直连；其余 vfs 单元禁 fs/respack 直连
     （Registry single-point via backends, bytes.ops 单源 inline 零拷贝 BytesCopy + SpinLock blocking Acquire try-finally 资源不丢, source-contract 强门禁, L7后端独立族收敛单缝）
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

{ L2→L2 respack seam 变体：仅 vfs.backends 允许 respack.reader，其余 vfs 单元禁（Registry single-point via backends, bytes.ops 单源 inline 零拷贝 BytesCopy + SpinLock blocking Acquire, source-contract 强门禁） }
procedure AssertNoRespackSeam(const ALabel, ASource: string);
begin
  Check(Pos('nextpas.core.respack.reader', ASource) = 0,
    ALabel + ' — must not reference nextpas.core.respack.reader (only vfs.backends single-point)');
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
  FILES: array[0..15] of string = (
    'src/nextpas.core.vfs.pas',
    'src/nextpas.core.vfs.base.pas',
    'src/nextpas.core.vfs.intf.pas',
    'src/nextpas.core.vfs.errors.pas',
    'src/nextpas.core.vfs.memtree.pas',
    'src/nextpas.core.vfs.util.pas',
    'src/nextpas.core.vfs.os.pas',
    'src/nextpas.core.vfs.embedded.pas',
    'src/nextpas.core.vfs.backends.pas',
    'src/nextpas.core.vfs.sub.pas',
    'src/nextpas.core.vfs.mount.pas',
    'src/nextpas.core.vfs.overlay.pas',
    'src/nextpas.core.vfs.cache.pas',
    'src/nextpas.core.vfs.transform.pas',
    'src/nextpas.core.vfs.compressed.pas',
    'src/nextpas.core.vfs.decorator.pas');
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
  NO_SEAM: array[0..19] of string = (
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
    'src/nextpas.core.vfs.backends.pas',
    'src/nextpas.core.vfs.sub.pas',
    'src/nextpas.core.vfs.mount.pas',
    'src/nextpas.core.vfs.overlay.pas',
    'src/nextpas.core.vfs.cache.pas',
    'src/nextpas.core.vfs.transform.pas',
    'src/nextpas.core.vfs.compressed.pas',
    'src/nextpas.core.vfs.decorator.pas');
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
  { base 单源：GZIP_MAX canonical 寄居 compress.base，vfs.base 经 compress.base 单源别名无字面量漂移，复用 bytes.ops 单源 inline 零拷贝 }
  Src := LoadSourceText('src/nextpas.core.vfs.base.pas');
  Check(Pos('nextpas.core.compress.base', Src) > 0,
    'vfs.base VFS_DECOMPRESS_MAX_BYTES must alias compress.base single source');
  Check(Pos('GZIP_MAX_DECOMPRESS_BYTES', Src) > 0,
    'vfs.base must reference GZIP_MAX_DECOMPRESS_BYTES canonical');
  Check(Pos('32 * 1024 * 1024', Src) = 0,
    'vfs.base must not duplicate literal 32MiB (single source via compress.base alias)');
  Check(Pos('VfsSpanFromString', Src) > 0,
    'vfs.base must have VfsSpanFromString single source helper (inline zero-copy)');
  Check(Pos('TByteSpan.FromStr', Src) > 0,
    'vfs.base helper must reuse TByteSpan.FromStr single source');
  Check(Pos('inline;', Src) > 0,
    'vfs.base has inline hot paths (perf evidence)');
  { 单源收敛：base 经 compress.base GZIP_MAX 单源别名（无字面量），compressed 经 vfs.base 单源别名复用消除二次字面量双写，链路 canonical 单源 }
  Src := LoadSourceText('src/nextpas.core.vfs.compressed.pas');
  Check(Pos('32 * 1024 * 1024', Src) = 0,
    'compressed must not duplicate literal 32MiB (single source via vfs.base alias)');
  Check(Pos('nextpas.core.vfs.base.VFS_DECOMPRESS_MAX_BYTES', Src) > 0,
    'compressed VFS_DECOMPRESS_MAX_BYTES must alias vfs.base single source');
  Check(Pos('nextpas.core.compress.base', Src) = 0,
    'compressed must not directly reference compress.base (L2→L2 decoupled, alias via vfs.base)');
  Check(Pos('nextpas.core.compress.gzip', Src) > 0,
    'compressed declares compress.gzip dependency for GzipDecompress');
  Check(Pos('COMPRESSED_HEADER_PEEK', Src) = 0,
    'compressed must not define COMPRESSED_HEADER_PEEK alias (single source via transform.TRANSFORM_HEADER_PEEK)');
  { 枚举单源：TDecompressAlgo 唯一声明于 vfs.base，compressed 经别名复用，
    门面经同名常量影子直通纯门面消费者；无二次声明无二义 }
  Src := LoadSourceText('src/nextpas.core.vfs.base.pas');
  Check(Pos('TDecompressAlgo = (daAuto, daGzip)', Src) > 0,
    'vfs.base declares TDecompressAlgo single source');
  Src := LoadSourceText('src/nextpas.core.vfs.compressed.pas');
  Check(Pos('TDecompressAlgo = nextpas.core.vfs.base.TDecompressAlgo', Src) > 0,
    'compressed aliases TDecompressAlgo via vfs.base (no redeclaration)');
  Check(Pos('= (daAuto, daGzip)', Src) = 0,
    'compressed must not redeclare enum values');
  Src := LoadSourceText('src/nextpas.core.vfs.pas');
  Check(Pos('daAuto: TDecompressAlgo = nextpas.core.vfs.base.daAuto', Src) > 0,
    'facade re-exports daAuto value for facade-only consumers');
  Check(Pos('daGzip: TDecompressAlgo = nextpas.core.vfs.base.daGzip', Src) > 0,
    'facade re-exports daGzip value for facade-only consumers');
  { 全族 IVfsView 透传：三后端 + Sub/mount/overlay/transform/compressed 全部实现，
    门面导出视图助手；overlay 热点 List 经 vfs.cache 单源 }
  Check(Pos('IVfsView', LoadSourceText('src/nextpas.core.vfs.sub.pas')) > 0,
    'sub implements IVfsView');
  Check(Pos('IVfsView', LoadSourceText('src/nextpas.core.vfs.mount.pas')) > 0,
    'mount implements IVfsView');
  Check(Pos('IVfsView', LoadSourceText('src/nextpas.core.vfs.overlay.pas')) > 0,
    'overlay implements IVfsView');
  Check(Pos('IVfsView', LoadSourceText('src/nextpas.core.vfs.transform.pas')) > 0,
    'transform implements IVfsView');
  Check(Pos('IVfsView', LoadSourceText('src/nextpas.core.vfs.compressed.pas')) > 0,
    'compressed implements IVfsView');
  Check(Pos('nextpas.core.vfs.cache', LoadSourceText('src/nextpas.core.vfs.overlay.pas')) > 0,
    'overlay List cache via vfs.cache single source');
  Check(Pos('VfsReadAllTextView', Src) > 0,
    'facade exposes view helpers');
  { 二分单源：memtree/embedded 字符串/视图二分收敛于 vfs.base VfsLowerBoundSpan }
  Check(Pos('VfsLowerBoundSpan', LoadSourceText('src/nextpas.core.vfs.base.pas')) > 0,
    'vfs.base declares VfsLowerBoundSpan single source');
  Check(Pos('VfsLowerBoundSpan', LoadSourceText('src/nextpas.core.vfs.memtree.pas')) > 0,
    'memtree reuses VfsLowerBoundSpan');
  Check(Pos('VfsLowerBoundSpan', LoadSourceText('src/nextpas.core.vfs.embedded.pas')) > 0,
    'embedded reuses VfsLowerBoundSpan');
  { decorator 聚合：门面扇出收敛单点收口，复用 transform/compressed 单源，bytes.ops 单源 inline 零拷贝，try-finally 不丢 }  Src := LoadSourceText('src/nextpas.core.vfs.decorator.pas');
  Check(Pos('nextpas.core.vfs.transform', Src) > 0,
    'decorator aggregates transform (single-point fan-out reduction)');
  Check(Pos('nextpas.core.vfs.compressed', Src) > 0,
    'decorator aggregates compressed (single-point fan-out reduction)');
  Check(Pos('32 * 1024 * 1024', Src) = 0,
    'decorator must not duplicate literal 32MiB (single source via vfs.base alias)');
  Check(Pos('nextpas.core.vfs.base.VFS_DECOMPRESS_MAX_BYTES', Src) > 0,
    'decorator VFS_DECOMPRESS_MAX_BYTES must alias vfs.base single source');
  Check(Pos('inline;', Src) > 0,
    'decorator has inline hot paths (perf evidence)');
  Check(Pos('nextpas.core.vfs.decorator', LoadSourceText('src/nextpas.core.vfs.pas')) > 0,
    'facade aggregates via decorator (fan-out reduced 13→12)');
  Check(Pos('nextpas.core.vfs.transform', LoadSourceText('src/nextpas.core.vfs.pas')) = 0,
    'facade must not directly reference transform (via decorator)');
  Check(Pos('nextpas.core.vfs.compressed', LoadSourceText('src/nextpas.core.vfs.pas')) = 0,
    'facade must not directly reference compressed (via decorator)');
  { backends 聚合：三后端单缝收口，门面扇出收敛 12→10，bytes.ops 单源 inline 零拷贝，try-finally 不丢 }
  Src := LoadSourceText('src/nextpas.core.vfs.backends.pas');
  Check(Pos('nextpas.core.vfs.memtree', Src) > 0,
    'backends aggregates memtree (single-point fan-out reduction)');
  Check(Pos('nextpas.core.vfs.embedded', Src) > 0,
    'backends aggregates embedded (single-point fan-out reduction)');
  Check(Pos('nextpas.core.vfs.os', Src) > 0,
    'backends aggregates os (single-point fan-out reduction)');
  Check(Pos('inline;', Src) > 0,
    'backends has inline hot paths (perf evidence)');
  Check(Pos('nextpas.core.vfs.backends', LoadSourceText('src/nextpas.core.vfs.pas')) > 0,
    'facade aggregates via backends (fan-out reduced 12→10)');
  Check(Pos('nextpas.core.vfs.memtree', LoadSourceText('src/nextpas.core.vfs.pas')) = 0,
    'facade must not directly reference memtree (via backends)');
  Check(Pos('nextpas.core.vfs.os', LoadSourceText('src/nextpas.core.vfs.pas')) = 0,
    'facade must not directly reference os (via backends)');
  Check(Pos('nextpas.core.vfs.embedded', LoadSourceText('src/nextpas.core.vfs.pas')) = 0,
    'facade must not directly reference embedded (via backends)');

  { L2→L2 single seam via backends aggregation: only backends may reference respack.reader (Registry single-point, source-contract gated, bytes.ops BytesCopy single-source inline zero-copy + SpinLock blocking Acquire try-finally 资源不丢) }
  Src := LoadSourceText('src/nextpas.core.vfs.backends.pas');
  Check(Pos('nextpas.core.respack.reader', Src) > 0,
    'backends declares respack.reader seam (L2→L2 single-point via backends, bytes.ops single-source)');
  Src := LoadSourceText('src/nextpas.core.vfs.embedded.pas');
  Check(Pos('nextpas.core.respack.reader', Src) = 0,
    'embedded must not directly reference respack.reader (via backends single seam)');
  Check(Pos('nextpas.core.vfs.backends', Src) > 0,
    'embedded reuses backends single seam (L2→L2 unified via backends)');
  Check(Pos('nextpas.core.bytes.ops', Src) > 0,
    'embedded reuses bytes.ops single source (inline zero-copy)');
  Check(Pos('BytesCopy', Src) > 0,
    'embedded reuses BytesCopy single source (not raw Move)');
  Check(Pos('inline;', Src) > 0,
    'embedded has inline hot paths (perf evidence)');
  Check(Pos('try', Src) > 0,
    'embedded has try-finally resource release (stability, not lost)');
  { Only backends may reference respack.reader among vfs family; others must not }
  AssertNoRespackSeam('vfs.base', LoadSourceText('src/nextpas.core.vfs.base.pas'));
  AssertNoRespackSeam('vfs.intf', LoadSourceText('src/nextpas.core.vfs.intf.pas'));
  AssertNoRespackSeam('vfs.errors', LoadSourceText('src/nextpas.core.vfs.errors.pas'));
  AssertNoRespackSeam('vfs.memtree', LoadSourceText('src/nextpas.core.vfs.memtree.pas'));
  AssertNoRespackSeam('vfs.util', LoadSourceText('src/nextpas.core.vfs.util.pas'));
  AssertNoRespackSeam('vfs.os', LoadSourceText('src/nextpas.core.vfs.os.pas'));
  AssertNoRespackSeam('vfs.sub', LoadSourceText('src/nextpas.core.vfs.sub.pas'));
  AssertNoRespackSeam('vfs.mount', LoadSourceText('src/nextpas.core.vfs.mount.pas'));
  AssertNoRespackSeam('vfs.overlay', LoadSourceText('src/nextpas.core.vfs.overlay.pas'));
  AssertNoRespackSeam('vfs.cache', LoadSourceText('src/nextpas.core.vfs.cache.pas'));
  AssertNoRespackSeam('vfs.transform', LoadSourceText('src/nextpas.core.vfs.transform.pas'));
  AssertNoRespackSeam('vfs.compressed', LoadSourceText('src/nextpas.core.vfs.compressed.pas'));
  AssertNoRespackSeam('vfs.decorator', LoadSourceText('src/nextpas.core.vfs.decorator.pas'));
  AssertNoRespackSeam('vfs facade', LoadSourceText('src/nextpas.core.vfs.pas'));
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
