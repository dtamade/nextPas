program test_respack_source_contract;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.fs;

{ 源契约门禁：respack(9 源 + writer.builder 内部单源 + embed.limits 独立策略模块共 12 文件，含 limits 阈值策略单源已抽取至 L1 embed.limits) uses 白名单锁定。
  1) 裸 FPC RTL 引用零容忍（复用仓库共享扫描器 fpc_rtl_uses_scan.inc，
     与 test_fs/test_vfs_source_contract 同机制，不自造）
  2) L2→L2 seam 唯一性：除 respack.dirsource 外，
     任何 respack 单元不得引用 nextpas.core.fs / nextpas.core.io.mapped（dirsource 唯一 L2→L2 IO seam：fs+io.mapped）
  3) 异常根纪律：错误族挂在 nextpas.core.exception
  4) 单源收敛：bytes.ops/bytes.binary 等零拷贝单源；writer.layout 布局单源
     (bytes.ops inline 零拷贝 + collections.algorithms Sort + mem.base AlignUp64)，
     writer.stream 流式两遍分段零双驻留复用 layout 单源，try..finally 不丢资源；
     阈值策略已抽取为 L1 独立模块 nextpas.core.embed.limits（inline 零拷贝，respack.limits 兼容转发） }

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

{ seam 唯一性：白名单外不得出现 nextpas.core.fs / io.mapped 引用 — 构建期依赖图校验（uses 子句 strip 注释/字符串后精确解析，防 Pos 文本 grep 被注释/字符串绕过），复用 fpc_rtl_uses_scan.inc FindUsesUnit 单源，inline 零额外拷贝于调用方 }
procedure AssertNoFsSeam(const ALabel, ASource: string); inline;
begin
  Check(not FindUsesUnit(ASource, 'nextpas.core.fs'), ALabel + ' — must not reference nextpas.core.fs (uses graph)');
  Check(not FindUsesUnit(ASource, 'nextpas.core.io.mapped'), ALabel + ' — must not reference nextpas.core.io.mapped (uses graph)');
end;

procedure TestRespackSourcesNoFpcRtl;
const
  FILES: array[0..11] of string = (
    'src/nextpas.core.respack.pas',
    'src/nextpas.core.respack.base.pas',
    'src/nextpas.core.embed.limits.pas',
    'src/nextpas.core.embed.pas',
    'src/nextpas.core.respack.limits.pas',
    'src/nextpas.core.respack.writer.pas',
    'src/nextpas.core.respack.writer.layout.pas',
    'src/nextpas.core.respack.writer.builder.pas',
    'src/nextpas.core.respack.writer.stream.pas',
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
  NO_SEAM: array[0..10] of string = (
    'src/nextpas.core.respack.pas',
    'src/nextpas.core.respack.base.pas',
    'src/nextpas.core.embed.limits.pas',
    'src/nextpas.core.embed.pas',
    'src/nextpas.core.respack.limits.pas',
    'src/nextpas.core.respack.writer.pas',
    'src/nextpas.core.respack.writer.layout.pas',
    'src/nextpas.core.respack.writer.builder.pas',
    'src/nextpas.core.respack.writer.stream.pas',
    'src/nextpas.core.respack.reader.pas',
    'src/nextpas.core.respack.embed.pas');
var
  I: Integer;
  Src: string;
begin
  { 白名单外的单元一律禁 fs/io.mapped 引用；dirsource 是唯一的 L2→L2 IO seam（fs+io.mapped mmap via mem.memory_map，registry 明示 + source-contract 门禁，同 vfs.os 范式） }
  for I := Low(NO_SEAM) to High(NO_SEAM) do
    AssertNoFsSeam(NO_SEAM[I], LoadSourceText(NO_SEAM[I]));
  { embed 已收敛至 L1 text.strings/text.char/text.conv 三单源（GlobMatch/IsAlpha/IntToStr 各归一、PChar 零拷贝 + inline，fs.glob 薄转发同源），不再构成 L2→L2 }
  Check(Pos('nextpas.core.text.strings', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.strings GlobMatch single source');
  Check(Pos('nextpas.core.text.char', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.char IsAlpha single source');
  Check(Pos('nextpas.core.text.conv', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares text.conv IntToStr single source');
  Check(not FindUsesUnit(LoadSourceText('src/nextpas.core.respack.embed.pas'), 'nextpas.core.fs'),
    'embed must not reference fs (L1 single source, uses graph)');
  Check(Pos('nextpas.core.respack.dirsource', LoadSourceText('src/nextpas.core.respack.embed.pas')) = 0,
    'embed must not reference dirsource (L1→L2 up-dependency fix, pure memory)');
  Check(Pos('nextpas.core.respack.writer', LoadSourceText('src/nextpas.core.respack.embed.pas')) = 0,
    'embed must not reference writer (pure memory)');
  Check(Pos('BytesCopy', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed reuses bytes.ops BytesCopy single source (WriteStr via BytesCopy, not Move)');
  Check(Pos('Move(PAnsiChar', LoadSourceText('src/nextpas.core.respack.embed.pas')) = 0,
    'embed must not use bare Move(PAnsiChar) (use BytesCopy)');
  Check(Pos('RESPACK_INC_MAX_BLOB_BYTES', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed has threshold constant RESPACK_INC_MAX_BLOB_BYTES (4MiB early reject)');
  Check(Pos('ResPackValidIdent', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares ResPackValidIdent');
  // design-conventions §2 inline redline 2: loop body must not be inline — ValidIdent contains for loop, must NOT be inline
  Check(Pos('function ResPackValidIdent(const AName: string): Boolean; inline', LoadSourceText('src/nextpas.core.respack.embed.pas')) = 0,
    'embed ResPackValidIdent must NOT be inline (loop body, I-Cache)');
  // capacity sizing must not be inline: nested inline var-param chain miscompiles
  // under FPC trunk -O2 REGVAR (stale Cap yields empty buffer and nil cursor)
  Check(Pos('CalcIncCapacity', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares CalcIncCapacity capacity single source');
  Check(Pos('CalcIncCapacity(const AName, ANStr: string; const APerLine: Integer; const AN: SizeUInt): SizeUInt; inline', LoadSourceText('src/nextpas.core.respack.embed.pas')) = 0,
    'embed CalcIncCapacity must NOT be inline (nested inline var-param REGVAR hazard)');
  Check(Pos('nextpas.core.bytes.ops', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares bytes.ops single source');
  Check(Pos('nextpas.core.embed.limits', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed declares embed.limits independent threshold single source (L1, respack.limits is forwarding)');
  Check(Pos('ResPackRequireIncSize', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed reuses ResPackRequireIncSize threshold single source');
  Check(Pos('ResPackEffectiveIncLimit', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed reuses ResPackEffectiveIncLimit configurable limit');
  Check(Pos('BytesConcatMany', LoadSourceText('src/nextpas.core.respack.embed.pas')) = 0,
    'embed must not use BytesConcatMany (unify to BytesCopy single source)');
  Check(Pos('MaxBlobBytes', LoadSourceText('src/nextpas.core.respack.embed.pas')) > 0,
    'embed exposes MaxBlobBytes configurable limit');
  { 独立策略模块门禁：embed.limits 为 L1 单源，供其他载体复用，respack.limits 仅兼容转发 }
  Check(Pos('EMBED_INC_MAX_BLOB_BYTES', LoadSourceText('src/nextpas.core.embed.limits.pas')) > 0,
    'embed.limits declares EMBED_INC_MAX_BLOB_BYTES independent strategy');
  Check(Pos('EmbedRequireIncSize', LoadSourceText('src/nextpas.core.embed.limits.pas')) > 0,
    'embed.limits declares EmbedRequireIncSize independent strategy');
  Check(Pos('EmbedEffectiveIncLimit', LoadSourceText('src/nextpas.core.embed.limits.pas')) > 0,
    'embed.limits declares EmbedEffectiveIncLimit');
  Check(not FindUsesUnit(LoadSourceText('src/nextpas.core.embed.limits.pas'), 'nextpas.core.fs'),
    'embed.limits must not reference fs (L1 pure, uses graph)');
  Check(not FindUsesUnit(LoadSourceText('src/nextpas.core.embed.limits.pas'), 'nextpas.core.io.mapped'),
    'embed.limits must not reference io.mapped (L1 pure)');
  Check(Pos('nextpas.core.base', LoadSourceText('src/nextpas.core.embed.limits.pas')) > 0,
    'embed.limits declares base single source');
  Check(Pos('nextpas.core.exception', LoadSourceText('src/nextpas.core.embed.limits.pas')) > 0,
    'embed.limits declares exception root');
  Check(Pos('inline', LoadSourceText('src/nextpas.core.embed.limits.pas')) > 0,
    'embed.limits inline zero-copy evidence');
  Check(Pos('nextpas.core.embed.limits', LoadSourceText('src/nextpas.core.respack.limits.pas')) > 0,
    'respack.limits forwards to embed.limits independent module');
  Check(Pos('inline', LoadSourceText('src/nextpas.core.respack.limits.pas')) > 0,
    'respack.limits inline forwarding evidence');
  Check(Pos('nextpas.core.embed.limits', LoadSourceText('src/nextpas.core.embed.pas')) > 0,
    'embed facade declares embed.limits');
  Check(Pos('inline', LoadSourceText('src/nextpas.core.embed.pas')) > 0,
    'embed facade inline evidence');

  { 正向断言：seam 单元确实声明了 fs+io.mapped 依赖（防白名单失效漂移，uses graph 校验） }
  Src := LoadSourceText('src/nextpas.core.respack.dirsource.pas');
  Check(FindUsesUnit(Src, 'nextpas.core.fs'), 'dirsource declares fs dependency (uses graph)');
  Check(FindUsesUnit(Src, 'nextpas.core.io.mapped'), 'dirsource declares io.mapped mmap dependency (uses graph)');
  Check(Pos('nextpas.core.bytes.ops', Src) > 0, 'dirsource declares bytes.ops BytesCopy single source');
  Check(Pos('BytesCopy', Src) > 0, 'dirsource reuses BytesCopy single source (no bare Move)');
  Check(Pos('ResPackEmbedBuild', Src) > 0, 'dirsource hosts ResPackEmbedBuild (IO seam, embed is pure)');
  Check(Pos('nextpas.core.text.strings', Src) > 0, 'dirsource declares text.strings GlobMatch single source (embed pipeline)');
  Check(Pos('GlobMatch', Src) > 0, 'dirsource reuses GlobMatch single source');
  Check(Pos('RelativizePath', Src) > 0, 'dirsource single RelativizePath via PathStripPrefix');
  Check(Pos('FilterRelPath', Src) > 0, 'dirsource DRY FilterRelPath pipeline');
  Check(Pos('TryReserveTotal', Src) > 0, 'dirsource DRY TryReserveTotal/TryAddSizeUInt single source');
  Check(Pos('EnsureStreamCapacity', Src) > 0, 'dirsource DRY EnsureStreamCapacity');
  Check(Pos('EnsureEmbedCapacity', Src) > 0, 'dirsource DRY EnsureEmbedCapacity');
  Check(Pos('ResPackEntriesFromDir', Src) > 0, 'dirsource ResPackEntriesFromDir small-pack guidance');
  Check(Pos('RESPACK_DIRSOURCE_LEGACY_LIMIT', Src) > 0, 'dirsource extracts 64MiB to RESPACK_DIRSOURCE_LEGACY_LIMIT (no magic)');
  Check(Pos('SizeUInt(64) * 1024 * 1024', Src) = 0, 'dirsource must not have bare 64MiB magic (use constant)');
  Check(Pos('TWalkCtx', Src) > 0, 'dirsource generic TWalkCtx<T> templated context single source');
  Check(Pos('EnsureWalkCapacity', Src) > 0, 'dirsource generic EnsureWalkCapacity<T> single source');
  Check(Pos('WalkPrePlain', Src) > 0, 'dirsource generic WalkPrePlain single source');
  Check(Pos('WalkPreEmbed', Src) > 0, 'dirsource generic WalkPreEmbed single source');
  Check(Pos('generic', Src) > 0, 'dirsource uses generics for Walk templating');
  { 依赖白名单：reader/writer 仅依赖 base/bytes；唯一 fs 缝隙已锁定（uses graph 校验） }
  Src := LoadSourceText('src/nextpas.core.respack.base.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'base must not reference fs (uses graph)');
  Check(Pos('RESPACK_DIRSOURCE_LEGACY_LIMIT', Src) > 0, 'base declares RESPACK_DIRSOURCE_LEGACY_LIMIT family with RESPACK_MAX_INPUT_BYTES');
  Check(Pos('RESPACK_MAX_INPUT_BYTES', Src) > 0, 'base declares RESPACK_MAX_INPUT_BYTES');
  Check(Pos('64) * 1024 * 1024', Src) > 0, 'base defines 64MiB legacy limit inline zero-copy');
  Src := LoadSourceText('src/nextpas.core.respack.reader.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'reader must not reference fs (uses graph)');
  Src := LoadSourceText('src/nextpas.core.respack.writer.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'writer must not reference fs (uses graph)');
  Src := LoadSourceText('src/nextpas.core.respack.writer.layout.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'writer.layout must not reference fs (uses graph)');
  Check(Pos('nextpas.core.bytes.ops', Src) > 0, 'writer.layout declares bytes.ops single source');
  Check(Pos('nextpas.core.collections.algorithms', Src) > 0, 'writer.layout declares collections.algorithms Sort single source');
  Check(Pos('nextpas.core.mem.base', Src) > 0, 'writer.layout declares mem.base AlignUp64 single source');
  Check(Pos('ResPackCmpPath', Src) > 0, 'writer.layout reuses bytes.ops ResPackCmpPath inline zero-copy');
  Src := LoadSourceText('src/nextpas.core.respack.writer.builder.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'writer.builder must not reference fs (uses graph)');
  Check(Pos('nextpas.core.bytes.ops', Src) > 0, 'writer.builder declares bytes.ops single source');
  Src := LoadSourceText('src/nextpas.core.respack.writer.stream.pas');
  Check(not FindUsesUnit(Src, 'nextpas.core.fs'), 'writer.stream must not reference fs (uses graph)');
  Check(Pos('nextpas.core.bytes.ops', Src) > 0, 'writer.stream declares bytes.ops single source');
  Check(Pos('nextpas.core.respack.writer.layout', Src) > 0, 'writer.stream reuses writer.layout single source');
  Check(Pos('ResPackLayoutClear', Src) > 0, 'writer.stream try..finally ResPackLayoutClear not leak');
  Check((Pos('TBytes', Src) > 0) and (Pos('SetLength(HeadBuf', Src) > 0), 'writer.stream Head TBytes RAII托管 SetLength');
  Check(Pos('GetMem(Head', Src) = 0, 'writer.stream no manual GetMem(Head) (RAII托管)');
  Check(Pos('FreeMem(Head', Src) = 0, 'writer.stream no manual FreeMem(Head) (RAII托管)');
  Check(Pos('try', Src) > 0, 'writer.stream has try..finally stability');
  Check(Pos('inline', Src) > 0, 'writer.stream inline zero-copy evidence');
  Check(Pos('WriteZeros', Src) > 0, 'writer.stream WriteZeros inline fast-path');
  Check(Pos('BYTES_ZERO_PAGE', Src) > 0, 'writer.stream reuses bytes.ops BYTES_ZERO_PAGE single source');
  Src := LoadSourceText('src/nextpas.core.respack.pas');
  Check(Pos('RESPACK_DIRSOURCE_LEGACY_LIMIT', Src) > 0, 'facade re-exports RESPACK_DIRSOURCE_LEGACY_LIMIT family');
  Check(Pos('RESPACK_MAX_INPUT_BYTES', Src) > 0, 'facade re-exports RESPACK_MAX_INPUT_BYTES');
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
