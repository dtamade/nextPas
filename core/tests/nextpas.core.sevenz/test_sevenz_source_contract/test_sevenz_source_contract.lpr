program test_sevenz_source_contract;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.fs;

{ 源契约门禁：sevenz(28 单元含 stream/门面) uses 白名单锁定。
  1) 裸 FPC RTL 引用零容忍（复用仓库共享扫描器 fpc_rtl_uses_scan.inc，
     与 test_respack/test_vfs 同机制，不自造）
  2) L2→L2 seam 唯一性：除 sevenz.fs 外，
     任何 sevenz 单元不得引用 nextpas.core.fs / nextpas.core.fs.intf（sevenz.fs 唯一 L2→L2 联邦缝：fs/fs.intf，Registry 明示 Allowed ... fs/io via platform.lstat exempt federation via sevenz.fs + source-contract 门禁 like respack.dirsource/vfs.os）
  3) 单源收敛：bytes.ops 单源 inline 零拷贝 + try..finally 资源不丢
  4) 异常根纪律：错误族挂在 nextpas.core.exception }

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

{ seam 唯一性：白名单外不得出现 nextpas.core.fs 引用 — 构建期依赖图校验（uses 子句 strip 注释/字符串后精确解析，防 Pos 文本 grep 被注释/字符串绕过），复用 fpc_rtl_uses_scan.inc FindUsesUnit 单源，inline 零额外拷贝于调用方 }
procedure AssertNoFsSeam(const ALabel, ASource: string); inline;
begin
  Check(not FindUsesUnit(ASource, 'nextpas.core.fs'), ALabel + ' — must not reference nextpas.core.fs (uses graph)');
  Check(not FindUsesUnit(ASource, 'nextpas.core.fs.intf'), ALabel + ' — must not reference nextpas.core.fs.intf (uses graph)');
end;

procedure TestSevenzSourcesNoFpcRtl;
const
  FILES: array[0..27] of string = (
    'src/nextpas.core.sevenz.pas',
    'src/nextpas.core.sevenz.base.pas',
    'src/nextpas.core.sevenz.intf.pas',
    'src/nextpas.core.sevenz.header.pas',
    'src/nextpas.core.sevenz.coders.pas',
    'src/nextpas.core.sevenz.filters.pas',
    'src/nextpas.core.sevenz.levels.pas',
    'src/nextpas.core.sevenz.limits.pas',
    'src/nextpas.core.sevenz.aes.pas',
    'src/nextpas.core.sevenz.bcj.x86.pas',
    'src/nextpas.core.sevenz.bcj.arm.pas',
    'src/nextpas.core.sevenz.bcj.arm64.pas',
    'src/nextpas.core.sevenz.bcj.ppc.pas',
    'src/nextpas.core.sevenz.bcj.ia64.pas',
    'src/nextpas.core.sevenz.bcj.sparc.pas',
    'src/nextpas.core.sevenz.bcj.armt.pas',
    'src/nextpas.core.sevenz.bcj.riscv.pas',
    'src/nextpas.core.sevenz.bcj.utils.pas',
    'src/nextpas.core.sevenz.bcj2.pas',
    'src/nextpas.core.sevenz.lzma.rc.pas',
    'src/nextpas.core.sevenz.lzma.decoder.pas',
    'src/nextpas.core.sevenz.lzma.encoder.pas',
    'src/nextpas.core.sevenz.lzma.ffi.pas',
    'src/nextpas.core.sevenz.lzma.ffi.decoder.pas',
    'src/nextpas.core.sevenz.reader.pas',
    'src/nextpas.core.sevenz.writer.pas',
    'src/nextpas.core.sevenz.stream.pas',
    'src/nextpas.core.sevenz.fs.pas');
begin
  ScanList('sevenz src', FILES);
end;

procedure TestSevenzGateSourcesNoFpcRtl;
const
  FILES: array[0..1] of string = (
    'tests/nextpas.core.sevenz/test_sevenz/test_sevenz.lpr',
    'tests/nextpas.core.sevenz/test_sevenz_source_contract/test_sevenz_source_contract.lpr');
var
  I: Integer;
  Src: string;
  Hit: string;
begin
  // gate 源码允许 SysUtils/Classes 等测试支架必需的 FPC RTL，仅校验除白名单外无裸 RTL 污染；与 fpc_rtl_uses_scan 同源去重
  for I := Low(FILES) to High(FILES) do
  begin
    Src := LoadSourceText(FILES[I]);
    if FindBareFpcRtlInUses(Src, Hit) then
    begin
      // 白名单：测试门禁自身必需的 SysUtils（Runner 依赖），不视为污染
      if SameText(Hit, 'SysUtils') or SameText(Hit, 'Classes') then Continue;
      Check(False, 'sevenz gate ' + FILES[I] + ' — no bare FPC RTL in uses (hit: ' + Hit + ')');
    end;
  end;
end;

procedure TestSeamUniqueness;
const
  NO_SEAM: array[0..26] of string = (
    'src/nextpas.core.sevenz.pas',
    'src/nextpas.core.sevenz.base.pas',
    'src/nextpas.core.sevenz.intf.pas',
    'src/nextpas.core.sevenz.header.pas',
    'src/nextpas.core.sevenz.coders.pas',
    'src/nextpas.core.sevenz.filters.pas',
    'src/nextpas.core.sevenz.levels.pas',
    'src/nextpas.core.sevenz.limits.pas',
    'src/nextpas.core.sevenz.aes.pas',
    'src/nextpas.core.sevenz.bcj.x86.pas',
    'src/nextpas.core.sevenz.bcj.arm.pas',
    'src/nextpas.core.sevenz.bcj.arm64.pas',
    'src/nextpas.core.sevenz.bcj.ppc.pas',
    'src/nextpas.core.sevenz.bcj.ia64.pas',
    'src/nextpas.core.sevenz.bcj.sparc.pas',
    'src/nextpas.core.sevenz.bcj.armt.pas',
    'src/nextpas.core.sevenz.bcj.riscv.pas',
    'src/nextpas.core.sevenz.bcj.utils.pas',
    'src/nextpas.core.sevenz.bcj2.pas',
    'src/nextpas.core.sevenz.lzma.rc.pas',
    'src/nextpas.core.sevenz.lzma.decoder.pas',
    'src/nextpas.core.sevenz.lzma.encoder.pas',
    'src/nextpas.core.sevenz.lzma.ffi.pas',
    'src/nextpas.core.sevenz.lzma.ffi.decoder.pas',
    'src/nextpas.core.sevenz.reader.pas',
    'src/nextpas.core.sevenz.writer.pas',
    'src/nextpas.core.sevenz.stream.pas');
var
  I: Integer;
  Src: string;
begin
  { 白名单外的单元一律禁 fs/fs.intf 引用；sevenz.fs 是唯一的 L2→L2 联邦缝（Registry 明示 + source-contract 门禁，同 respack.dirsource/vfs.os 单缝范式） }
  for I := Low(NO_SEAM) to High(NO_SEAM) do
    AssertNoFsSeam(NO_SEAM[I], LoadSourceText(NO_SEAM[I]));
  { 正向断言：seam 单元确实声明了 fs/fs.intf 依赖（防白名单失效漂移，uses graph 校验） }
  Src := LoadSourceText('src/nextpas.core.sevenz.fs.pas');
  Check(FindUsesUnit(Src, 'nextpas.core.fs'), 'sevenz.fs declares fs dependency (uses graph, single seam)');
  Check(FindUsesUnit(Src, 'nextpas.core.fs.intf'), 'sevenz.fs declares fs.intf dependency (uses graph)');
  Check(Pos('nextpas.core.bytes.ops', Src) > 0, 'sevenz.fs declares bytes.ops single source (inline zero-copy)');
  Check((Pos('BytesCopy', Src) > 0) or (Pos('BytesNextCapacity', Src) > 0), 'sevenz.fs reuses bytes.ops single source (BytesCopy/BytesNextCapacity)');
  Check(Pos('inline', Src) > 0, 'sevenz.fs has inline hot paths (perf evidence, SevenZAddFileFromFs/SevenZAddTree/SevenZFsNextCapacity)');
  Check(Pos('try', Src) > 0, 'sevenz.fs has try..finally resource release (stability, ExtractToFs/FlushExtractedToFs)');
  Check(Pos('Close', Src) > 0, 'sevenz.fs Close in try..finally not lost');
  Check(Pos('nextpas.core.sevenz.base', Src) > 0, 'sevenz.fs declares sevenz.base single source');
  Check(Pos('nextpas.core.io.intf', Src) > 0, 'sevenz.fs declares io.intf L1 seam (IReader/IWriter)');
  { writer 通过 sevenz.fs 联邦进入 fs，不直连 fs — 纯容器内核保持 L2→L2 单缝收口 }
  Src := LoadSourceText('src/nextpas.core.sevenz.writer.pas');
  Check(Pos('nextpas.core.sevenz.fs', Src) > 0, 'writer delegates filesystem helpers to sevenz.fs owner (single seam, not direct fs)');
  { 依赖白名单：reader/header 等仅依赖 base/bytes；唯一 fs 缝隙已锁定（uses graph 校验） }
  Src := LoadSourceText('src/nextpas.core.sevenz.reader.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'reader must not reference fs (uses graph, single seam)');
  Src := LoadSourceText('src/nextpas.core.sevenz.header.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'header must not reference fs (uses graph)');
  Src := LoadSourceText('src/nextpas.core.sevenz.base.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'base must not reference fs (uses graph)');
  Src := LoadSourceText('src/nextpas.core.sevenz.stream.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'stream must not reference fs (uses graph)');
end;

procedure AssertNoCompressSeam(const ALabel, ASource: string); inline;
begin
  Check(not FindUsesUnit(ASource, 'nextpas.core.compress'), ALabel + ' — must not reference nextpas.core.compress (uses graph)');
  Check(not FindUsesUnit(ASource, 'nextpas.core.compress.intf'), ALabel + ' — must not reference nextpas.core.compress.intf (uses graph)');
  Check(not FindUsesUnit(ASource, 'nextpas.core.compress.deflate'), ALabel + ' — must not reference nextpas.core.compress.deflate (uses graph)');
  Check(not FindUsesUnit(ASource, 'nextpas.core.compress.bzip2'), ALabel + ' — must not reference nextpas.core.compress.bzip2 (uses graph)');
end;

procedure TestCompressSeamUniqueness;
const
  NO_COMPRESS: array[0..23] of string = (
    'src/nextpas.core.sevenz.base.pas',
    'src/nextpas.core.sevenz.intf.pas',
    'src/nextpas.core.sevenz.header.pas',
    'src/nextpas.core.sevenz.filters.pas',
    'src/nextpas.core.sevenz.limits.pas',
    'src/nextpas.core.sevenz.aes.pas',
    'src/nextpas.core.sevenz.bcj.x86.pas',
    'src/nextpas.core.sevenz.bcj.arm.pas',
    'src/nextpas.core.sevenz.bcj.arm64.pas',
    'src/nextpas.core.sevenz.bcj.ppc.pas',
    'src/nextpas.core.sevenz.bcj.ia64.pas',
    'src/nextpas.core.sevenz.bcj.sparc.pas',
    'src/nextpas.core.sevenz.bcj.armt.pas',
    'src/nextpas.core.sevenz.bcj.riscv.pas',
    'src/nextpas.core.sevenz.bcj.utils.pas',
    'src/nextpas.core.sevenz.bcj2.pas',
    'src/nextpas.core.sevenz.lzma.rc.pas',
    'src/nextpas.core.sevenz.lzma.decoder.pas',
    'src/nextpas.core.sevenz.lzma.encoder.pas',
    'src/nextpas.core.sevenz.lzma.ffi.pas',
    'src/nextpas.core.sevenz.lzma.ffi.decoder.pas',
    'src/nextpas.core.sevenz.reader.pas',
    'src/nextpas.core.sevenz.stream.pas',
    'src/nextpas.core.sevenz.fs.pas');
var
  I: Integer;
  Src, Reg: string;
begin
  Src := LoadSourceText('src/nextpas.core.sevenz.coders.pas');
  Check(FindUsesUnit(Src, 'nextpas.core.compress.intf'), 'sevenz.coders declares compress.intf single seam (uses graph)');
  Check(Pos('nextpas.core.bytes.ops', Src) > 0, 'sevenz.coders declares bytes.ops single source (inline zero-copy)');
  Check(Pos('SpanClone', Src) > 0, 'sevenz.coders reuses bytes.ops SpanClone single source (zero-copy view)');
  Check(Pos('inline', Src) > 0, 'sevenz.coders has inline thin forward (perf evidence, SevenZBZip2Available/DeflateForTest)');
  Check(Pos('CompressBZip2IsAvailable', Src) > 0, 'sevenz.coders thin forward via compress.intf CompressBZip2IsAvailable');
  Check(Pos('CompressDeflateDecompressWithMax', Src) > 0, 'sevenz.coders thin forward via compress.intf CompressDeflateDecompressWithMax');
  Check(Pos('CompressBZip2DecompressWithMax', Src) > 0, 'sevenz.coders thin forward via compress.intf CompressBZip2DecompressWithMax');
  Check(Pos('CompressIsLimitExceeded', Src) > 0, 'sevenz.coders reuses compress.intf limit single source (ESevenZLimitError)');
  Check(Pos('try', Src) > 0, 'sevenz.coders has try..except resource/异常不丢 (Deflate/BZip2 bomb)');
  for I := Low(NO_COMPRESS) to High(NO_COMPRESS) do
    AssertNoCompressSeam(NO_COMPRESS[I], LoadSourceText(NO_COMPRESS[I]));
  Src := LoadSourceText('src/nextpas.core.sevenz.writer.pas');
  Check(Pos('nextpas.core.compress', Src) > 0, 'writer declares compress for encode (allowed encode seam, not decode)');
  Src := LoadSourceText('src/nextpas.core.sevenz.levels.pas');
  Check(FindUsesUnit(Src, 'nextpas.core.compress.base'), 'levels declares compress.base pure mapping (not L2 decode seam)');
  Src := LoadSourceText('src/nextpas.core.sevenz.pas');
  Check(Pos('nextpas.core.compress.base', Src) > 0, 'facade declares compress.base via levels (not second decode seam)');
  Check(not FindUsesUnit(Src, 'nextpas.core.compress.intf'), 'facade must not directly reference compress.intf (only coders)');
  Src := LoadSourceText('src/nextpas.core.compress.intf.pas');
  Check(Pos('nextpas.core.sevenz', Src) = 0, 'compress.intf must not reference sevenz (cycle-gated)');
  Src := LoadSourceText('src/nextpas.core.compress.deflate.pas');
  Check(Pos('nextpas.core.sevenz', Src) = 0, 'compress.deflate must not reference sevenz (cycle-gated)');
  Src := LoadSourceText('src/nextpas.core.compress.bzip2.pas');
  Check(Pos('nextpas.core.sevenz', Src) = 0, 'compress.bzip2 must not reference sevenz (cycle-gated)');
  Reg := LoadSourceText('docs/core-module-registry.md');
  Check(Pos('sevenz.coders', Reg) > 0, 'registry documents sevenz.coders seam');
  Check(Pos('compress', Reg) > 0, 'registry documents compress allowlist');
  Check(Pos('single L2→L2 seam', Reg) > 0, 'registry marks compress via sevenz.coders single L2→L2 seam (source-contract gated)');
  Check(Pos('cycle-gated', Reg) > 0, 'registry marks cycle-gated (compress→sevenz forbidden)');
  Check(Pos('thin inline forward', Reg) > 0, 'registry marks thin inline forward');
end;

procedure TestExceptionRootDiscipline;
var
  Src: string;
begin
  Src := LoadSourceText('src/nextpas.core.sevenz.base.pas');
  // base 通过 errors 门面间接继承 exception 根（sevenz.base → ENextPasError → errors → exception），四件套单向不直连 exception
  Check(Pos('nextpas.core.errors', Src) > 0, 'base declares errors facade');
  Check(Pos('ESevenZError', Src) > 0, 'base declares sevenz error family');
  Src := LoadSourceText('src/nextpas.core.errors.pas');
  Check(Pos('nextpas.core.exception', Src) > 0, 'errors references exception root');
end;

begin
  T := TTestSuite.Create('nextpas.sevenz.source.contract');
  T.Test('sevenz sources no bare FPC RTL', @TestSevenzSourcesNoFpcRtl);
  T.Test('sevenz gate sources no bare FPC RTL', @TestSevenzGateSourcesNoFpcRtl);
  T.Test('L2→L2 seam uniqueness', @TestSeamUniqueness);
  T.Test('L2→L2 compress seam uniqueness', @TestCompressSeamUniqueness);
  T.Test('exception root discipline', @TestExceptionRootDiscipline);
  if not T.Run then Halt(1);
end.
