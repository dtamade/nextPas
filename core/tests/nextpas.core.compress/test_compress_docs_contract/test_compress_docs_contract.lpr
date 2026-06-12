program test_compress_docs_contract;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing;

var
  T: TTestRunner;

function ReadText(const ARelativePath: string): string;
var
  LPath: string;
  LLines: TStringList;
begin
  LPath := ExpandFileName('../../../' + ARelativePath);
  Check(FileExists(LPath), 'source file exists: ' + LPath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LPath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function LowerText(const AText: string): string;
begin
  Result := LowerCase(AText);
end;

function CountLines(const AText: string): SizeInt;
var
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    Result := LLines.Count;
  finally
    LLines.Free;
  end;
end;

function CountOccurrences(const ASource, AToken: string): SizeInt;
var
  LOffset, LFound: SizeInt;
begin
  Result := 0;
  LOffset := 1;
  while LOffset <= Length(ASource) do
  begin
    LFound := Pos(AToken, Copy(ASource, LOffset, MaxInt));
    if LFound = 0 then
      Break;
    Inc(Result);
    Inc(LOffset, LFound + Length(AToken) - 1);
  end;
end;

function CompareGoDirectoryHasNoTestFiles: Boolean;
var
  LSearch: TSearchRec;
  LPath: string;
  LFound: Boolean;
begin
  LPath := ExpandFileName(
    '../../../benchmarks/nextpas.core.compress/bench_compress/compare_go');
  Check(DirectoryExists(LPath), 'Go comparator directory exists: ' + LPath);
  LFound := FindFirst(IncludeTrailingPathDelimiter(LPath) + '*_test.go',
    faAnyFile, LSearch) = 0;
  try
    Result := not LFound;
  finally
    if LFound then
      FindClose(LSearch);
  end;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckBefore(const ASource, AFirstToken, ASecondToken, AMessage: string);
var
  LFirst, LSecond: SizeInt;
begin
  LFirst := Pos(AFirstToken, ASource);
  LSecond := Pos(ASecondToken, ASource);
  Check((LFirst > 0) and (LSecond > 0) and (LFirst < LSecond),
    AMessage + ': ' + AFirstToken + ' before ' + ASecondToken);
end;

function SliceFrom(const ASource, AStartToken: string): string;
var
  LStart: SizeInt;
begin
  LStart := Pos(AStartToken, ASource);
  Check(LStart > 0, 'source slice start exists: ' + AStartToken);
  if LStart = 0 then
    Exit('');
  Result := Copy(ASource, LStart, MaxInt);
end;

function SliceBetween(const ASource, AStartToken, AEndToken: string): string;
var
  LStart, LEnd: SizeInt;
begin
  LStart := Pos(AStartToken, ASource);
  Check(LStart > 0, 'source slice start exists: ' + AStartToken);
  if LStart = 0 then
    Exit('');

  LEnd := Pos(AEndToken, Copy(ASource, LStart + Length(AStartToken), MaxInt));
  Check(LEnd > 0, 'source slice end exists: ' + AEndToken);
  if LEnd = 0 then
    Exit(Copy(ASource, LStart, MaxInt));

  Result := Copy(ASource, LStart, Length(AStartToken) + LEnd - 1);
end;

function RightTrimSpaces(const AText: string): string;
var
  LEnd: SizeInt;
begin
  LEnd := Length(AText);
  while (LEnd > 0) and (AText[LEnd] <= ' ') do
    Dec(LEnd);
  Result := Copy(AText, 1, LEnd);
end;

procedure AddUniqueToken(const ATokens: TStrings; const AToken: string);
begin
  if (AToken <> '') and (ATokens.IndexOf(AToken) < 0) then
    ATokens.Add(AToken);
end;

procedure AddWhitespaceTokens(const AText: string; const ATokens: TStrings);
var
  LIndex, LStart: SizeInt;
begin
  LIndex := 1;
  while LIndex <= Length(AText) do
  begin
    while (LIndex <= Length(AText)) and (AText[LIndex] <= ' ') do
      Inc(LIndex);
    LStart := LIndex;
    while (LIndex <= Length(AText)) and (AText[LIndex] > ' ') do
      Inc(LIndex);
    if LStart < LIndex then
      AddUniqueToken(ATokens, Copy(AText, LStart, LIndex - LStart));
  end;
end;

function LineHasContinuation(var ALine: string): Boolean;
begin
  ALine := RightTrimSpaces(ALine);
  Result := (Length(ALine) > 0) and (ALine[Length(ALine)] = '\');
  if Result then
    Delete(ALine, Length(ALine), 1);
end;

procedure CollectMakefileTargetPrerequisites(const AMakefile, ATarget: string;
  const APrerequisites: TStrings);
var
  LLines: TStringList;
  LTargets: TStringList;
  LRawLine, LLine, LLogicalLine, LLeft, LRight: string;
  LColon, LEqual, LComment, LI: SizeInt;
  LContinues: Boolean;
begin
  LLogicalLine := '';
  LLines := TStringList.Create;
  LTargets := TStringList.Create;
  try
    LLines.Text := AMakefile;
    for LI := 0 to LLines.Count - 1 do
    begin
      LRawLine := LLines[LI];
      if (Length(LRawLine) > 0) and (LRawLine[1] = #9) then
        Continue;

      if LLogicalLine = '' then
        LLine := LRawLine
      else
        LLine := LLogicalLine + ' ' + Trim(LRawLine);

      LContinues := LineHasContinuation(LLine);
      if LContinues then
      begin
        LLogicalLine := LLine;
        Continue;
      end;
      LLogicalLine := '';

      LLine := Trim(LLine);
      if (LLine = '') or (LLine[1] = '#') then
        Continue;
      LComment := Pos('#', LLine);
      if LComment > 0 then
        LLine := Trim(Copy(LLine, 1, LComment - 1));

      LColon := Pos(':', LLine);
      if LColon = 0 then
        Continue;
      LEqual := Pos('=', LLine);
      if (LEqual > 0) and (LEqual < LColon) then
        Continue;

      LLeft := Trim(Copy(LLine, 1, LColon - 1));
      LRight := Trim(Copy(LLine, LColon + 1, MaxInt));
      LTargets.Clear;
      AddWhitespaceTokens(LLeft, LTargets);
      if LTargets.IndexOf(ATarget) >= 0 then
        AddWhitespaceTokens(LRight, APrerequisites);
    end;
  finally
    LTargets.Free;
    LLines.Free;
  end;
end;

function MakefileTargetPrerequisitesExactly(const AMakefile, ATarget: string;
  const AExpected: array of string): Boolean;
var
  LActual: TStringList;
  LI: SizeInt;
begin
  Result := False;
  LActual := TStringList.Create;
  try
    CollectMakefileTargetPrerequisites(AMakefile, ATarget, LActual);
    if LActual.Count <> Length(AExpected) then
      Exit;
    for LI := Low(AExpected) to High(AExpected) do
      if LActual.IndexOf(AExpected[LI]) < 0 then
        Exit;
    Result := True;
  finally
    LActual.Free;
  end;
end;

procedure CheckMakefileTargetPrerequisitesExactly(const AMakefile,
  ATarget: string; const AExpected: array of string; const AMessage: string);
var
  LActual: TStringList;
  LExpected: TStringList;
  LI: SizeInt;
begin
  LActual := TStringList.Create;
  LExpected := TStringList.Create;
  try
    CollectMakefileTargetPrerequisites(AMakefile, ATarget, LActual);
    for LI := Low(AExpected) to High(AExpected) do
      AddUniqueToken(LExpected, AExpected[LI]);

    CheckEqual(Int64(LExpected.Count), Int64(LActual.Count),
      AMessage + ' count for ' + ATarget);
    for LI := 0 to LExpected.Count - 1 do
      Check(LActual.IndexOf(LExpected[LI]) >= 0,
        AMessage + ' includes ' + ATarget + ':' + LExpected[LI]);
    for LI := 0 to LActual.Count - 1 do
      Check(LExpected.IndexOf(LActual[LI]) >= 0,
        AMessage + ' excludes unexpected ' + ATarget + ':' + LActual[LI]);
  finally
    LExpected.Free;
    LActual.Free;
  end;
end;

procedure CheckMakefileTargetPrerequisiteAbsent(const AMakefile, ATarget,
  APrerequisite, AMessage: string);
var
  LActual: TStringList;
begin
  LActual := TStringList.Create;
  try
    CollectMakefileTargetPrerequisites(AMakefile, ATarget, LActual);
    Check(LActual.IndexOf(APrerequisite) < 0,
      AMessage + ': ' + ATarget + ':' + APrerequisite);
  finally
    LActual.Free;
  end;
end;

function AuditMakefilePrerequisitesAreValid(const AMakefile: string): Boolean;
begin
  Result :=
    MakefileTargetPrerequisitesExactly(AMakefile, 'test',
      ['run', 'native-compile', 'zlib-native-compile', 'benchmark-compile',
       'go-comparator-compile', 'example-run', 'example-native-compile',
       'heaptrc',
       'docs-contract-run', 'basic-test-run', 'deep-test-run']) and
    MakefileTargetPrerequisitesExactly(AMakefile, 'audit-gate', ['test']);
end;

procedure CheckAuditTestPrerequisites(const AMakefile, AMessage: string);
begin
  CheckMakefileTargetPrerequisitesExactly(AMakefile, 'test',
    ['run', 'native-compile', 'zlib-native-compile', 'benchmark-compile',
     'go-comparator-compile', 'example-run', 'example-native-compile',
     'heaptrc',
     'docs-contract-run', 'basic-test-run', 'deep-test-run'], AMessage);
  CheckMakefileTargetPrerequisitesExactly(AMakefile, 'audit-gate', ['test'],
    AMessage);
  CheckMakefileTargetPrerequisiteAbsent(AMakefile, 'test', 'native-runtime',
    AMessage + ' keeps native LZ4 runtime optional');
  CheckMakefileTargetPrerequisiteAbsent(AMakefile, 'test',
    'zlib-native-runtime', AMessage + ' keeps native zlib runtime optional');
  CheckMakefileTargetPrerequisiteAbsent(AMakefile, 'test',
    'go-comparator-run', AMessage + ' keeps Go comparator runtime optional');
end;

procedure TestAuditMakefileTargetPrerequisiteParserRejectsOptionalRuntime;
var
  LMakefile: string;
begin
  LMakefile :=
    'test: run native-compile zlib-native-compile benchmark-compile ' +
    'go-comparator-compile example-run example-native-compile ' +
    'heaptrc docs-contract-run ' +
    'go-comparator-run' + LineEnding +
    'audit-gate: test' + LineEnding +
    'go-comparator-run:' + LineEnding +
    #9 + '@printf ''compress-go-comparator-run=pass\n''' + LineEnding;

  Check(not AuditMakefilePrerequisitesAreValid(LMakefile),
    'parser rejects optional runtime target in audit test prerequisites');
end;

procedure TestAuditMakefileTargetPrerequisitesMatchGatePolicy;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');
  CheckAuditTestPrerequisites(LMakefile,
    'audit Makefile target prerequisites match gate policy');
end;

procedure TestCompressionLevelDocsMatchSource;
var
  LReadme: string;
  LBase: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LBase := ReadText('src/nextpas.core.compress.base.pas');

  CheckContains(LBase, 'clFastest', 'source exposes current fastest level');
  CheckContains(LBase, 'clBest', 'source exposes current best level');
  CheckContains(LReadme, '`clFastest`', 'docs list current fastest level');
  CheckContains(LReadme, '`clBest`', 'docs list current best level');
  CheckAbsent(LReadme, 'clBestSpeed', 'docs omit removed best-speed level');
  CheckAbsent(LReadme, 'clBestCompression',
    'docs omit removed best-compression level');
end;

procedure TestFacadeExampleDocsMatchCurrentApi;
var
  LDesign: string;
  LFacade: string;
begin
  LDesign := ReadText('docs/design-conventions.md');
  LFacade := ReadText('src/nextpas.core.compress.pas');

  CheckContains(LFacade, 'function GzipCompress',
    'compress facade exposes current gzip compress API');
  CheckContains(LDesign, 'nextpas.core.compress.GzipCompress(Data)',
    'design conventions use current gzip facade example');
  CheckAbsent(LDesign, 'GzipEncode',
    'design conventions must not mention removed gzip encode API');
  CheckAbsent(LDesign, 'GzipDecode',
    'design conventions must not mention removed gzip decode API');
end;

procedure TestRunnableCompressExampleDocsMatchFiles;
var
  LReadme: string;
  LExample: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LExample := ReadText(
    'examples/nextpas.core.compress/compress_roundtrip/compress_roundtrip.lpr');

  CheckContains(LReadme,
    '../../examples/nextpas.core.compress/compress_roundtrip/compress_roundtrip.lpr',
    'compress docs link runnable roundtrip example');
  CheckContains(LReadme,
    '../../examples/nextpas.core.compress/compress_roundtrip/Makefile',
    'compress docs link runnable roundtrip example Makefile');
  ReadText('examples/nextpas.core.compress/compress_roundtrip/Makefile');
  CheckContains(LExample, '  nextpas.core.compress',
    'compress example imports the root facade');
  CheckAbsent(LExample, 'nextpas.core.compress.deflate',
    'compress example must not bypass the root facade with deflate internals');
  CheckAbsent(LExample, 'nextpas.core.compress.gzip',
    'compress example must not bypass the root facade with gzip internals');
  CheckAbsent(LExample, 'nextpas.core.compress.lz4.ffi',
    'compress example must not bypass the root facade with native LZ4 FFI');
  CheckAbsent(LExample, 'nextpas.core.compress.lz4;',
    'compress example must not bypass the root facade with pure LZ4 internals');
end;

procedure TestSupportedFormatsTableMatchesFacade;
var
  LReadme: string;
  LFacade: string;
  LFormats: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LFacade := ReadText('src/nextpas.core.compress.pas');
  LFormats := SliceBetween(LReadme, '## Supported Formats', '## API');

  CheckContains(LFormats,
    '| Deflate | Yes      | Yes        | Yes       | zlib-wrapped Deflate stream (RFC 1950) |',
    'docs supported-format table states Deflate streaming support');
  CheckContains(LFormats,
    '| Gzip    | Yes      | Yes        | Yes       | Gzip wrapper (RFC 1952) |',
    'docs supported-format table states Gzip streaming support');
  CheckContains(LFormats,
    '| LZ4     | Yes      | Yes        | No        | Block format, optional native FFI |',
    'docs supported-format table states LZ4 is one-shot only');
  CheckContains(LFacade, 'function DeflateWriter',
    'facade exposes Deflate streaming writer');
  CheckContains(LFacade, 'function DeflateReader',
    'facade exposes Deflate streaming reader');
  CheckContains(LFacade, 'function GzipWriter',
    'facade exposes Gzip streaming writer');
  CheckContains(LFacade, 'function GzipReader',
    'facade exposes Gzip streaming reader');
  CheckAbsent(LFacade, 'function Lz4Writer',
    'facade must not expose unsupported LZ4 streaming writer');
  CheckAbsent(LFacade, 'function Lz4Reader',
    'facade must not expose unsupported LZ4 streaming reader');
end;

procedure TestDeflateFormatDocsMatchSource;
var
  LReadme: string;
  LReadmeLower: string;
  LDeflateLower: string;
  LGoBench: string;
  LGoBenchLower: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LReadmeLower := LowerText(LReadme);
  LDeflateLower := LowerText(ReadText('src/nextpas.core.compress.deflate.pas'));
  LGoBench := ReadText(
    'benchmarks/nextpas.core.compress/bench_compress/compare_go/main.go');
  LGoBenchLower := LowerText(LGoBench);

  CheckContains(LDeflateLower, 'compress2(',
    'one-shot Deflate source uses zlib wrapper API');
  CheckContains(LDeflateLower, 'inflateinit(lstream',
    'one-shot Deflate source uses zlib wrapper API for decode');
  CheckContains(LDeflateLower, 'lstream.avail_in <> 0',
    'one-shot Deflate decode rejects trailing input');
  CheckContains(LDeflateLower, 'deflateinit(fstream',
    'streaming Deflate writer uses zlib-wrapped init');
  CheckContains(LDeflateLower, 'inflateinit(fstream',
    'streaming Deflate reader uses zlib-wrapped init');
  CheckAbsent(LDeflateLower, 'deflateinit2(fstream, alevel, z_deflated, -15',
    'streaming Deflate must not silently switch to raw mode');

  CheckAbsent(LReadmeLower, 'raw deflate',
    'docs must not claim raw Deflate output');
  CheckAbsent(LReadmeLower, 'rfc 1951',
    'docs must not cite raw Deflate as current output format');
  CheckContains(LReadme, 'zlib-wrapped Deflate stream',
    'docs describe current Deflate format');
  CheckContains(LReadme, 'RFC 1950',
    'docs cite the zlib wrapper format standard');

  CheckContains(LGoBench, '"compress/zlib"',
    'Go Deflate comparator uses zlib wrapper package');
  CheckContains(LGoBench, 'zlib.NewWriter',
    'Go Deflate comparator compresses zlib-wrapped streams');
  CheckContains(LGoBench, 'zlib.NewReader',
    'Go Deflate comparator decompresses zlib-wrapped streams');
  CheckAbsent(LGoBenchLower, '"compress/flate"',
    'Go Deflate comparator must not benchmark raw RFC1951 streams');
  CheckAbsent(LGoBenchLower, 'flate.newwriter',
    'Go Deflate comparator must not write raw Deflate streams');
  CheckAbsent(LGoBenchLower, 'flate.newreader',
    'Go Deflate comparator must not read raw Deflate streams');
end;

procedure TestDeflateInteropNoteMatchesSource;
var
  LDeep: string;
  LDeepLower: string;
  LAudit: string;
begin
  LDeep := ReadText(
    'tests/nextpas.core.compress/test_compress_deep/test_compress_deep.lpr');
  LDeepLower := LowerText(LDeep);
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckAbsent(LDeepLower, 'deflatewriter uses raw deflate',
    'deep test comment must not preserve stale raw Deflate note');
  CheckAbsent(LDeepLower, 'not interchangeable',
    'deep test comment must not preserve stale interop warning');
  CheckContains(LDeep,
    'one-shot and streaming Deflate paths both use zlib-wrapped streams',
    'deep test comment documents current one-shot and streaming contract');
  CheckContains(LAudit, 'TestDeflateCrossApiRoundTrip',
    'audit test names Deflate one-shot and streaming cross-API roundtrip');
  CheckContains(LAudit, 'Deflate cross-API roundtrip',
    'audit gate registers Deflate one-shot and streaming cross-API roundtrip');
end;

procedure TestGzipCrossApiAuditContract;
var
  LAudit: string;
begin
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LAudit, 'TestGzipCrossApiRoundTrip',
    'audit test names Gzip one-shot and streaming cross-API roundtrip');
  CheckContains(LAudit, 'Gzip cross-API roundtrip',
    'audit gate registers Gzip one-shot and streaming cross-API roundtrip');
end;

procedure TestBoundedDeflateDocsMatchSurface;
var
  LReadme: string;
  LDeflate: string;
  LFacade: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LFacade := ReadText('src/nextpas.core.compress.pas');

  CheckContains(LDeflate, 'function DeflateDecompressWithMaxOutputSize',
    'deflate subunit exposes bounded helper');
  CheckContains(LDeflate, 'function CreateDeflateReaderWithMaxOutputSize',
    'deflate subunit exposes bounded streaming helper');
  CheckContains(LReadme, 'DeflateDecompressWithMaxOutputSize',
    'docs name bounded helper');
  CheckContains(LReadme, 'DeflateReaderWithMaxOutputSize',
    'docs name bounded streaming helper');
  CheckContains(LReadme, 'uses nextpas.core.compress;',
    'docs show bounded helper root facade import');
  CheckAbsent(LReadme, 'not re-exported by the root `nextpas.core.compress` facade',
    'docs must not preserve stale bounded helper facade boundary');
  CheckContains(LFacade, 'function DeflateDecompressWithMaxOutputSize',
    'root facade exposes bounded deflate helper');
  CheckContains(LFacade, 'function DeflateReaderWithMaxOutputSize',
    'root facade exposes bounded deflate streaming helper');
  CheckContains(LFacade,
    'nextpas.core.compress.deflate.DeflateDecompressWithMaxOutputSize',
    'root facade forwards bounded deflate helper to deflate subunit');
  CheckContains(LFacade,
    'nextpas.core.compress.deflate.CreateDeflateReaderWithMaxOutputSize',
    'root facade forwards bounded deflate streaming helper to deflate subunit');
end;

procedure TestDeflateInvalidHeaderContractMatchesAudit;
var
  LReadme: string;
  LDeflate: string;
  LAudit: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LReadme, 'Deflate error model:',
    'docs name the stable Deflate error model');
  CheckContains(LReadme, '`deflate: invalid zlib header`',
    'docs list stable Deflate invalid-header error');
  CheckContains(LReadme, '`deflate: truncated stream`',
    'docs list stable Deflate truncated-stream error');
  CheckContains(LReadme, '`deflate: preset dictionary not supported`',
    'docs list stable Deflate preset-dictionary error');
  CheckContains(LReadme, '`deflate: trailing bytes after stream`',
    'docs list stable Deflate trailing-bytes error');
  CheckContains(LReadme, '`deflate: corrupt stream`',
    'docs list stable Deflate corrupt-stream error');
  CheckContains(LDeflate, 'IsInvalidZlibHeader',
    'deflate source owns zlib header validation helper');
  CheckContains(LDeflate, '((AFirst and $0F) <> Z_DEFLATED)',
    'deflate invalid-header helper checks compression method');
  CheckContains(LDeflate, '((AFirst shr 4) > 7)',
    'deflate invalid-header helper checks window size');
  CheckContains(LDeflate, '((LHeader mod 31) <> 0)',
    'deflate invalid-header helper checks header check bits');
  CheckContains(LDeflate, 'deflate: invalid zlib header',
    'deflate source exposes stable invalid-header error');
  CheckContains(LDeflate, 'if Length(AData) < 2 then',
    'deflate source classifies short one-shot zlib headers');
  CheckContains(LDeflate, 'deflate: truncated stream',
    'deflate source exposes stable truncated-stream error');
  CheckContains(LDeflate, 'deflate: preset dictionary not supported',
    'deflate source exposes stable preset-dictionary error');
  CheckContains(LDeflate, 'deflate: trailing bytes after stream',
    'deflate source exposes stable trailing-bytes error');
  CheckContains(LDeflate, 'deflate: corrupt stream',
    'deflate source exposes stable corrupt-stream error');
  CheckContains(LAudit, 'TestDeflateInvalidZlibHeaderErrorModel',
    'audit test names invalid zlib header error contract');
  CheckContains(LAudit, 'bad compression method',
    'audit locks invalid zlib header bad compression method branch');
  CheckContains(LAudit, 'bad window size',
    'audit locks invalid zlib header bad window size branch');
  CheckContains(LAudit, 'bad header check bits',
    'audit locks invalid zlib header check bits branch');
  CheckContains(LAudit, 'TestDeflateShortZlibHeaderErrorModel',
    'audit test names short zlib header error contract');
  CheckContains(LAudit, 'TestDeflateSplitZlibHeaderErrorModel',
    'audit test names split zlib header error contract');
  CheckContains(LAudit, 'TestDeflateCorruptPayloadErrorModel',
    'audit test names corrupt payload error contract');
  CheckContains(LAudit, 'TestDeflateChecksumOnlyCorruptionErrorModel',
    'audit test names checksum-only corruption error contract');
  CheckContains(LAudit, 'TestDeflatePresetDictionaryHeaderErrorModel',
    'audit test names preset dictionary error contract');
  CheckContains(LAudit, 'TestDeflateTrailingBytesLeavesReaderTerminal',
    'audit test names trailing bytes error contract');
  CheckContains(LAudit, 'Deflate invalid zlib header error model',
    'audit gate registers invalid zlib header error contract');
  CheckContains(LAudit, 'Deflate short zlib header error model',
    'audit gate registers short zlib header error contract');
  CheckContains(LAudit, 'Deflate split zlib header error model',
    'audit gate registers split zlib header error contract');
  CheckContains(LAudit, 'Deflate corrupt payload error model',
    'audit gate registers corrupt payload error contract');
  CheckContains(LAudit, 'Deflate checksum-only corruption error model',
    'audit gate registers checksum-only corruption error contract');
  CheckContains(LAudit, 'Deflate preset dictionary header error model',
    'audit gate registers preset dictionary error contract');
  CheckContains(LAudit, 'Deflate trailing bytes terminal reader',
    'audit gate registers trailing bytes error contract');
end;

procedure TestGzipErrorModelDocsMatchAudit;
var
  LReadme: string;
  LGzip: string;
  LAudit: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LReadme, 'Gzip error model:',
    'docs name the stable Gzip error model');
  CheckContains(LReadme, '`gzip: header too short`',
    'docs list stable Gzip short-header error');
  CheckContains(LReadme, '`gzip: invalid magic`',
    'docs list stable Gzip invalid-magic error');
  CheckContains(LReadme, '`gzip: unsupported method`',
    'docs list stable Gzip unsupported-method error');
  CheckContains(LReadme, '`gzip: invalid flags`',
    'docs list stable Gzip invalid-flags error');
  CheckContains(LReadme, '`gzip: truncated FEXTRA`',
    'docs list stable Gzip FEXTRA truncation error');
  CheckContains(LReadme, '`gzip: truncated FNAME`',
    'docs list stable Gzip FNAME truncation error');
  CheckContains(LReadme, '`gzip: truncated FCOMMENT`',
    'docs list stable Gzip FCOMMENT truncation error');
  CheckContains(LReadme, '`gzip: header field exceeds limit`',
    'docs list stable Gzip optional-header field limit error');
  CheckContains(LReadme, '`gzip: truncated header`',
    'docs list stable Gzip header-CRC truncation error');
  CheckContains(LReadme, '`gzip: header CRC mismatch`',
    'docs list stable Gzip header-CRC mismatch error');
  CheckContains(LReadme, '`gzip: truncated stream`',
    'docs list stable Gzip truncated-stream error');
  CheckContains(LReadme, '`gzip: truncated trailer`',
    'docs list stable Gzip truncated-trailer error');
  CheckContains(LReadme, '`gzip: trailing bytes after trailer`',
    'docs list stable Gzip trailing-bytes error');
  CheckContains(LReadme, '`gzip: corrupt stream`',
    'docs list stable Gzip corrupt-stream error');
  CheckContains(LReadme, '`gzip: CRC32 mismatch`',
    'docs list stable Gzip CRC error');
  CheckContains(LReadme, '`gzip: size mismatch`',
    'docs list stable Gzip size error');
  CheckContains(LReadme,
    'Concatenated gzip members use the same header, payload, trailer, and integrity error model as the first member',
    'docs state concatenated gzip members use the same error model');
  CheckContains(LReadme,
    'Bytes after a trailer that do not begin a complete gzip member remain `gzip: trailing bytes after trailer`; bytes that begin with gzip magic but truncate the fixed header are `gzip: header too short`',
    'docs state concatenated gzip member boundary error split');
  CheckContains(LGzip, 'gzip: header too short',
    'gzip source exposes stable short-header error');
  CheckContains(LGzip, 'gzip: invalid magic',
    'gzip source exposes stable invalid-magic error');
  CheckContains(LGzip, 'gzip: unsupported method',
    'gzip source exposes stable unsupported-method error');
  CheckContains(LGzip, 'gzip: invalid flags',
    'gzip source exposes stable invalid-flags error');
  CheckContains(LGzip, 'gzip: header CRC mismatch',
    'gzip source exposes stable header-CRC mismatch error');
  CheckContains(LGzip, 'gzip: truncated stream',
    'gzip source exposes stable truncated-stream error');
  CheckContains(LGzip, 'gzip: header field exceeds limit',
    'gzip source exposes stable optional-header field limit error');
  CheckContains(LGzip, 'gzip: truncated trailer',
    'gzip source exposes stable truncated-trailer error');
  CheckContains(LGzip, 'gzip: trailing bytes after trailer',
    'gzip source exposes stable trailing-bytes error');
  CheckContains(LGzip, 'gzip: corrupt stream',
    'gzip source exposes stable corrupt-stream error');
  CheckContains(LGzip, 'gzip: CRC32 mismatch',
    'gzip source exposes stable CRC error');
  CheckContains(LGzip, 'gzip: size mismatch',
    'gzip source exposes stable size error');
  CheckContains(LAudit, 'TestGzipTruncatedHeader',
    'audit test names gzip short-header contract');
  CheckContains(LAudit, 'TestGzipEmptyEncodedInputErrorModel',
    'audit test names gzip empty encoded input error model');
  CheckContains(LAudit, 'Gzip empty encoded input error model',
    'audit gate registers gzip empty encoded input error model');
  CheckContains(LAudit, 'gzip one-shot empty encoded input has stable error',
    'audit locks gzip one-shot empty encoded input error');
  CheckContains(LAudit, 'gzip bounded one-shot empty encoded input has stable error',
    'audit locks gzip bounded empty encoded input error');
  CheckContains(LAudit, 'gzip stream empty encoded input has stable error',
    'audit locks gzip stream empty encoded input error');
  CheckContains(LAudit, 'gzip bounded stream empty encoded input has stable error',
    'audit locks gzip bounded stream empty encoded input error');
  CheckContains(LAudit, 'GzipDecompress(nil)',
    'audit calls one-shot gzip empty encoded input path');
  CheckContains(LAudit, 'GzipDecompressWithMaxOutputSize(nil, 0)',
    'audit calls bounded gzip empty encoded input path');
  CheckContains(LAudit, 'GzipReader(CreateBytesStreamFrom(nil) as IReader)',
    'audit calls streaming gzip empty encoded input path');
  CheckContains(LAudit, 'GzipReaderWithMaxOutputSize(',
    'audit calls bounded streaming gzip empty encoded input path');
  CheckContains(LAudit, 'CreateBytesStreamFrom(nil) as IReader, 0',
    'audit uses zero cap for bounded streaming gzip empty encoded input path');
  CheckContains(LAudit, 'TestGzipFixedHeaderErrorModel',
    'audit test names gzip fixed-header contract');
  CheckContains(LAudit, 'Gzip fixed header error model',
    'audit gate registers gzip fixed-header contract');
  CheckContains(LAudit, 'TestGzipOptionalHeaderTruncationErrorModel',
    'audit test names gzip optional-header contract');
  CheckContains(LAudit, 'truncated FHCRC empty',
    'audit locks empty FHCRC truncation contract');
  CheckContains(LAudit, 'truncated FHCRC one byte',
    'audit locks one-byte FHCRC truncation contract');
  CheckContains(LAudit, 'TestGzipOptionalHeaderFieldLimit',
    'audit test names gzip optional-header field limit contract');
  CheckContains(LAudit, 'TestGzipCorruptPayloadErrorModel',
    'audit test names gzip corrupt-payload contract');
  CheckContains(LAudit, 'TestGzipRejectsTrailingBytesAfterTrailer',
    'audit test names gzip trailing-bytes contract');
  CheckContains(LAudit, 'TestGzipConcatenatedCorruptSecondMemberErrorModel',
    'audit test names gzip concatenated second-member error contract');
  CheckContains(LAudit, 'Gzip concatenated corrupt second member error model',
    'audit gate registers gzip concatenated second-member error contract');
  CheckContains(LAudit,
    'TestGzipConcatenatedTruncatedSecondMemberTrailerDeferredValidation',
    'audit test names gzip concatenated truncated second-member trailer contract');
  CheckContains(LAudit,
    'Gzip concatenated truncated second member trailer deferred validation',
    'audit gate registers gzip concatenated truncated second-member trailer contract');
  CheckContains(LAudit, 'TestGzipHeaderCrcRejected',
    'audit test names gzip header-CRC contract');
  CheckContains(LAudit, 'TestGzipOptionalHeaderAllFieldsRoundTrip',
    'audit test names gzip all-optional-header roundtrip contract');
  CheckContains(LAudit, 'Gzip optional header all fields roundtrip',
    'audit gate registers gzip all-optional-header roundtrip contract');
  CheckContains(LAudit, 'TestGzipWrongCRC',
    'audit test names gzip CRC contract');
  CheckContains(LAudit, 'gzip wrong CRC has stable error',
    'audit locks gzip CRC stable error contract');
  CheckContains(LAudit, 'TestGzipWrongSize',
    'audit test names gzip size contract');
  CheckContains(LAudit, 'gzip wrong size has stable error',
    'audit locks gzip size stable error contract');
  CheckContains(LAudit, 'TestGzipSingleMemberIntegrityBoundedParity',
    'audit test names gzip single-member bounded integrity parity');
  CheckContains(LAudit, 'Gzip single-member integrity bounded parity',
    'audit gate registers gzip single-member bounded integrity parity');
  CheckContains(LAudit, 'gzip bounded single-member CRC has stable error',
    'audit locks bounded gzip single-member CRC error');
  CheckContains(LAudit, 'gzip bounded single-member size has stable error',
    'audit locks bounded gzip single-member size error');
end;

procedure TestGzipOneShotZlibStateUsesFinally;
var
  LGzip: string;
  LCompress: string;
  LDecompress: string;
begin
  LGzip := LowerText(ReadText('src/nextpas.core.compress.gzip.pas'));
  LGzip := Copy(LGzip, Pos('implementation', LGzip), MaxInt);
  LCompress := SliceBetween(LGzip, 'function gzipcompress(',
    'function gzipdecompress(');
  LDecompress := SliceBetween(LGzip, 'function gzipdecompress(', 'end.');

  CheckContains(LCompress, 'try',
    'one-shot Gzip compress protects zlib state');
  CheckContains(LCompress, 'finally',
    'one-shot Gzip compress releases zlib state on all exits');
  CheckContains(LCompress, 'deflateend(lstream)',
    'one-shot Gzip compress ends zlib state');
  CheckContains(LDecompress, 'try',
    'one-shot Gzip decompress protects zlib state');
  CheckContains(LDecompress, 'finally',
    'one-shot Gzip decompress releases zlib state on all exits');
  CheckContains(LDecompress, 'inflateend(lstream)',
    'one-shot Gzip decompress ends zlib state');
end;

procedure TestGzipOneShotCompressionUsesBoundedAllocation;
var
  LGzip: string;
  LCompress: string;
begin
  LGzip := LowerText(ReadText('src/nextpas.core.compress.gzip.pas'));
  LGzip := Copy(LGzip, Pos('implementation', LGzip), MaxInt);
  LCompress := SliceBetween(LGzip, 'function gzipcompress(',
    'function gzipdecompress(');

  CheckContains(LCompress, 'compressbound(',
    'one-shot Gzip compress uses a zlib bound for output allocation');
  CheckAbsent(LCompress, 'setlength(lout, (loutlen + lhave) * 2)',
    'one-shot Gzip compress must not use unbounded dynamic output growth');
end;

procedure TestBoundedGzipDocsMatchSurface;
var
  LReadme: string;
  LGzip: string;
  LFacade: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LFacade := ReadText('src/nextpas.core.compress.pas');

  CheckContains(LGzip, 'function GzipDecompressWithMaxOutputSize',
    'gzip subunit exposes bounded helper');
  CheckContains(LGzip, 'function CreateGzipReaderWithMaxOutputSize',
    'gzip subunit exposes bounded streaming helper');
  CheckContains(LGzip, 'Result := GzipDecompressWithMaxOutputSize(AData, MAX_DECOMPRESS_SIZE)',
    'gzip default decode delegates to bounded helper');
  CheckAbsent(LGzip, 'if AMaxOutputSize = 0 then',
    'gzip bounded helper treats zero cap as an output limit');
  CheckContains(LGzip, 'FMemberOutputStart: SizeUInt;',
    'gzip streaming bounded reader tracks current member output start');
  CheckContains(LGzip, 'FMemberOutputStart := FOutputSize;',
    'gzip streaming bounded reader resets member output start per member');
  CheckContains(LGzip, 'SizeUInt(LExpectedSize) > FMaxOutputSize - FMemberOutputStart',
    'gzip streaming bounded reader rejects trailer size above remaining cap');
  CheckContains(LGzip, 'SizeUInt(LExpectedSize) > AMaxOutputSize - LMemberOutStart',
    'gzip bounded helper rejects trailer size above remaining cap');
  CheckContains(LGzip, 'LCapacity := AMaxOutputSize',
    'gzip bounded helper clamps allocation growth to caller cap');
  CheckContains(LReadme, 'GzipDecompressWithMaxOutputSize',
    'docs name bounded gzip helper');
  CheckContains(LReadme, 'GzipReaderWithMaxOutputSize',
    'docs name bounded gzip streaming helper');
  CheckContains(LReadme, 'uses nextpas.core.compress;',
    'docs show bounded gzip helper root facade import');
  CheckContains(LFacade, 'function GzipDecompressWithMaxOutputSize',
    'root facade exposes bounded gzip helper');
  CheckContains(LFacade, 'function GzipReaderWithMaxOutputSize',
    'root facade exposes bounded gzip streaming helper');
  CheckContains(LFacade,
    'nextpas.core.compress.gzip.GzipDecompressWithMaxOutputSize',
    'root facade forwards bounded gzip helper to gzip subunit');
  CheckContains(LFacade,
    'nextpas.core.compress.gzip.CreateGzipReaderWithMaxOutputSize',
    'root facade forwards bounded gzip streaming helper to gzip subunit');
end;

procedure TestBoundedOutputLimitErrorDocsMatchAudit;
var
  LReadme: string;
  LDeflate: string;
  LGzip: string;
  LAudit: string;
  LHighExpansionPartial: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');
  LHighExpansionPartial := SliceBetween(LAudit,
    'procedure TestBoundedHighExpansionPartialRemainingCapPreservesCallerTail;',
    'procedure TestBoundedHighExpansionFailureLoopReleasesState;');

  CheckContains(LReadme, '`deflate: decompressed size exceeds limit`',
    'docs list stable Deflate output-limit error');
  CheckContains(LReadme, '`gzip: decompressed size exceeds limit`',
    'docs list stable Gzip output-limit error');
  CheckContains(LDeflate, 'deflate: decompressed size exceeds limit',
    'Deflate source exposes stable output-limit error');
  CheckContains(LGzip, 'gzip: decompressed size exceeds limit',
    'Gzip source exposes stable output-limit error');
  CheckContains(LAudit, 'TestDeflateOutputLimitErrorModel',
    'audit test names Deflate output-limit error model');
  CheckContains(LAudit, 'Deflate output limit error model',
    'audit gate registers Deflate output-limit error model');
  CheckContains(LAudit, 'TestGzipOutputLimitErrorModel',
    'audit test names Gzip output-limit error model');
  CheckContains(LAudit, 'Gzip output limit error model',
    'audit gate registers Gzip output-limit error model');
  CheckContains(LAudit, 'TestGzipStreamingTrailerSizeAboveCapReportsOutputLimit',
    'audit test names Gzip streaming trailer-size cap contract');
  CheckContains(LAudit, 'Gzip streaming trailer size above cap reports output limit',
    'audit gate registers Gzip streaming trailer-size cap contract');
  CheckContains(LAudit,
    'TestGzipConcatenatedTrailerSizeAboveRemainingCapReportsOutputLimit',
    'audit test names Gzip concatenated trailer remaining-cap contract');
  CheckContains(LAudit,
    'Gzip concatenated trailer remaining cap output limit',
    'audit gate registers Gzip concatenated trailer remaining-cap contract');
  CheckContains(LAudit,
    'trailer size above remaining cap reports output limit',
    'audit locks Gzip remaining-cap trailer-size error priority');
  CheckContains(LAudit, 'TestStreamingReaderOutputLimitErrorModel',
    'audit test names streaming output-limit error model');
  CheckContains(LAudit, 'Streaming reader output limit error model',
    'audit gate registers streaming output-limit error model');
  CheckContains(LAudit, 'TestStreamingReaderOutputLimitIsCumulativeAcrossReads',
    'audit test names cumulative streaming output-limit error model');
  CheckContains(LAudit, 'Streaming reader output limit is cumulative across reads',
    'audit gate registers cumulative streaming output-limit error model');
  CheckContains(LAudit, 'TestBoundedReaderPartialRemainingCapPreservesCallerTail',
    'audit test names bounded reader partial remaining-cap caller-tail contract');
  CheckContains(LAudit, 'Bounded reader partial remaining cap preserves caller tail',
    'audit gate registers bounded reader partial remaining-cap caller-tail contract');
  CheckContains(LAudit, 'deflate bounded partial cap preserves caller tail',
    'audit locks Deflate bounded partial remaining-cap caller-tail preservation');
  CheckContains(LAudit, 'gzip bounded partial cap preserves caller tail',
    'audit locks Gzip bounded partial remaining-cap caller-tail preservation');
  CheckContains(LAudit, 'TestBoundedExactCapRejectsTrailingBytes',
    'audit test names bounded exact-cap trailing-byte contract');
  CheckContains(LAudit, 'Bounded exact cap rejects trailing bytes',
    'audit gate registers bounded exact-cap trailing-byte contract');
  CheckContains(LAudit, 'TestBoundedHighExpansionLimitPath',
    'audit test names bounded high-expansion limit path');
  CheckContains(LAudit, 'Bounded high-expansion limit path',
    'audit gate registers bounded high-expansion limit path');
  CheckContains(LAudit,
    'TestBoundedHighExpansionPartialRemainingCapPreservesCallerTail',
    'audit test names bounded high-expansion partial remaining-cap caller-tail contract');
  CheckContains(LAudit,
    'Bounded high-expansion partial cap preserves caller tail',
    'audit gate registers bounded high-expansion partial cap caller-tail contract');
  CheckContains(LAudit,
    'deflate high-expansion partial cap preserves caller tail',
    'audit locks Deflate high-expansion partial cap caller-tail preservation');
  CheckContains(LAudit,
    'gzip high-expansion partial cap preserves caller tail',
    'audit locks Gzip high-expansion partial cap caller-tail preservation');
  CheckContains(LAudit, 'deflate high-expansion partial cap second read',
    'audit locks Deflate high-expansion partial-cap second read size');
  CheckContains(LAudit, 'gzip high-expansion partial cap second read',
    'audit locks Gzip high-expansion partial-cap second read size');
  CheckContains(LHighExpansionPartial, 'DeflateReaderWithMaxOutputSize(',
    'high-expansion partial-cap test uses Deflate bounded streaming reader');
  CheckContains(LHighExpansionPartial, 'GzipReaderWithMaxOutputSize(',
    'high-expansion partial-cap test uses Gzip bounded streaming reader');
  CheckContains(LHighExpansionPartial, 'OutputCap + 1',
    'high-expansion partial-cap test leaves one byte of remaining cap');
  CheckContains(LHighExpansionPartial,
    'CheckEqual(Int64(1), Int64(LRead), ASecondReadLabel)',
    'high-expansion partial-cap test locks one-byte second read');
  CheckContains(LAudit, 'deflate high-expansion one-shot rejects above cap',
    'audit locks Deflate high-expansion one-shot limit path');
  CheckContains(LAudit, 'gzip high-expansion one-shot rejects above cap',
    'audit locks Gzip high-expansion one-shot limit path');
  CheckContains(LAudit, 'deflate high-expansion streaming rejects above cap',
    'audit locks Deflate high-expansion streaming limit path');
  CheckContains(LAudit, 'gzip high-expansion streaming rejects above cap',
    'audit locks Gzip high-expansion streaming limit path');
  CheckContains(LAudit, 'TestBoundedHighExpansionFailureLoopReleasesState',
    'audit test names bounded high-expansion cap failure loop');
  CheckContains(LAudit, 'Bounded high-expansion failure loop releases state',
    'audit gate registers bounded high-expansion cap failure loop');
  CheckContains(LAudit, 'deflate high-expansion one-shot cap failure loop',
    'audit locks Deflate one-shot cap failure loop');
  CheckContains(LAudit, 'gzip high-expansion one-shot cap failure loop',
    'audit locks Gzip one-shot cap failure loop');
  CheckContains(LAudit, 'deflate high-expansion streaming cap failure loop',
    'audit locks Deflate streaming cap failure loop');
  CheckContains(LAudit, 'gzip high-expansion streaming cap failure loop',
    'audit locks Gzip streaming cap failure loop');
  CheckContains(LAudit, 'deflate bounded reader exact cap reports trailing bytes',
    'audit locks Deflate exact-cap trailing-byte validation');
  CheckContains(LAudit, 'gzip bounded reader exact cap reports trailing bytes',
    'audit locks Gzip exact-cap trailing-byte validation');
  CheckContains(LAudit, 'deflate streaming reader enforces output cap',
    'audit locks Deflate streaming output-limit error model');
  CheckContains(LAudit, 'gzip streaming reader enforces output cap',
    'audit locks Gzip streaming output-limit error model');
  CheckContains(LAudit, 'DeflateWithCorruptPayloadAfterPartialOutput',
    'audit builds Deflate corrupt-payload partial-output fixture');
  CheckContains(LAudit,
    'deflate corrupt payload after partial output raises on next read',
    'audit locks Deflate corrupt-payload deferred-read contract');
end;

procedure TestGzipOptionalHeaderErrorsMatchAudit;
var
  LGzip: string;
  LAudit: string;
begin
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LGzip, 'gzip: truncated FEXTRA',
    'gzip source exposes stable FEXTRA truncation error');
  CheckContains(LGzip, 'gzip: truncated FNAME',
    'gzip source exposes stable FNAME truncation error');
  CheckContains(LGzip, 'gzip: truncated FCOMMENT',
    'gzip source exposes stable FCOMMENT truncation error');
  CheckContains(LGzip, 'gzip: header field exceeds limit',
    'gzip source exposes stable optional-header field limit error');
  CheckContains(LAudit, 'TestGzipOptionalHeaderTruncationErrorModel',
    'audit test names gzip optional-header error contract');
  CheckContains(LAudit, 'TestGzipOptionalHeaderFieldLimit',
    'audit test names gzip optional-header field limit contract');
  CheckContains(LAudit, 'Gzip optional header truncation error model',
    'audit gate registers gzip optional-header error contract');
  CheckContains(LAudit, 'truncated FHCRC empty',
    'audit locks empty FHCRC truncation under optional-header errors');
  CheckContains(LAudit, 'truncated FHCRC one byte',
    'audit locks one-byte FHCRC truncation under optional-header errors');
  CheckContains(LAudit, 'Gzip optional header field limit',
    'audit gate registers gzip optional-header field limit contract');
end;

procedure TestGzipTrailerBoundaryMatchesAudit;
var
  LGzip: string;
  LAudit: string;
begin
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckAbsent(LGzip, 'SizeUInt(Length(AData)) - 8',
    'gzip one-shot must not guess trailer at end-of-file');
  CheckContains(LGzip, 'LTrailerAvail := LStream.avail_in',
    'gzip one-shot reads trailer at zlib stream end');
  CheckContains(LGzip, 'gzip: truncated trailer',
    'gzip source exposes stable truncated-trailer error');
  CheckContains(LGzip, 'gzip: trailing bytes after trailer',
    'gzip source exposes stable after-trailer error');
  CheckContains(LAudit, 'gzip one-shot truncated trailer has stable error',
    'audit locks one-shot truncated trailer classification');
  CheckContains(LAudit, 'TBytes.Create($1F, $8B, $08)',
    'audit builds concatenated second-member fixed-header truncation fixture');
  CheckContains(LAudit, '''gzip: header too short'', ''truncated fixed header''',
    'audit locks concatenated second-member fixed-header classification');
  CheckContains(LAudit,
    'gzip concatenated second member fixed-header length matrix',
    'audit locks concatenated second-member fixed-header length matrix');
  CheckContains(LAudit,
    'single magic byte remains trailing bytes',
    'audit locks trailer garbage split before full gzip magic');
  CheckContains(LAudit,
    'TestGzipBoundedReaderConcatenatedTruncatedSecondMemberHeader',
    'audit test names bounded reader concatenated second-member truncation contract');
  CheckContains(LAudit,
    'Gzip bounded reader concatenated truncated second member header',
    'audit gate registers bounded reader concatenated second-member truncation contract');
  CheckContains(LAudit,
    'gzip bounded reader concatenated truncated second member header preserves caller byte',
    'audit locks bounded reader second-member truncation caller-buffer contract');
  CheckContains(LAudit, 'gzip one-shot rejects bytes after trailer',
    'audit locks one-shot after-trailer classification');
end;

procedure TestStreamingLifecycleDocsMatchContract;
var
  LReadme: string;
  LAudit: string;
  LDeep: string;
  LDeflate: string;
  LGzip: string;
  LFailedPayloadWrite: string;
  LRaisedSinkFailure: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');
  LDeep := ReadText(
    'tests/nextpas.core.compress/test_compress_deep/test_compress_deep.lpr');
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LFailedPayloadWrite := SliceBetween(LAudit,
    'procedure TestStreamingWriterFailedPayloadWriteLeavesTerminal;',
    'procedure TestStreamingWriterFailedFlushLeavesTerminal;');
  LRaisedSinkFailure := SliceBetween(LAudit,
    'procedure TestStreamingWriterRaisedSinkFailureLeavesTerminal;',
    'procedure TestStreamingWriterFailedFlushLeavesTerminal;');

  CheckContains(LReadme, 'Writer `Close` finalizes the compressed stream',
    'docs state streaming writer close finalizes format data');
  CheckContains(LReadme,
    'Writer `Flush` publishes a readable prefix and keeps the writer open for later `Write` calls',
    'docs state streaming writer flush continuation contract');
  CheckContains(LReadme, 'Writer `Close` is idempotent',
    'docs state streaming writer close is idempotent');
  CheckContains(LReadme, 'Writes after writer `Close` raise stable write-after-close errors',
    'docs state streaming writer after-close error contract');
  CheckContains(LReadme, 'Flush after successful writer `Close` raises stable flush-after-close errors',
    'docs state streaming writer flush-after-close error contract');
  CheckContains(LReadme, 'Reader `Close` is release-only',
    'docs state streaming reader close does not drain or validate');
  CheckContains(LReadme, 'Reader `Close` is idempotent',
    'docs state streaming reader close is idempotent');
  CheckContains(LReadme, 'Reads after reader `Close` return 0',
    'docs state streaming reader after-close contract');
  CheckContains(LReadme, 'Read to EOF to validate trailing bytes, CRC, and size',
    'docs state full streaming validation requires read-to-EOF');
  CheckContains(LReadme, 'Streaming factories reject nil readers and writers',
    'docs state streaming nil endpoint contract');
  CheckContains(LAudit, 'TestStreamingCloseLifecycleContract',
    'audit test names streaming close lifecycle contract');
  CheckContains(LAudit, 'Streaming close lifecycle contract',
    'audit gate registers streaming close lifecycle contract');
  CheckContains(LAudit, 'TestGzipEmptyStream',
    'audit test names gzip close-without-writes streaming contract');
  CheckContains(LAudit, 'Gzip empty stream',
    'audit gate registers gzip close-without-writes streaming contract');
  CheckContains(LAudit, 'TestStreamingWriterFailedCloseLeavesTerminal',
    'audit test names streaming failed-close terminal contract');
  CheckContains(LAudit, 'Streaming writer failed close leaves terminal',
    'audit gate registers streaming failed-close terminal contract');
  CheckContains(LAudit, 'TestStreamingWriterFlushPreservesContinuation',
    'audit test names streaming flush continuation contract');
  CheckContains(LAudit, 'Streaming writer flush preserves continuation',
    'audit gate registers streaming flush continuation contract');
  CheckContains(LAudit, 'CheckCodec(False, ''deflate writer flush continuation'')',
    'audit invokes Deflate flush continuation fixture');
  CheckContains(LAudit, 'CheckCodec(True, ''gzip writer flush continuation'')',
    'audit invokes Gzip flush continuation fixture');
  CheckContains(LAudit, 'write after flush returns full count',
    'audit locks write-after-flush continuation count');
  CheckContains(LAudit, 'read after flush continuation EOF returns 0',
    'audit locks flush continuation EOF contract');
  CheckContains(LAudit, 'deflate writer failed close leaves terminal',
    'audit locks Deflate failed-close terminal state');
  CheckContains(LAudit, 'gzip writer failed close leaves terminal',
    'audit locks Gzip failed-close terminal state');
  CheckContains(LAudit, 'TestStreamingWriterFailedPayloadWriteLeavesTerminal',
    'audit test names streaming failed-payload-write terminal contract');
  CheckContains(LAudit, 'Streaming writer failed payload write leaves terminal',
    'audit gate registers streaming failed-payload-write terminal contract');
  CheckContains(LFailedPayloadWrite, 'PAYLOAD_SIZE = 3 * COMPRESS_BUF_SIZE',
    'audit uses a large payload to force write-time compressed output');
  CheckContains(LFailedPayloadWrite, 'SetLength(AData, PAYLOAD_SIZE)',
    'audit allocates the failed-payload-write fixture from the named bound');
  CheckContains(LFailedPayloadWrite, 'clNone',
    'audit uses no-compression streaming mode to force write-time output');
  CheckContains(LFailedPayloadWrite, 'TShortWriter.Create(1)',
    'audit routes Deflate failed-payload-write through a short sink');
  CheckContains(LFailedPayloadWrite, 'TShortWriter.Create(2)',
    'audit routes Gzip failed-payload-write past the header into a short sink');
  CheckContains(LFailedPayloadWrite,
    ''' failed payload write keeps write-after-close error''',
    'audit locks failed-payload-write terminal state label suffix');
  CheckContains(LFailedPayloadWrite, '''deflate writer'');',
    'audit invokes Deflate failed-payload-write terminal fixture');
  CheckContains(LFailedPayloadWrite, '''gzip writer'');',
    'audit invokes Gzip failed-payload-write terminal fixture');
  CheckContains(LAudit, 'TRaisingWriter',
    'audit defines a sink writer that raises directly');
  CheckContains(LAudit, 'TestStreamingWriterRaisedSinkFailureLeavesTerminal',
    'audit test names streaming raised-sink terminal contract');
  CheckContains(LAudit, 'Streaming writer raised sink failure leaves terminal',
    'audit gate registers streaming raised-sink terminal contract');
  CheckContains(LRaisedSinkFailure, 'sink write failed',
    'audit locks direct sink exception propagation');
  CheckContains(LRaisedSinkFailure,
    ''' failed raised sink write keeps write-after-close error''',
    'audit locks raised-sink-write terminal state label suffix');
  CheckContains(LRaisedSinkFailure,
    'GzipWriter(TRaisingWriter.Create(0))',
    'audit covers gzip header write raising directly from sink');
  CheckContains(LAudit, 'deflate: write after close',
    'audit locks Deflate writer after-close error');
  CheckContains(LAudit, 'gzip: write after close',
    'audit locks Gzip writer after-close error');
  CheckContains(LAudit, 'deflate: flush after close',
    'audit locks Deflate writer flush-after-close error');
  CheckContains(LAudit, 'gzip: flush after close',
    'audit locks Gzip writer flush-after-close error');
  CheckContains(LAudit, 'TestStreamingWriterPayloadFlushAfterClose',
    'audit test names payload flush-after-close contract');
  CheckContains(LAudit, 'deflate payload writer flush-after-close uses stable error',
    'audit locks Deflate payload flush-after-close error');
  CheckContains(LAudit, 'gzip payload writer flush-after-close uses stable error',
    'audit locks Gzip payload flush-after-close error');
  CheckContains(LAudit, 'TestDeflateReaderPartialCloseIsReleaseOnly',
    'audit test names Deflate reader release-only close contract');
  CheckContains(LAudit, 'Deflate partial close release-only',
    'audit gate registers Deflate reader release-only close contract');
  CheckContains(LAudit, 'TestGzipReaderPartialCloseIsReleaseOnly',
    'audit test names Gzip reader release-only close contract');
  CheckContains(LAudit, 'Gzip partial close release-only',
    'audit gate registers Gzip reader release-only close contract');
  CheckContains(LAudit, 'TestStreamingReaderCloseBeforeFirstReadIsReleaseOnly',
    'audit test names close-before-first-read release-only contract');
  CheckContains(LAudit, 'Streaming reader close before first read is release-only',
    'audit gate registers close-before-first-read release-only contract');
  CheckContains(LAudit, 'TestStreamingFactoryRejectsNilEndpoints',
    'audit test names streaming nil endpoint contract');
  CheckContains(LAudit, 'Streaming factory rejects nil endpoints',
    'audit gate registers streaming nil endpoint contract');
  CheckContains(LAudit, 'TestStreamingBoundedReaderRejectsNilEndpoints',
    'audit test names bounded streaming nil endpoint contract');
  CheckContains(LAudit, 'Streaming bounded reader rejects nil endpoints',
    'audit gate registers bounded streaming nil endpoint contract');
  CheckContains(LAudit, 'root facade deflate bounded reader rejects nil endpoint',
    'audit locks root facade Deflate bounded nil reader contract');
  CheckContains(LAudit, 'root facade gzip bounded reader rejects nil endpoint',
    'audit locks root facade Gzip bounded nil reader contract');
  CheckContains(LAudit, 'TestStreamingSmallInputZeroWriteAndRepeatedEOFMatrix',
    'audit test names small-input zero-write repeated-EOF streaming contract');
  CheckContains(LAudit, 'Streaming small input zero-write repeated EOF matrix',
    'audit gate registers small-input zero-write repeated-EOF streaming contract');
  CheckContains(LAudit, 'TestStreamingReaderCorruptErrorLeavesTerminalMatrix',
    'audit test names corrupt-input terminal streaming contract');
  CheckContains(LAudit, 'Streaming reader corrupt error leaves terminal matrix',
    'audit gate registers corrupt-input terminal streaming contract');
  CheckContains(LAudit, 'TestStreamingReaderTruncatedErrorLeavesTerminalMatrix',
    'audit test names truncated-input terminal streaming contract');
  CheckContains(LAudit, 'Streaming reader truncated error leaves terminal matrix',
    'audit gate registers truncated-input terminal streaming contract');
  CheckContains(LAudit, 'TestStreamingReaderDeferredValidationAfterPayload',
    'audit test names deferred validation after final payload contract');
  CheckContains(LAudit, 'Streaming reader deferred validation after payload',
    'audit gate registers deferred validation after final payload contract');
  CheckContains(LAudit,
    'deflate trailing bytes after payload read raises on next read',
    'audit locks Deflate trailing-byte validation after payload delivery');
  CheckContains(LAudit,
    'deflate checksum after payload read raises on next read',
    'audit locks Deflate checksum validation after payload delivery');
  CheckContains(LAudit,
    'gzip trailing bytes after payload read raises on next read',
    'audit locks Gzip trailing-byte validation after payload delivery');
  CheckContains(LAudit,
    'gzip CRC after payload read raises on next read',
    'audit locks Gzip CRC validation after payload delivery');
  CheckContains(LAudit,
    'gzip size after payload read raises on next read',
    'audit locks Gzip size validation after payload delivery');
  CheckContains(LAudit,
    'gzip truncated trailer after payload read raises on next read',
    'audit locks Gzip truncated-trailer validation after payload delivery');
  CheckContains(LAudit, 'CheckBoundedDeferredValidationPreservesCallerTail',
    'audit helper names bounded deferred-validation caller-tail contract');
  CheckContains(LAudit,
    'deflate bounded checksum after oversized payload read preserves tail',
    'audit covers bounded Deflate checksum caller-tail preservation');
  CheckContains(LAudit,
    'gzip bounded CRC after oversized payload read preserves tail',
    'audit covers bounded Gzip CRC caller-tail preservation');
  CheckContains(LAudit,
    'gzip bounded size after oversized payload read preserves tail',
    'audit covers bounded Gzip size caller-tail preservation');
  CheckContains(LAudit,
    'gzip corrupt payload after partial output raises on next read',
    'audit locks Gzip corrupt-payload validation after produced bytes');
  CheckContains(LDeep, 'TestGzipStreamingFlushPublishesReadablePrefix',
    'deep test names Gzip flush readable-prefix contract');
  CheckContains(LDeep, 'Gzip streaming flush publishes readable prefix',
    'deep gate registers Gzip flush readable-prefix contract');
  CheckContains(LDeep, 'TestDeflateStreamingFlushPublishesReadablePrefix',
    'deep test names Deflate flush readable-prefix contract');
  CheckContains(LDeep, 'Deflate streaming flush publishes readable prefix',
    'deep gate registers Deflate flush readable-prefix contract');
  CheckContains(LDeflate, 'deflate: writer is nil',
    'Deflate writer factory exposes stable nil writer error');
  CheckContains(LDeflate, 'deflate: reader is nil',
    'Deflate reader factory exposes stable nil reader error');
  CheckContains(LGzip, 'gzip: writer is nil',
    'Gzip writer factory exposes stable nil writer error');
  CheckContains(LGzip, 'gzip: reader is nil',
    'Gzip reader factory exposes stable nil reader error');
end;

procedure TestStreamingDocsShowBoundedReadersForUntrustedInput;
var
  LReadme: string;
  LStreamingSection: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LStreamingSection := SliceBetween(LReadme, '### Streaming (IWriter/IReader)',
    '### Compression Levels');

  CheckContains(LStreamingSection, 'DeflateReaderWithMaxOutputSize',
    'streaming docs show bounded Deflate reader for untrusted input');
  CheckContains(LStreamingSection, 'GzipReaderWithMaxOutputSize',
    'streaming docs show bounded Gzip reader for untrusted input');
  CheckContains(LStreamingSection, 'MaxOutputSize',
    'streaming docs name caller-owned output cap');
  CheckBefore(LStreamingSection, 'DeflateReaderWithMaxOutputSize',
    'DeflateReader(SrcStream)',
    'streaming docs introduce bounded Deflate reader before unbounded example');
end;

procedure TestStreamingZlibAvailNarrowingMatchesSource;
var
  LDeflate: string;
  LGzip: string;
begin
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');

  CheckContains(LDeflate, 'ZlibAvailChunk(',
    'Deflate owns a helper for SizeUInt to zlib avail narrowing');
  CheckContains(LGzip, 'ZlibAvailChunk(',
    'Gzip owns a helper for SizeUInt to zlib avail narrowing');
  CheckAbsent(LDeflate, 'FStream.avail_in := ACount',
    'Deflate writer must not pass SizeUInt ACount directly to zlib avail_in');
  CheckAbsent(LDeflate, 'FStream.avail_out := ACount',
    'Deflate reader must not pass SizeUInt ACount directly to zlib avail_out');
  CheckAbsent(LGzip, 'FStream.avail_in := ACount',
    'Gzip writer must not pass SizeUInt ACount directly to zlib avail_in');
  CheckAbsent(LGzip, 'FStream.avail_out := ACount',
    'Gzip reader must not pass SizeUInt ACount directly to zlib avail_out');
end;

procedure TestStreamingReaderCapProbeMatchesSource;
var
  LDeflate: string;
  LGzip: string;
  LDeflateRead: string;
  LDeflateProbeBranch: string;
  LGzipRead: string;
begin
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LDeflateRead := SliceBetween(LDeflate, 'function TDeflateReader.Read',
    'procedure TDeflateReader.Close;');
  LDeflateProbeBranch := SliceBetween(LDeflateRead, 'if LProbeOnly then',
    'CheckOutputLimit(Result);');
  LGzipRead := SliceBetween(LGzip, 'function TGzipReader.Read',
    'function TGzipReader.FinishStream: Boolean;');

  CheckContains(LDeflateRead, 'LProbeOnly: Boolean;',
    'Deflate bounded reader tracks probe-only cap checks');
  CheckContains(LGzipRead, 'LProbeOnly: Boolean;',
    'Gzip bounded reader tracks probe-only cap checks');
  CheckContains(LDeflateRead, 'if FOutputSize >= FMaxOutputSize then',
    'Deflate bounded reader detects an exhausted output cap before inflate');
  CheckContains(LGzipRead, 'if FOutputSize >= FMaxOutputSize then',
    'Gzip bounded reader detects an exhausted output cap before inflate');
  CheckContains(LDeflateRead, 'FStream.next_out := @LProbe',
    'Deflate exhausted-cap probe does not target caller buffer');
  CheckContains(LGzipRead, 'FStream.next_out := @LProbe',
    'Gzip exhausted-cap probe does not target caller buffer');
  CheckBefore(LDeflateRead, 'if LProbeOnly then',
    'FStream.next_out := @ABuf',
    'Deflate caller buffer is selected only after probe branch');
  CheckBefore(LGzipRead, 'if LProbeOnly then',
    'FStream.next_out := @ABuf',
    'Gzip caller buffer is selected only after probe branch');
  CheckContains(LDeflateRead,
    'raise EIOError.Create(''deflate: decompressed size exceeds limit'')',
    'Deflate exhausted-cap probe raises the stable limit error');
  CheckContains(LGzipRead,
    'raise EIOError.Create(''gzip: decompressed size exceeds limit'')',
    'Gzip exhausted-cap probe raises the stable limit error');
  CheckContains(LDeflate, 'FPendingFinishValidation: Boolean;',
    'Deflate reader tracks pending EOF validation after returning final bytes');
  CheckContains(LGzip, 'FPendingFinishValidation: Boolean;',
    'Gzip reader tracks pending EOF validation after returning final bytes');
  CheckContains(LGzip, 'FPendingReadError: string;',
    'Gzip reader tracks pending corrupt-input errors after returning produced bytes');
  CheckContains(LDeflateRead, 'FPendingFinishValidation := True',
    'Deflate reader defers EOF validation when final bytes are returned');
  CheckContains(LGzipRead, 'FPendingFinishValidation := True',
    'Gzip reader defers EOF validation when final bytes are returned');
  CheckContains(LDeflateRead, 'Exit(Result);',
    'Deflate reader returns final bytes before deferred EOF validation');
  CheckContains(LGzipRead, 'Exit(Result);',
    'Gzip reader returns final bytes before deferred EOF validation');
  CheckContains(LDeflateRead, 'if FPendingFinishValidation then',
    'Deflate reader runs deferred EOF validation on the next read');
  CheckContains(LGzipRead, 'if FPendingFinishValidation then',
    'Gzip reader runs deferred EOF validation on the next read');
  CheckContains(LGzipRead, 'if FPendingReadError <> '''' then',
    'Gzip reader raises pending corrupt-input errors on the next read');
  CheckBefore(LDeflateProbeBranch,
    'raise EIOError.Create(''deflate: decompressed size exceeds limit'')',
    'FinishStream;',
    'Deflate final-byte probe reports limit before trailing bytes');
end;

procedure TestDeflatePendingCorruptReadSourceContract;
var
  LDeflate: string;
  LDeflateRead: string;
  LAudit: string;
begin
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LDeflateRead := SliceBetween(LDeflate, 'function TDeflateReader.Read',
    'procedure TDeflateReader.Close;');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LDeflate, 'FPendingReadError: string;',
    'Deflate reader tracks pending corrupt-input errors after returning produced bytes');
  CheckContains(LDeflateRead, 'if FPendingReadError <> '''' then',
    'Deflate reader raises pending corrupt-input errors on the next read');
  CheckContains(LDeflateRead, 'FPendingReadError := '''';',
    'Deflate reader clears pending corrupt-input errors before raising');
  CheckContains(LDeflateRead,
    'FPendingReadError := ''deflate: corrupt stream'';',
    'Deflate reader stores stable pending corrupt-input error');
  CheckContains(LDeflateRead, 'Exit(Result);',
    'Deflate reader returns produced bytes before deferred corrupt-input error');
  CheckContains(LAudit, 'DeflateWithCorruptPayloadAfterPartialOutput',
    'audit builds Deflate corrupt-payload partial-output fixture');
  CheckContains(LAudit,
    'deflate corrupt payload after partial output raises on next read',
    'audit locks Deflate pending corrupt-input runtime proof');
end;

procedure TestGzipPendingCorruptReadSourceContract;
var
  LGzip: string;
  LGzipRead: string;
  LAudit: string;
begin
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LGzipRead := SliceBetween(LGzip, 'function TGzipReader.Read',
    'function TGzipReader.FinishStream: Boolean;');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LGzip, 'FPendingReadError: string;',
    'Gzip reader tracks pending corrupt-input errors after returning produced bytes');
  CheckContains(LGzipRead, 'if FPendingReadError <> '''' then',
    'Gzip reader raises pending corrupt-input errors on the next read');
  CheckContains(LGzipRead, 'FPendingReadError := '''';',
    'Gzip reader clears pending corrupt-input errors before raising');
  CheckContains(LGzipRead,
    'FPendingReadError := ''gzip: corrupt stream'';',
    'Gzip reader stores stable pending corrupt-input error');
  CheckContains(LGzipRead, 'Exit(Result);',
    'Gzip reader returns produced bytes before deferred corrupt-input error');
  CheckContains(LAudit, 'GzipWithCorruptPayloadAfterPartialOutput',
    'audit builds Gzip corrupt-payload partial-output fixture');
  CheckContains(LAudit,
    'gzip corrupt payload after partial output raises on next read',
    'audit locks Gzip pending corrupt-input runtime proof');
end;

procedure TestOneShotZlibWidthGuardsMatchSource;
var
  LDeflate: string;
  LGzip: string;
  LDeflateImpl: string;
  LGzipImpl: string;
  LDeflateDecode: string;
  LGzipDecode: string;
  LGzipCompress: string;
begin
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LDeflateImpl := SliceBetween(LDeflate, 'implementation', 'end.'#10);
  LGzipImpl := SliceBetween(LGzip, 'implementation', 'end.'#10);
  LDeflateDecode := SliceFrom(LDeflateImpl,
    'function DeflateDecompressWithMaxOutputSize');
  LGzipDecode := SliceFrom(LGzipImpl,
    'function GzipDecompressWithMaxOutputSize');
  LGzipCompress := SliceBetween(LGzipImpl, 'function GzipCompress',
    'function GzipDecompress');

  CheckContains(LDeflate, 'ZlibInputSize(',
    'Deflate owns a helper for one-shot SizeUInt to zlib input narrowing');
  CheckContains(LGzip, 'ZlibInputSize(',
    'Gzip owns a helper for one-shot SizeUInt to zlib input narrowing');
  CheckContains(LDeflate,
    'LDstLen := compressBound(ZlibInputSize(SizeUInt(Length(AData))))',
    'Deflate compress bounds use checked zlib input width');
  CheckContains(LDeflate, 'compress2(@Result[0], @LDstLen, LInput,',
    'Deflate compress calls zlib with explicit input argument');
  CheckContains(LDeflate, 'ZlibInputSize(SizeUInt(Length(AData)))',
    'Deflate compress passes checked input width to zlib');
  CheckContains(LDeflate,
    'LInputSize := ZlibInputSize(SizeUInt(Length(AData)))',
    'Deflate one-shot decode passes checked input width to zlib');
  CheckContains(LGzip,
    'LInputSize := ZlibInputSize(SizeUInt(Length(AData)))',
    'Gzip one-shot encode passes checked input width to zlib');
  CheckContains(LGzip,
    'LBound := compressBound(LInputSize)',
    'Gzip one-shot encode bounds use checked input width');
  CheckContains(LGzip,
    'LStream.avail_in := ZlibInputSize(SizeUInt(Length(AData)) - LOffset)',
    'Gzip one-shot decode passes checked compressed input width to zlib');
  CheckContains(LGzipCompress, 'LInputSize := ZlibInputSize(SizeUInt(Length(AData)))',
    'Gzip one-shot encode stores checked input width once');
  CheckContains(LGzipCompress, 'crc32(0, @AData[0], LInputSize)',
    'Gzip CRC uses checked input width');
  CheckContains(LGzipCompress, 'LSize := UInt32(LInputSize)',
    'Gzip ISIZE uses checked input width');
  CheckContains(LGzipCompress, 'LStream.avail_in := LInputSize',
    'Gzip zlib input uses checked input width');
  CheckContains(LGzipCompress, 'LBound := compressBound(LInputSize)',
    'Gzip compress bound uses checked input width');
  CheckBefore(LGzipCompress, 'LInputSize := ZlibInputSize(SizeUInt(Length(AData)))',
    'crc32(0, @AData[0], LInputSize)',
    'Gzip validates input width before CRC');
  CheckBefore(LGzipCompress, 'LInputSize := ZlibInputSize(SizeUInt(Length(AData)))',
    'LSize := UInt32(LInputSize)',
    'Gzip validates input width before ISIZE narrowing');
  CheckBefore(LDeflateDecode, 'LInputSize := ZlibInputSize(SizeUInt(Length(AData)))',
    'SetLength(Result, LCapacity)',
    'Deflate bounded decode validates input width before output allocation');
  CheckBefore(LGzipDecode, 'LInputSize := ZlibInputSize(SizeUInt(Length(AData)))',
    'SetLength(Result, LCapacity)',
    'Gzip bounded decode validates input width before output allocation');
  CheckContains(LDeflateDecode, 'LStream.avail_out := ZlibAvailChunk(LCapacity - LOutLen)',
    'Deflate bounded decode narrows output room before zlib avail_out');
  CheckAbsent(LDeflateDecode, 'LStream.avail_out := LCapacity - LOutLen',
    'Deflate bounded decode must not pass SizeUInt output room directly to zlib');
  CheckAbsent(LDeflate, 'compressBound(Length(AData))',
    'Deflate must not pass raw Length(AData) to compressBound');
  CheckAbsent(LDeflate, 'LStream.avail_in := Length(AData)',
    'Deflate must not pass raw Length(AData) to zlib avail_in');
  CheckAbsent(LGzip, 'LStream.avail_in := Length(AData)',
    'Gzip must not pass raw Length(AData) to zlib avail_in');
  CheckAbsent(LGzip, 'compressBound(Length(AData))',
    'Gzip must not pass raw Length(AData) to compressBound');
  CheckAbsent(LGzip, 'crc32(0, @AData[0], Length(AData))',
    'Gzip must not pass raw Length(AData) to crc32');
  CheckAbsent(LGzip, 'LSize := UInt32(Length(AData))',
    'Gzip must not narrow raw Length(AData) to ISIZE');
end;

procedure TestOneShotInflateStateCleanupMatchesSource;
var
  LDeflate: string;
  LGzip: string;
  LDeflateImpl: string;
  LGzipImpl: string;
  LDeflateDecode: string;
  LDeflateZeroCap: string;
  LDeflateNormal: string;
  LGzipDecode: string;
begin
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LDeflateImpl := SliceBetween(LDeflate, 'implementation', 'end.'#10);
  LGzipImpl := SliceBetween(LGzip, 'implementation', 'end.'#10);
  LDeflateDecode := SliceFrom(LDeflateImpl,
    'function DeflateDecompressWithMaxOutputSize');
  LGzipDecode := SliceFrom(LGzipImpl,
    'function GzipDecompressWithMaxOutputSize');
  LDeflateZeroCap := SliceBetween(LDeflateDecode,
    'if AMaxOutputSize = 0 then', 'Exit(nil);');
  LDeflateNormal := SliceBetween(LDeflateDecode,
    'SetLength(Result, LCapacity);', 'SetLength(Result, LOutLen);');

  CheckContains(LDeflateZeroCap, 'if inflateInit(LStream) <> Z_OK then',
    'Deflate zero-cap bounded decode initializes zlib state');
  CheckContains(LDeflateZeroCap, 'try',
    'Deflate zero-cap bounded decode protects initialized zlib state');
  CheckContains(LDeflateZeroCap, 'finally',
    'Deflate zero-cap bounded decode uses cleanup finally');
  CheckContains(LDeflateZeroCap, 'inflateEnd(LStream);',
    'Deflate zero-cap bounded decode releases zlib state');
  CheckBefore(LDeflateZeroCap, 'if inflateInit(LStream) <> Z_OK then',
    'try', 'Deflate zero-cap bounded decode guards initialized state');
  CheckBefore(LDeflateZeroCap, 'finally', 'inflateEnd(LStream);',
    'Deflate zero-cap bounded decode releases state in finally');

  CheckContains(LDeflateNormal, 'if inflateInit(LStream) <> Z_OK then',
    'Deflate bounded decode initializes zlib state');
  CheckContains(LDeflateNormal, 'try',
    'Deflate bounded decode protects initialized zlib state');
  CheckContains(LDeflateNormal, 'finally',
    'Deflate bounded decode uses cleanup finally');
  CheckContains(LDeflateNormal, 'inflateEnd(LStream);',
    'Deflate bounded decode releases zlib state');
  CheckBefore(LDeflateNormal, 'if inflateInit(LStream) <> Z_OK then',
    'try', 'Deflate bounded decode guards initialized state');
  CheckBefore(LDeflateNormal, 'finally', 'inflateEnd(LStream);',
    'Deflate bounded decode releases state in finally');

  CheckContains(LGzipDecode, 'if inflateInit2(LStream, -15) <> Z_OK then',
    'Gzip bounded decode initializes zlib state');
  CheckContains(LGzipDecode, 'try',
    'Gzip bounded decode protects initialized zlib state');
  CheckContains(LGzipDecode, 'finally',
    'Gzip bounded decode uses cleanup finally');
  CheckContains(LGzipDecode, 'inflateEnd(LStream);',
    'Gzip bounded decode releases zlib state');
  CheckBefore(LGzipDecode, 'if inflateInit2(LStream, -15) <> Z_OK then',
    'try', 'Gzip bounded decode guards initialized state');
  CheckBefore(LGzipDecode, 'finally', 'inflateEnd(LStream);',
    'Gzip bounded decode releases state in finally');
end;

procedure TestBoundedGrowthPolicyNeverExceedsCap;
var
  LDeflate: string;
  LGzip: string;
  LDeflateImpl: string;
  LGzipImpl: string;
  LDeflateDecode: string;
  LDeflateInitial: string;
  LDeflateGrowth: string;
  LGzipDecode: string;
  LGzipInitial: string;
  LGzipGrowth: string;
begin
  LDeflate := ReadText('src/nextpas.core.compress.deflate.pas');
  LGzip := ReadText('src/nextpas.core.compress.gzip.pas');
  LDeflateImpl := SliceBetween(LDeflate, 'implementation', 'end.'#10);
  LGzipImpl := SliceBetween(LGzip, 'implementation', 'end.'#10);
  LDeflateDecode := SliceFrom(LDeflateImpl,
    'function DeflateDecompressWithMaxOutputSize');
  LGzipDecode := SliceFrom(LGzipImpl,
    'function GzipDecompressWithMaxOutputSize');
  LDeflateInitial := SliceBetween(LDeflateDecode,
    'LCapacity := SizeUInt(Length(AData)) * 4;',
    'FillChar(LStream, SizeOf(LStream), 0);');
  LGzipInitial := SliceBetween(LGzipDecode,
    'LCapacity := SizeUInt(Length(AData)) * 4;',
    'FillChar(LStream, SizeOf(LStream), 0);');
  LDeflateGrowth := SliceBetween(LDeflateDecode,
    'if LOutLen >= LCapacity then',
    'SetLength(Result, LOutLen);');
  LGzipGrowth := SliceBetween(LGzipDecode,
    'repeat',
    'until LRet = Z_STREAM_END;');

  CheckContains(LDeflateInitial, 'LCapacity > AMaxOutputSize',
    'Deflate initial bounded decode capacity checks cap');
  CheckContains(LDeflateInitial, 'LCapacity := AMaxOutputSize',
    'Deflate initial bounded decode clamps to cap');
  CheckBefore(LDeflateInitial, 'LCapacity := AMaxOutputSize',
    'SetLength(Result, LCapacity)',
    'Deflate initial bounded decode clamps before allocation');
  CheckContains(LGzipInitial, 'LCapacity > AMaxOutputSize',
    'Gzip initial bounded decode capacity checks cap');
  CheckContains(LGzipInitial, 'LCapacity := AMaxOutputSize',
    'Gzip initial bounded decode clamps to cap');
  CheckBefore(LGzipInitial, 'LCapacity := AMaxOutputSize',
    'SetLength(Result, LCapacity)',
    'Gzip initial bounded decode clamps before allocation');
  CheckBefore(LGzipDecode,
    'if (AData[LOffset] <> $1F) or (AData[LOffset + 1] <> $8B) then',
    'SetLength(Result, LCapacity)',
    'Gzip bounded decode validates magic before output allocation');
  CheckBefore(LGzipDecode, 'if AData[LOffset + 2] <> $08 then',
    'SetLength(Result, LCapacity)',
    'Gzip bounded decode validates method before output allocation');
  CheckBefore(LGzipDecode, 'if (LFlags and $E0) <> 0 then',
    'SetLength(Result, LCapacity)',
    'Gzip bounded decode validates flags before output allocation');
  CheckContains(LGzipDecode, 'SizeUInt(Length(AData)) - LOffset < 2',
    'Gzip optional header two-byte guards use remaining input capacity');
  CheckAbsent(LGzipDecode, 'LOffset + 2 > SizeUInt(Length(AData))',
    'Gzip optional header two-byte guards must not add positions before input-bound checks');

  CheckContains(LDeflateGrowth, 'LCapacity >= AMaxOutputSize',
    'Deflate bounded growth rejects exhausted cap');
  CheckContains(LDeflateGrowth, 'LCapacity > AMaxOutputSize div 2',
    'Deflate bounded growth checks half-cap before doubling');
  CheckContains(LDeflateGrowth, 'LCapacity := AMaxOutputSize',
    'Deflate bounded growth clamps to max cap');
  CheckContains(LDeflateGrowth, 'LCapacity := LCapacity * 2',
    'Deflate bounded growth doubles only below half-cap');
  CheckBefore(LDeflateGrowth, 'LCapacity > AMaxOutputSize div 2',
    'LCapacity := LCapacity * 2',
    'Deflate bounded growth guards doubling with half-cap check');

  CheckContains(LGzipGrowth, 'LHave > AMaxOutputSize - LOutLen',
    'Gzip bounded growth rejects output above cap before addition');
  CheckAbsent(LGzipGrowth, 'LOutLen + LHave > AMaxOutputSize',
    'Gzip bounded growth must not add output length before cap check');
  CheckAbsent(LGzipGrowth, 'LOutLen + LHave > SizeUInt(Length(Result))',
    'Gzip bounded growth must not add output length before buffer check');
  CheckAbsent(LGzipGrowth, 'LCapacity := LOutLen + LHave',
    'Gzip bounded growth must not size allocation with unchecked addition');
  CheckContains(LGzipGrowth, 'LRequiredCapacity := LOutLen + LHave',
    'Gzip bounded growth computes required capacity only after cap guard');
  CheckContains(LGzipGrowth, 'LCapacity > AMaxOutputSize div 2',
    'Gzip bounded growth checks half-cap before doubling');
  CheckContains(LGzipGrowth, 'LCapacity := AMaxOutputSize',
    'Gzip bounded growth clamps to max cap');
  CheckContains(LGzipGrowth, 'LCapacity := LCapacity * 2',
    'Gzip bounded growth doubles only below half-cap');
  CheckBefore(LGzipGrowth, 'LCapacity > AMaxOutputSize div 2',
    'LCapacity := LCapacity * 2',
    'Gzip bounded growth guards doubling with half-cap check');
end;

procedure TestPerformanceDocsMatchCurrentImplementation;
var
  LReadme: string;
  LGateMatrix: string;
  LBench: string;
  LDeflateCompressBench: string;
  LGzipCompressBench: string;
  LLz4CompressBench: string;
  LGoBench: string;
  LGoBenchLower: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LGateMatrix := SliceFrom(LReadme, '## Gate Matrix');
  LBench := ReadText(
    'benchmarks/nextpas.core.compress/bench_compress/bench_compress.lpr');
  LDeflateCompressBench := SliceBetween(LBench,
    'procedure BenchDeflateCompress;', 'procedure BenchDeflateDecompress;');
  LGzipCompressBench := SliceBetween(LBench,
    'procedure BenchGzipCompress;', 'procedure BenchGzipDecompress;');
  LLz4CompressBench := SliceBetween(LBench,
    'procedure BenchLz4Compress;', 'procedure BenchLz4Decompress;');
  LGoBench := ReadText(
    'benchmarks/nextpas.core.compress/bench_compress/compare_go/main.go');
  LGoBenchLower := LowerText(LGoBench);

  Check(CountLines(LReadme) <= 150,
    'compress README stays compact: ' + IntToStr(CountLines(LReadme)) + ' lines');
  CheckEqual(Int64(4), Int64(CountOccurrences(LGateMatrix, LineEnding + '| `')),
    'gate matrix keeps four data rows');
  CheckAbsent(LReadme, 'Production Ready',
    'compress docs must not overstate production readiness');
  CheckAbsent(LReadme, 'production ready',
    'compress docs must not overstate production readiness lower-case');
  CheckAbsent(LReadme, 'via `nextpas.core.compress.zlib.ffi`',
    'docs must not claim default Deflate/Gzip path goes through zlib.ffi');
  CheckContains(LReadme, 'FPC paszlib by default',
    'docs describe the current default zlib owner');
  CheckContains(LBench, 'DeflateCompress(GData)',
    'benchmark covers one-shot Deflate compression');
  CheckContains(LBench, 'DeflateDecompress(LCompressed)',
    'benchmark covers one-shot Deflate decompression');
  CheckContains(LBench, 'procedure CheckBytesEqual',
    'Pascal compress benchmark validates decoded bytes before reporting throughput');
  CheckContains(LDeflateCompressBench,
    'CheckBytesEqual(GData, LDecompressed, ''Deflate benchmark compress'')',
    'Deflate compression benchmark validates warm-up output before timing');
  CheckBefore(LDeflateCompressBench,
    'CheckBytesEqual(GData, LDecompressed, ''Deflate benchmark compress'')',
    'LStart := TInstant.Now',
    'Deflate compression benchmark validates output before timing');
  CheckContains(LBench,
    'CheckBytesEqual(GData, LDecompressed, ''Deflate benchmark decompress'')',
    'Deflate benchmark validates decompressed output');
  CheckContains(LBench, 'GzipCompress(GData)',
    'benchmark covers one-shot Gzip compression');
  CheckContains(LBench, 'GzipDecompress(LCompressed)',
    'benchmark covers one-shot Gzip decompression');
  CheckContains(LGzipCompressBench,
    'CheckBytesEqual(GData, LDecompressed, ''Gzip benchmark compress'')',
    'Gzip compression benchmark validates warm-up output before timing');
  CheckBefore(LGzipCompressBench,
    'CheckBytesEqual(GData, LDecompressed, ''Gzip benchmark compress'')',
    'LStart := TInstant.Now',
    'Gzip compression benchmark validates output before timing');
  CheckContains(LBench,
    'CheckBytesEqual(GData, LDecompressed, ''Gzip benchmark decompress'')',
    'Gzip benchmark validates decompressed output');
  CheckContains(LReadme, 'LZ4 throughput is covered by the Pascal benchmark only.',
    'docs state LZ4 throughput evidence owner');
  CheckContains(LReadme,
    '`nextpas.core.compress.lz4.ffi` is ABI-only',
    'docs record current LZ4 FFI ABI boundary');
  CheckContains(LReadme,
    '`nextpas.core.compress.lz4.native` owns wrapper, fallback, and error-policy code',
    'docs record current LZ4 native owner boundary');
  CheckContains(LReadme,
    'The Pascal benchmark is one-shot throughput only; it does not measure streaming reader or writer throughput.',
    'docs state Pascal benchmark one-shot-only scope');
  CheckContains(LBench, 'Lz4Compress(GData)',
    'Pascal benchmark covers one-shot LZ4 compression');
  CheckContains(LBench, 'Lz4Decompress(LCompressed, DATA_SIZE)',
    'Pascal benchmark covers one-shot LZ4 decompression');
  CheckContains(LLz4CompressBench,
    'CheckBytesEqual(GData, LDecompressed, ''LZ4 benchmark compress'')',
    'LZ4 compression benchmark validates warm-up output before timing');
  CheckBefore(LLz4CompressBench,
    'CheckBytesEqual(GData, LDecompressed, ''LZ4 benchmark compress'')',
    'LStart := TInstant.Now',
    'LZ4 compression benchmark validates output before timing');
  CheckContains(LBench,
    'CheckBytesEqual(GData, LDecompressed, ''LZ4 benchmark decompress'')',
    'LZ4 benchmark validates decompressed output');
  CheckAbsent(LBench, 'DeflateWriter',
    'Pascal benchmark does not cover Deflate streaming writer throughput');
  CheckAbsent(LBench, 'DeflateReader',
    'Pascal benchmark does not cover Deflate streaming reader throughput');
  CheckAbsent(LBench, 'GzipWriter',
    'Pascal benchmark does not cover Gzip streaming writer throughput');
  CheckAbsent(LBench, 'GzipReader',
    'Pascal benchmark does not cover Gzip streaming reader throughput');
  CheckAbsent(LGoBenchLower, 'lz4',
    'Go comparator remains Deflate/Gzip only for LZ4 throughput ownership');
  CheckContains(LReadme, '## Gate Matrix',
    'docs include a compact gate matrix');
  CheckContains(LReadme,
    '| `audit-gate` | Default landing gate | `test` alias: runtime audit, basic/deep module tests, native compile-only branches, benchmark/Go compile checks, example run, heaptrc, docs contract |',
    'gate matrix documents default audit-gate contents');
  CheckContains(LReadme,
    '| `native-runtime`, `zlib-native-runtime` | Optional runtime/link proof | Host-provided liblz4/libz plus heaptrc; keep optional unless the landing host owns those libraries |',
    'gate matrix documents optional native runtime proof');
  CheckContains(LReadme,
    '| `benchmark-run`, `go-comparator-run` | Optional throughput evidence | Not part of default landing proof |',
    'gate matrix documents optional throughput proof');
  CheckContains(LReadme,
    '| `heaptrc`, `docs-contract-run` | Focused evidence | Zero-leak audit proof and docs/source contract proof |',
    'gate matrix documents heaptrc and docs-contract proof');
end;

procedure TestLz4NativeBoundGuardMatchesPurePolicy;
var
  LBase: string;
  LLz4: string;
  LNative: string;
  LFacade: string;
begin
  LBase := ReadText('src/nextpas.core.compress.base.pas');
  LLz4 := ReadText('src/nextpas.core.compress.lz4.pas');
  LNative := ReadText('src/nextpas.core.compress.lz4.native.pas');
  LFacade := ReadText('src/nextpas.core.compress.pas');

  CheckContains(LBase, 'LZ4_MAX_INPUT_SIZE',
    'compress base owns shared LZ4 max input policy');
  CheckContains(LLz4, 'AInputSize > LZ4_MAX_INPUT_SIZE',
    'pure LZ4 bound checks shared max input policy');
  CheckContains(LLz4, 'LLen > LZ4_MAX_INPUT_SIZE',
    'pure LZ4 compress checks shared max input policy');
  CheckAbsent(LLz4, '(LLen = 0) or (LLen > LZ4_MAX_INPUT_SIZE)',
    'pure LZ4 compress must not silently treat over-limit input as empty');
  CheckContains(LLz4, 'SetLength(Result, Lz4CompressBound(LLen))',
    'pure LZ4 compress uses the public bound as its allocation ceiling');
  CheckAbsent(LLz4, 'LLen + (LLen div 255) + 16 + 4',
    'pure LZ4 compress must not allocate above its public bound');
  CheckAbsent(LowerText(LLz4), '* 2',
    'pure LZ4 compress must not use unbounded dynamic output growth');
  CheckContains(LNative, 'SizeUInt(AInputSize) > LZ4_MAX_INPUT_SIZE',
    'native LZ4 bound checks shared max input policy before FFI');
  CheckContains(LFacade, 'AInputSize > LZ4_MAX_INPUT_SIZE',
    'facade checks LZ4 bound before narrowing SizeUInt for native FFI');
  CheckContains(LNative, 'SizeUInt(Length(AData)) > LZ4_MAX_INPUT_SIZE',
    'native LZ4 compress checks shared max input policy before FFI');
  CheckContains(LNative, 'NativeLz4CompressBound(Int32(Length(AData)))',
    'native LZ4 compress reuses checked bound helper');
end;

procedure TestLz4NativeFacadeOwnerBoundary;
var
  LFacade: string;
  LInterfaceUses: string;
  LNativeUses: string;
  LPureUses: string;
begin
  LFacade := ReadText('src/nextpas.core.compress.pas');
  LInterfaceUses := SliceBetween(LFacade, 'interface', 'type');
  LNativeUses := SliceBetween(LInterfaceUses,
    '{$IFDEF NEXTPAS_USE_LZ4_NATIVE}', '{$ENDIF}');
  LPureUses := SliceBetween(LInterfaceUses,
    '{$IFNDEF NEXTPAS_USE_LZ4_NATIVE}', '{$ENDIF}');

  CheckContains(LInterfaceUses, '{$IFNDEF NEXTPAS_USE_LZ4_NATIVE}',
    'facade pure LZ4 import is guarded away from native mode');
  CheckContains(LInterfaceUses, '{$IFDEF NEXTPAS_USE_LZ4_NATIVE}',
    'facade native LZ4 import is guarded behind native mode');
  CheckContains(LPureUses, 'nextpas.core.compress.lz4',
    'facade pure LZ4 import is inside non-native branch');
  CheckAbsent(LPureUses, 'nextpas.core.compress.lz4.ffi',
    'facade non-native branch must not import native LZ4 FFI owner');
  CheckContains(LNativeUses, 'nextpas.core.compress.lz4.native',
    'facade native LZ4 import is inside native branch');
  CheckAbsent(LNativeUses, 'nextpas.core.compress.lz4.ffi',
    'facade native branch must not import raw LZ4 FFI unit');
  CheckAbsent(LNativeUses, ', nextpas.core.compress.lz4' + LineEnding,
    'facade native branch must not import pure LZ4 implementation');
end;

procedure TestLz4FfiUnitIsAbiOnlyAndNativeOwnerBoundary;
var
  LFfi: string;
  LNative: string;
  LFacade: string;
  LReadme: string;
begin
  LFfi := ReadText('src/nextpas.core.compress.lz4.ffi.pas');
  LNative := ReadText('src/nextpas.core.compress.lz4.native.pas');
  LFacade := ReadText('src/nextpas.core.compress.pas');
  LReadme := ReadText('docs/compress/README.md');

  CheckContains(LFfi, 'external ''lz4''',
    'LZ4 ffi unit declares native liblz4 ABI');
  CheckAbsent(LFfi, 'function NativeLz4Compress',
    'LZ4 ffi unit must not own native wrapper facade');
  CheckAbsent(LFfi, 'uses' + LineEnding + '  nextpas.core.compress.lz4',
    'LZ4 ffi unit must not own pure fallback imports');
  CheckAbsent(LFfi, 'SetLength(Result',
    'LZ4 ffi unit must not own allocation policy');
  CheckAbsent(LFfi, 'RaiseAfterClearingResult',
    'LZ4 ffi unit must not own error cleanup policy');

  CheckContains(LNative, 'function NativeLz4Compress',
    'LZ4 native owner unit exposes native wrapper facade');
  CheckContains(LNative, 'nextpas.core.compress.lz4.ffi',
    'LZ4 native owner unit imports ABI unit only in native mode');
  CheckContains(LNative, 'nextpas.core.compress.lz4',
    'LZ4 native owner unit owns pure fallback');
  CheckContains(LFacade, 'nextpas.core.compress.lz4.native',
    'root facade imports compress-owned LZ4 native owner');
  CheckAbsent(LFacade, 'nextpas.core.compress.lz4.ffi',
    'root facade must not import raw LZ4 ffi unit');
  CheckContains(LReadme, '`nextpas.core.compress.lz4.native` owns wrapper, fallback, and error-policy code',
    'docs record current LZ4 native owner boundary');
end;

procedure TestLz4DecodeBoundGuardMatchesPurePolicy;
var
  LReadme: string;
  LAudit: string;
  LLz4: string;
  LDecode: string;
  LDecodeAfterInputWidth: string;
  LNative: string;
  LNativeDecode: string;
  LNativeDecodeAfterInputWidth: string;
  LFacade: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');
  LLz4 := ReadText('src/nextpas.core.compress.lz4.pas');
  LDecode := SliceFrom(LLz4, 'function Lz4DecompressWithMaxOutputSize');
  LDecodeAfterInputWidth := SliceFrom(LDecode,
    'if SizeUInt(Length(AData)) > SizeUInt(High(Int32)) then');
  LNative := ReadText('src/nextpas.core.compress.lz4.native.pas');
  LNativeDecode := SliceFrom(LNative,
    'function NativeLz4DecompressWithMaxOutputSize');
  LNativeDecodeAfterInputWidth := SliceFrom(LNativeDecode,
    'if SizeUInt(Length(AData)) > SizeUInt(High(Int32)) then');
  LFacade := ReadText('src/nextpas.core.compress.pas');

  CheckContains(LLz4, 'SizeUInt(AOriginalSize) > LZ4_MAX_INPUT_SIZE',
    'pure LZ4 decode checks original-size policy before allocation');
  CheckContains(LLz4, 'function Lz4DecompressWithMaxOutputSize',
    'pure LZ4 subunit exposes bounded decode helper');
  CheckContains(LLz4, 'AOriginalSize) > AMaxOutputSize',
    'pure LZ4 bounded decode checks declared output cap before allocation');
  CheckContains(LLz4, 'SizeUInt(Length(AData)) > SizeUInt(High(Int32))',
    'pure LZ4 decode checks compressed input width before Int32 narrowing');
  CheckBefore(LLz4, 'SizeUInt(Length(AData)) > SizeUInt(High(Int32))',
    'LEnd := Length(AData)',
    'pure LZ4 decode validates compressed input width before assigning Int32 end');
  CheckContains(LDecode, 'LLitLen > LEnd - LSrc',
    'pure LZ4 literal input guard uses remaining input capacity');
  CheckContains(LDecode, 'LEnd - LSrc < 2',
    'pure LZ4 offset guard uses remaining input capacity');
  CheckContains(LDecode, 'LLitLen > AOriginalSize - LDst',
    'pure LZ4 literal output guard uses remaining output capacity');
  CheckContains(LDecode, 'LMatchLen > AOriginalSize - LDst',
    'pure LZ4 match output guard uses remaining output capacity');
  CheckAbsent(LDecode, 'LSrc + LLitLen > LEnd',
    'pure LZ4 decode must not add positions before input-bound checks');
  CheckAbsent(LDecode, 'LSrc + 2 > LEnd',
    'pure LZ4 offset guard must not add positions before input-bound checks');
  CheckAbsent(LDecode, 'LDst + LLitLen > AOriginalSize',
    'pure LZ4 decode must not add positions before literal output-bound checks');
  CheckAbsent(LDecode, 'LDst + LMatchLen > AOriginalSize',
    'pure LZ4 decode must not add positions before match output-bound checks');
  CheckContains(LLz4, 'Result := Lz4DecompressWithMaxOutputSize(AData, AOriginalSize, LZ4_MAX_INPUT_SIZE)',
    'pure LZ4 default decode delegates to bounded helper');
  CheckContains(LReadme, 'Lz4DecompressWithMaxOutputSize',
    'docs name bounded LZ4 helper');
  CheckContains(LReadme, 'uses nextpas.core.compress;',
    'docs show bounded LZ4 helper root facade import');
  CheckContains(LReadme,
    'Lz4DecompressWithMaxOutputSize(Compressed, OriginalSize, MaxOutputSize)',
    'docs show bounded LZ4 helper call shape');
  CheckAbsent(LReadme, 'not re-exported by the root `nextpas.core.compress` facade',
    'docs must not preserve stale bounded LZ4 helper facade boundary');
  CheckContains(LFacade, 'function Lz4DecompressWithMaxOutputSize',
    'root facade exposes bounded LZ4 helper');
  CheckContains(LFacade,
    'nextpas.core.compress.lz4.native.NativeLz4DecompressWithMaxOutputSize',
    'root facade forwards native bounded LZ4 helper to native owner');
  CheckContains(LFacade,
    'nextpas.core.compress.lz4.Lz4DecompressWithMaxOutputSize',
    'root facade forwards pure bounded LZ4 helper to LZ4 subunit');
  CheckContains(LNative, 'SizeUInt(AOriginalSize) > LZ4_MAX_INPUT_SIZE',
    'native LZ4 decode checks original-size policy before allocation');
  CheckContains(LNative, 'function NativeLz4DecompressWithMaxOutputSize',
    'native LZ4 subunit exposes bounded decode helper');
  CheckContains(LNative, 'AOriginalSize) > AMaxOutputSize',
    'native LZ4 bounded decode checks declared output cap before allocation');
  CheckContains(LNative, 'Result := NativeLz4DecompressWithMaxOutputSize(AData, AOriginalSize, LZ4_MAX_INPUT_SIZE)',
    'native LZ4 default decode delegates to bounded helper');
  CheckContains(LNative, 'Lz4DecompressWithMaxOutputSize(AData,',
    'native LZ4 fallback delegates bounded helper to pure implementation');
  CheckContains(LNative, 'AOriginalSize, AMaxOutputSize)',
    'native LZ4 fallback passes bounded output cap to pure implementation');
  CheckContains(LNative, 'SizeUInt(Length(AData)) > SizeUInt(High(Int32))',
    'native LZ4 decode checks compressed input width before FFI');
  CheckBefore(LDecodeAfterInputWidth, 'if IsLz4FrameHeader(AData) then',
    'SetLength(Result, AOriginalSize)',
    'pure LZ4 decode classifies frame headers before output allocation');
  CheckBefore(LNativeDecodeAfterInputWidth, 'if IsLz4FrameHeader(AData) then',
    'SetLength(Result, AOriginalSize)',
    'native LZ4 decode classifies frame headers before output allocation');
  CheckContains(LNativeDecode, 'procedure RaiseAfterClearingResult',
    'native LZ4 decode centralizes FFI failure cleanup');
  CheckContains(LNativeDecode, 'SetLength(Result, 0);',
    'native LZ4 decode clears FFI output buffer on failure before raising');
  CheckBefore(LNativeDecode, 'SetLength(Result, 0);',
    'raise EIOError.Create(AMessage)',
    'native LZ4 cleanup helper clears output buffer before raising');
  CheckContains(LNativeDecode,
    'RaiseAfterClearingResult(''lz4 native: decompress failed'')',
    'native LZ4 decompress failure uses cleanup helper');
  CheckContains(LNativeDecode,
    'RaiseAfterClearingResult(''lz4 native: size mismatch'')',
    'native LZ4 size mismatch uses cleanup helper');
  CheckContains(LAudit, 'TestRootFacadeLz4BoundAndMetadataParity',
    'audit test names root facade LZ4 bound and metadata parity');
  CheckContains(LAudit, 'Root facade LZ4 bound and metadata parity',
    'audit gate registers root facade LZ4 bound and metadata parity');
  CheckContains(LAudit, 'TestRootFacadeLz4BoundedMalformedParity',
    'audit test names root facade bounded LZ4 malformed parity');
  CheckContains(LAudit, 'Root facade bounded LZ4 malformed parity',
    'audit gate registers root facade bounded LZ4 malformed parity');
end;

procedure TestLz4EmptyDecodeContractMatchesAudit;
var
  LReadme: string;
  LAudit: string;
  LLz4: string;
  LNative: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');
  LLz4 := ReadText('src/nextpas.core.compress.lz4.pas');
  LNative := ReadText('src/nextpas.core.compress.lz4.native.pas');

  CheckContains(LReadme, '`Lz4Decompress(nil, 0)` returns empty `TBytes`',
    'docs state LZ4 empty decode contract');
  CheckContains(LAudit, 'TestLz4EmptyDecodeContract',
    'audit test names LZ4 empty decode contract');
  CheckContains(LAudit, 'LZ4 empty decode contract',
    'audit gate registers LZ4 empty decode contract');
  CheckContains(LLz4, 'if Length(AData) = 0 then',
    'pure LZ4 decode has empty input branch');
  CheckContains(LNative, 'if Length(AData) = 0 then',
    'native LZ4 wrapper has empty input branch');
end;

procedure TestLz4RawBlockDocsMatchFrameGuard;
var
  LReadme: string;
  LLz4: string;
  LNative: string;
  LAudit: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LLz4 := ReadText('src/nextpas.core.compress.lz4.pas');
  LNative := ReadText('src/nextpas.core.compress.lz4.native.pas');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LReadme, 'raw LZ4 block',
    'docs identify LZ4 as raw block API');
  CheckContains(LReadme, 'frame headers are rejected as unsupported',
    'docs identify unsupported LZ4 frame boundary');
  CheckContains(LLz4, 'IsLz4FrameHeader',
    'pure LZ4 decode owns frame header classifier');
  CheckContains(LLz4, 'unsupported frame/header',
    'pure LZ4 decode exposes stable frame-header error');
  CheckContains(LNative, 'IsLz4FrameHeader',
    'native LZ4 wrapper owns frame header classifier');
  CheckContains(LNative, 'unsupported frame/header',
    'native LZ4 wrapper exposes stable frame-header error');
  CheckContains(LLz4, 'on E: EIOError do',
    'pure LZ4 classifies frame headers after raw decode fails');
  CheckContains(LNative, 'if LDecompressed < 0 then',
    'native LZ4 classifies frame headers after native decode fails');
  CheckContains(LLz4, '$184D2204',
    'pure LZ4 guard rejects standard frame magic');
  CheckContains(LLz4, '$184D2A50',
    'pure LZ4 guard rejects skippable frame magic family');
  CheckContains(LLz4, '$184C2102',
    'pure LZ4 guard rejects legacy frame magic');
  CheckContains(LLz4, 'if LMagic = $184D2204 then',
    'pure LZ4 standard frame magic is classified from four-byte magic');
  CheckContains(LLz4, 'if LMagic = $184C2102 then',
    'pure LZ4 legacy frame magic is classified from four-byte magic');
  CheckContains(LLz4, 'LSkippableSize := UInt32(AData[4])',
    'pure LZ4 skippable frame guard reads declared payload size');
  CheckContains(LLz4, 'if Length(AData) = 4 then',
    'pure LZ4 exact skippable magic is classified as frame header');
  CheckContains(LLz4, 'if Length(AData) < 8 then',
    'pure LZ4 partial skippable header keeps raw-block path');
  CheckContains(LLz4, 'SizeUInt(Length(AData)) - 8 >= SizeUInt(LSkippableSize)',
    'pure LZ4 skippable frame guard requires complete declared payload');
  CheckContains(LNative, '$184D2204',
    'native LZ4 guard rejects standard frame magic');
  CheckContains(LNative, '$184D2A50',
    'native LZ4 guard rejects skippable frame magic family');
  CheckContains(LNative, '$184C2102',
    'native LZ4 guard rejects legacy frame magic');
  CheckContains(LNative, 'if LMagic = $184D2204 then',
    'native LZ4 standard frame magic is classified from four-byte magic');
  CheckContains(LNative, 'if LMagic = $184C2102 then',
    'native LZ4 legacy frame magic is classified from four-byte magic');
  CheckContains(LNative, 'LSkippableSize := UInt32(AData[4])',
    'native LZ4 skippable frame guard reads declared payload size');
  CheckContains(LNative, 'if Length(AData) = 4 then',
    'native LZ4 exact skippable magic is classified as frame header');
  CheckContains(LNative, 'if Length(AData) < 8 then',
    'native LZ4 partial skippable header keeps raw-block path');
  CheckContains(LNative,
    'SizeUInt(Length(AData)) - 8 >= SizeUInt(LSkippableSize)',
    'native LZ4 skippable frame guard requires complete declared payload');
  CheckContains(LAudit, 'standard frame header',
    'audit locks standard LZ4 frame header rejection');
  CheckContains(LAudit, 'skippable frame header',
    'audit locks skippable LZ4 frame header rejection');
  CheckContains(LAudit, 'legacy frame header',
    'audit locks legacy LZ4 frame header rejection');
  CheckContains(LAudit, 'TestLz4TruncatedFrameMagicRejectedAsUnsupported',
    'audit test names truncated LZ4 frame magic contract');
  CheckContains(LAudit, 'LZ4 truncated frame magic unsupported',
    'audit gate registers truncated LZ4 frame magic contract');
  CheckContains(LAudit, 'truncated standard frame magic',
    'audit locks truncated standard frame magic rejection');
  CheckContains(LAudit, 'truncated skippable frame magic',
    'audit locks truncated skippable frame magic rejection');
  CheckContains(LAudit, 'truncated legacy frame magic',
    'audit locks truncated legacy frame magic rejection');
  CheckContains(LAudit, 'TestLz4RawBlockSkippableMagicLiteralPrefixAccepted',
    'audit locks raw-block collision with skippable frame magic');
  CheckContains(LAudit, 'TestLz4MalformedRawBlockMagicLiteralPrefixKeepsDecodeError',
    'audit locks malformed raw-block collision with skippable frame magic');
  CheckContains(LAudit, 'LZ4 malformed raw block magic literal prefix',
    'audit registers malformed raw-block collision with skippable frame magic');
  CheckContains(LAudit, 'Pos(''unsupported frame/header'', E.Message) = 0',
    'audit locks malformed raw-block collision away from frame-header classification');
  CheckContains(LAudit, 'skippable magic threshold collision keeps decode error',
    'audit locks incomplete skippable-header collision as raw-block error');
  CheckContains(LAudit, 'TestRootFacadeLz4FrameRawBlockBoundary',
    'audit test names root facade LZ4 frame/raw-block boundary');
  CheckContains(LAudit, 'Root facade LZ4 frame/raw-block boundary',
    'audit gate registers root facade LZ4 frame/raw-block boundary');
end;

procedure TestLz4ErrorModelDocsMatchAudit;
var
  LReadme: string;
  LLz4: string;
  LLz4Native: string;
  LAudit: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LLz4 := ReadText('src/nextpas.core.compress.lz4.pas');
  LLz4Native := ReadText('src/nextpas.core.compress.lz4.native.pas');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LReadme, 'LZ4 error model:',
    'docs name the stable LZ4 error model');
  CheckContains(LReadme, 'The stable `lz4:` error model is the default pure-Pascal surface',
    'docs scope stable LZ4 errors to the default pure implementation');
  CheckContains(LReadme, 'The optional native LZ4 FFI surface is not error-message parity with the pure path',
    'docs state native LZ4 error surface is non-parity');
  CheckContains(LReadme, '`lz4 native: decompress failed`',
    'docs list native LZ4 coarse decode failure');
  CheckContains(LReadme, '`lz4 native: size mismatch`',
    'docs list native LZ4 coarse size mismatch');
  CheckContains(LReadme, '`lz4: truncated literal length`',
    'docs list stable LZ4 truncated-literal-length error');
  CheckContains(LReadme, '`lz4: literal overflow`',
    'docs list stable LZ4 literal-overflow error');
  CheckContains(LReadme, '`lz4: literal length overflow`',
    'docs list stable LZ4 literal-length-overflow error');
  CheckContains(LReadme, '`lz4: truncated offset`',
    'docs list stable LZ4 truncated-offset error');
  CheckContains(LReadme, '`lz4: zero offset`',
    'docs list stable LZ4 zero-offset error');
  CheckContains(LReadme, '`lz4: offset before start`',
    'docs list stable LZ4 offset-before-start error');
  CheckContains(LReadme, '`lz4: truncated match length`',
    'docs list stable LZ4 truncated-match-length error');
  CheckContains(LReadme, '`lz4: match length overflow`',
    'docs list stable LZ4 match-length-overflow error');
  CheckContains(LReadme, '`lz4: output overflow`',
    'docs list stable LZ4 output-overflow error');
  CheckContains(LReadme, '`lz4: decompressed size mismatch`',
    'docs list stable LZ4 size-mismatch error');
  CheckContains(LReadme, '`lz4: final literal tail missing`',
    'docs list stable LZ4 final-literal-tail error');
  CheckContains(LReadme, '`lz4: final match too close to end`',
    'docs list stable LZ4 near-end-match error');
  CheckContains(LReadme, '`lz4: input size exceeds limit`',
    'docs list stable LZ4 input-size-limit error');
  CheckContains(LReadme, '`lz4: invalid original size`',
    'docs list stable LZ4 invalid-original-size error');
  CheckContains(LReadme, '`lz4: original size exceeds limit`',
    'docs list stable LZ4 original-size-limit error');
  CheckContains(LReadme, '`lz4: compressed input size exceeds limit`',
    'docs list stable LZ4 compressed-input-size-limit error');
  CheckContains(LReadme, '`lz4: decompressed size exceeds limit`',
    'docs list stable LZ4 output-cap error');
  CheckContains(LReadme, '`lz4: empty input with nonzero original size`',
    'docs list stable LZ4 empty-input metadata error');
  CheckContains(LReadme, '`lz4: non-empty input with zero original size`',
    'docs list stable LZ4 zero-original-size metadata error');
  CheckContains(LLz4, 'lz4: truncated literal length',
    'pure LZ4 source exposes stable truncated-literal-length error');
  CheckContains(LLz4, 'lz4: literal overflow',
    'pure LZ4 source exposes stable literal-overflow error');
  CheckContains(LLz4, 'lz4: literal length overflow',
    'pure LZ4 source exposes stable literal-length-overflow error');
  CheckContains(LLz4, 'lz4: truncated offset',
    'pure LZ4 source exposes stable truncated-offset error');
  CheckContains(LLz4, 'lz4: zero offset',
    'pure LZ4 source exposes stable zero-offset error');
  CheckContains(LLz4, 'lz4: offset before start',
    'pure LZ4 source exposes stable offset-before-start error');
  CheckContains(LLz4, 'lz4: truncated match length',
    'pure LZ4 source exposes stable truncated-match-length error');
  CheckContains(LLz4, 'lz4: match length overflow',
    'pure LZ4 source exposes stable match-length-overflow error');
  CheckContains(LLz4, 'lz4: output overflow',
    'pure LZ4 source exposes stable output-overflow error');
  CheckContains(LLz4, 'lz4: decompressed size mismatch',
    'pure LZ4 source exposes stable decompressed-size-mismatch error');
  CheckContains(LLz4, 'lz4: final literal tail missing',
    'pure LZ4 source exposes stable final-literal-tail error');
  CheckContains(LLz4, 'lz4: final match too close to end',
    'pure LZ4 source exposes stable near-end-match error');
  CheckContains(LLz4, 'lz4: input size exceeds limit',
    'pure LZ4 source exposes stable input-size-limit error');
  CheckContains(LLz4, 'lz4: invalid original size',
    'pure LZ4 source exposes stable invalid-original-size error');
  CheckContains(LLz4, 'lz4: original size exceeds limit',
    'pure LZ4 source exposes stable original-size-limit error');
  CheckContains(LLz4, 'lz4: compressed input size exceeds limit',
    'pure LZ4 source exposes stable compressed-input-size-limit error');
  CheckContains(LLz4, 'lz4: decompressed size exceeds limit',
    'pure LZ4 source exposes stable output-cap error');
  CheckContains(LLz4, 'lz4: empty input with nonzero original size',
    'pure LZ4 source exposes stable empty-input metadata error');
  CheckContains(LLz4, 'lz4: non-empty input with zero original size',
    'pure LZ4 source exposes stable zero-original-size metadata error');
  CheckContains(LLz4Native, 'lz4 native: decompress failed',
    'native LZ4 source exposes non-parity decompress failure');
  CheckContains(LLz4Native, 'lz4 native: size mismatch',
    'native LZ4 source exposes non-parity size mismatch');
  CheckContains(LAudit, 'lz4 native: decompress failed',
    'audit accepts documented native LZ4 coarse decode failure');
  CheckContains(LAudit, 'TestNativeLz4OriginalSizeMismatch',
    'audit test names native LZ4 original-size mismatch contract');
  CheckContains(LAudit, 'Native LZ4 original-size mismatch',
    'audit gate registers native LZ4 original-size mismatch contract');
  CheckContains(LAudit, 'TestLz4MalformedBranchErrorModel',
    'audit test names LZ4 malformed branch error contract');
  CheckContains(LAudit, 'LZ4 malformed branch error model',
    'audit gate registers LZ4 malformed branch error contract');
  CheckContains(LAudit, '''root facade lz4 '' + ALabel + '' has stable error''',
    'audit covers root facade LZ4 malformed branch errors');
  CheckContains(LAudit, '''native lz4 wrapper '' + ALabel +',
    'audit covers native wrapper LZ4 malformed branch errors');
  CheckContains(LAudit, '''truncated literal length'');',
    'audit routes truncated-literal-length through the LZ4 malformed branch matrix');
  CheckContains(LAudit, 'TestLz4MalformedOriginalSizeMetadata',
    'audit test names LZ4 metadata error contract');
  CheckContains(LAudit, 'LZ4 malformed original size metadata',
    'audit gate registers LZ4 metadata error contract');
  CheckContains(LAudit, 'lz4: truncated offset',
    'audit locks stable LZ4 truncated-offset error');
  CheckContains(LAudit, 'lz4: match length overflow',
    'audit locks stable LZ4 match-length-overflow error');
  CheckContains(LAudit, 'lz4: output overflow',
    'audit locks stable LZ4 output-overflow error');
  CheckContains(LAudit, 'TestLz4MalformedBlockEndingWithMatchRejected',
    'audit test names final-literal-tail malformed block contract');
  CheckContains(LAudit, 'LZ4 malformed block ending with match',
    'audit gate registers final-literal-tail malformed block contract');
  CheckContains(LAudit, 'lz4: final literal tail missing',
    'audit locks stable final-literal-tail error');
  CheckContains(LAudit, 'root facade lz4 rejects block ending with match',
    'audit covers root facade final-literal-tail malformed block contract');
  CheckContains(LAudit, 'native lz4 wrapper rejects block ending with match',
    'audit covers native wrapper final-literal-tail malformed block contract');
  CheckContains(LAudit, 'TestLz4MalformedNearEndMatchRejected',
    'audit test names near-end-match malformed block contract');
  CheckContains(LAudit, 'LZ4 malformed near-end match',
    'audit gate registers near-end-match malformed block contract');
  CheckContains(LAudit, 'lz4: final match too close to end',
    'audit locks stable near-end-match error');
  CheckContains(LAudit,
    'root facade lz4 rejects last match inside final match limit',
    'audit covers root facade near-end-match malformed block contract');
  CheckContains(LAudit,
    'native lz4 wrapper rejects last match inside final match limit',
    'audit covers native wrapper near-end-match malformed block contract');
end;

procedure TestLz4EncoderBlockTerminationMatchesAudit;
var
  LLz4: string;
  LAudit: string;
begin
  LLz4 := ReadText('src/nextpas.core.compress.lz4.pas');
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');

  CheckContains(LLz4, 'LZ4_LAST_LITERALS = 5',
    'pure LZ4 encoder names the final literal tail rule');
  CheckContains(LLz4, 'LZ4_MF_LIMIT = 12',
    'pure LZ4 encoder names the last-match search rule');
  CheckContains(LLz4, 'LMatchFindLimit := LEnd - LZ4_MF_LIMIT',
    'pure LZ4 encoder stops finding matches before the final match limit');
  CheckContains(LLz4, 'LMatchLimit := LEnd - LZ4_LAST_LITERALS',
    'pure LZ4 encoder stops extending matches before final literals');
  CheckContains(LLz4, 'while LSrc <= LMatchFindLimit do',
    'pure LZ4 encoder applies the last-match search limit');
  CheckContains(LLz4, 'LSrc + LMatchLen < LMatchLimit',
    'pure LZ4 encoder applies the final-literal extension limit');
  CheckContains(LAudit, 'TestLz4PureEncoderBlockEndsWithLiteralTail',
    'audit test names pure LZ4 block termination contract');
  CheckContains(LAudit, 'LZ4 pure encoder block ends with literal tail',
    'audit gate registers pure LZ4 block termination contract');
end;

procedure TestNativeLz4CompileGateIsInAuditPath;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile, 'NATIVE_COMPILE_FLAGS ?= -Cn -dNEXTPAS_USE_LZ4_NATIVE',
    'audit Makefile compiles native LZ4 branch without linking');
  CheckContains(LMakefile, 'test: run native-compile',
    'audit test target includes native LZ4 compile-only gate');
  CheckContains(LMakefile, 'compress-audit-native-lz4-compile=pass',
    'native LZ4 compile gate emits stable pass marker');
end;

procedure TestNativeLz4RuntimeGateIsOptional;
var
  LReadme: string;
  LMakefile: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile, 'NATIVE_RUNTIME_BUILD_DIR',
    'audit Makefile isolates native LZ4 runtime build artifacts');
  CheckContains(LMakefile, 'NATIVE_RUNTIME_HEAPTRC_LOG',
    'audit Makefile stores native LZ4 runtime heaptrc output separately');
  CheckContains(LMakefile, 'NATIVE_RUNTIME_RUN_LOG',
    'audit Makefile stores native LZ4 runtime program output separately');
  CheckContains(LMakefile,
    'NATIVE_RUNTIME_HEAPTRC_ENV ?= HEAPTRC=log=$(NATIVE_RUNTIME_HEAPTRC_LOG)',
    'native LZ4 runtime directs heaptrc to an explicit log file');
  CheckContains(LMakefile, 'NATIVE_RUNTIME_FLAGS ?= -dNEXTPAS_USE_LZ4_NATIVE',
    'audit Makefile exposes native LZ4 link/runtime flags');
  CheckContains(LMakefile, 'LZ4_PKG_CONFIG ?= pkg-config',
    'audit Makefile exposes pkg-config selector for native LZ4 runtime');
  CheckContains(LMakefile, 'LZ4_LIB_DIR ?= $(shell $(LZ4_PKG_CONFIG) --variable=libdir liblz4',
    'audit Makefile discovers native LZ4 libdir via pkg-config');
  CheckContains(LMakefile, 'NATIVE_RUNTIME_FPC_FLAGS ?= $(FPC_FLAGS)',
    'audit Makefile exposes native LZ4 runtime FPC flags');
  CheckContains(LMakefile, '$(if $(LZ4_LIB_DIR),-Fl$(LZ4_LIB_DIR))',
    'native LZ4 runtime passes pkg-config libdir to FPC linker');
  CheckContains(LMakefile, 'NATIVE_RUNTIME_ENV ?= $(if $(LZ4_LIB_DIR),LD_LIBRARY_PATH=$(LZ4_LIB_DIR)',
    'native LZ4 runtime only injects shared library lookup when pkg-config libdir exists');
  CheckContains(LMakefile, '$(if $(LD_LIBRARY_PATH),:$(LD_LIBRARY_PATH),),)',
    'native LZ4 runtime preserves caller LD_LIBRARY_PATH');
  CheckContains(LMakefile, 'native-runtime:',
    'audit Makefile exposes optional native LZ4 runtime target');
  CheckContains(LMakefile, 'rm -f $(NATIVE_RUNTIME_RUN_LOG) $(NATIVE_RUNTIME_HEAPTRC_LOG)',
    'native LZ4 runtime clears stale logs before leak proof');
  CheckContains(LMakefile, '$(NATIVE_RUNTIME_ENV) $(NATIVE_RUNTIME_HEAPTRC_ENV) $(NATIVE_RUNTIME_BUILD_DIR)/$(PROGRAM) > $(NATIVE_RUNTIME_RUN_LOG) 2>&1',
    'native LZ4 runtime captures program output separately from heaptrc');
  CheckContains(LMakefile, 'grep -F ''0 unfreed memory blocks'' $(NATIVE_RUNTIME_HEAPTRC_LOG)',
    'native LZ4 runtime asserts zero unfreed blocks');
  CheckContains(LMakefile, 'compress-audit-native-lz4-runtime=pass',
    'native LZ4 runtime gate emits stable pass marker');
  CheckAbsent(LMakefile,
    'test: run native-compile native-runtime',
    'default audit test must not require system liblz4 runtime link');
  CheckAbsent(LMakefile,
    'audit-gate: test native-runtime',
    'default landing gate must not require optional native runtime proof');
  CheckContains(LReadme,
    'Native LZ4 audit is compile-only by default; run `make -C core/tests/nextpas.core.compress/test_compress_audit native-runtime` only on hosts with system liblz4 for runtime/link proof.',
    'docs state native LZ4 runtime evidence level');
  CheckContains(LReadme,
    'Native LZ4 runtime proof requires the development link name `liblz4.so`, not only a runtime `liblz4.so.1` shared object.',
    'docs state native LZ4 runtime proof needs development link name');
  CheckContains(LReadme,
    'When `pkg-config liblz4` is available, `native-runtime` uses that libdir for FPC linking and runtime shared-library lookup.',
    'docs state native LZ4 runtime pkg-config behavior');
end;

procedure TestNativeZlibCompileGateIsInAuditPath;
var
  LAudit: string;
  LMakefile: string;
  LZlibFfi: string;
begin
  LAudit := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/test_compress_audit.lpr');
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');
  LZlibFfi := ReadText('src/nextpas.core.compress.zlib.ffi.pas');

  CheckContains(LZlibFfi, 'NEXTPAS_USE_ZLIB_NATIVE',
    'zlib FFI unit documents native compile switch');
  CheckContains(LZlibFfi, 'function NativeZlibVersion',
    'zlib FFI unit exposes a compile verification entry point');
  CheckContains(LAudit, 'NativeZlibVersion',
    'audit program references native zlib verification entry point');
  CheckContains(LMakefile, 'ZLIB_NATIVE_COMPILE_FLAGS ?= -Cn -dNEXTPAS_USE_ZLIB_NATIVE',
    'audit Makefile compiles native zlib branch without running it');
  CheckContains(LMakefile, 'test: run native-compile zlib-native-compile',
    'audit test target includes native zlib compile-only gate');
  CheckContains(LMakefile, 'compress-audit-native-zlib-compile=pass',
    'native zlib compile gate emits stable pass marker');
end;

procedure TestNativeZlibRuntimeProofDocsAreExplicit;
var
  LReadme: string;
  LMakefile: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LReadme,
    '`make -C core/tests/nextpas.core.compress/test_compress_audit zlib-native-compile` only proves the native zlib branch compiles; the default audit gate does not provide native zlib runtime/link proof.',
    'docs state native zlib evidence level');
  CheckContains(LMakefile, 'ZLIB_NATIVE_RUNTIME_BUILD_DIR',
    'audit Makefile isolates native zlib runtime build artifacts');
  CheckContains(LMakefile, 'ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG',
    'audit Makefile stores native zlib runtime heaptrc output separately');
  CheckContains(LMakefile, 'ZLIB_NATIVE_RUNTIME_RUN_LOG',
    'audit Makefile stores native zlib runtime program output separately');
  CheckContains(LMakefile,
    'ZLIB_NATIVE_RUNTIME_HEAPTRC_ENV ?= HEAPTRC=log=$(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG)',
    'native zlib runtime directs heaptrc to an explicit log file');
  CheckContains(LMakefile, 'ZLIB_NATIVE_RUNTIME_FLAGS ?= -dNEXTPAS_USE_ZLIB_NATIVE',
    'audit Makefile exposes native zlib link/runtime flags');
  CheckContains(LMakefile, 'zlib-native-runtime:',
    'audit Makefile exposes optional native zlib runtime target');
  CheckContains(LMakefile, 'rm -f $(ZLIB_NATIVE_RUNTIME_RUN_LOG) $(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG)',
    'native zlib runtime clears stale logs before leak proof');
  CheckContains(LMakefile, '$(ZLIB_NATIVE_RUNTIME_HEAPTRC_ENV) $(ZLIB_NATIVE_RUNTIME_BUILD_DIR)/$(PROGRAM) > $(ZLIB_NATIVE_RUNTIME_RUN_LOG) 2>&1',
    'native zlib runtime captures program output separately from heaptrc');
  CheckContains(LMakefile, 'grep -F ''0 unfreed memory blocks'' $(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG)',
    'native zlib runtime asserts zero unfreed blocks');
  CheckContains(LMakefile, 'compress-audit-native-zlib-runtime=pass',
    'native zlib runtime gate emits stable pass marker');
  CheckAbsent(LMakefile,
    'test: run native-compile zlib-native-compile zlib-native-runtime',
    'default audit test must not require native zlib runtime link');
  CheckAbsent(LMakefile,
    'audit-gate: test zlib-native-runtime',
    'default landing gate must not require optional native zlib runtime proof');
  CheckContains(LReadme,
    'Run `make -C core/tests/nextpas.core.compress/test_compress_audit zlib-native-runtime` on hosts with system `libz.so` for native zlib runtime/link proof.',
    'docs state optional native zlib runtime proof command');
end;

procedure TestBenchmarkCompileGateIsInAuditPath;
var
  LReadme: string;
  LMakefile: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile, 'test: run native-compile zlib-native-compile benchmark-compile',
    'audit test target includes benchmark compile-only gate');
  CheckContains(LMakefile, 'benchmark-compile:',
    'audit Makefile exposes benchmark compile-only target');
  CheckContains(LMakefile, 'benchmarks/nextpas.core.compress/bench_compress build',
    'audit benchmark gate compiles current benchmark without running it');
  CheckContains(LMakefile, 'compress-benchmark-compile=pass',
    'benchmark compile gate emits stable pass marker');
  CheckContains(LReadme,
    'Audit gate compiles the benchmark only; run `make -C core/tests/nextpas.core.compress/test_compress_audit benchmark-run` for throughput evidence.',
    'docs state benchmark evidence level');
end;

procedure TestBenchmarkRunGateIsOptional;
var
  LReadme: string;
  LMakefile: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile, 'benchmark-run:',
    'audit Makefile exposes optional Pascal benchmark runtime target');
  CheckContains(LMakefile,
    'benchmarks/nextpas.core.compress/bench_compress run',
    'optional benchmark runtime target runs current Pascal benchmark');
  CheckContains(LMakefile, 'compress-benchmark-run=pass',
    'benchmark runtime gate emits stable pass marker');
  CheckMakefileTargetPrerequisiteAbsent(LMakefile, 'test', 'benchmark-run',
    'default audit test keeps Pascal benchmark runtime optional');
  CheckMakefileTargetPrerequisiteAbsent(LMakefile, 'audit-gate',
    'benchmark-run',
    'default audit-gate keeps Pascal benchmark runtime optional');
  CheckContains(LReadme,
    'run `make -C core/tests/nextpas.core.compress/test_compress_audit benchmark-run` for throughput evidence.',
    'docs route benchmark runtime proof through optional audit target');
end;

procedure TestGoComparatorCompileGateIsInAuditPath;
var
  LReadme: string;
  LMakefile: string;
  LGoComparator: string;
  LDeflateDecompressBench: string;
  LGzipDecompressBench: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');
  LGoComparator := ReadText(
    'benchmarks/nextpas.core.compress/bench_compress/compare_go/main.go');
  LDeflateDecompressBench := SliceBetween(LGoComparator,
    'func benchDeflateDecompress(data []byte)', 'func benchGzipCompress');
  LGzipDecompressBench := SliceBetween(LGoComparator,
    'func benchGzipDecompress(data []byte)', 'func main()');

  CheckContains(LGoComparator, 'zlib.NewWriter',
    'Go comparator uses zlib wrapper for Deflate benchmark parity');
  CheckContains(LGoComparator, 'gzip.NewWriter',
    'Go comparator includes Gzip benchmark parity');
  CheckContains(LGoComparator, 'func mustWrite(',
    'Go comparator checks compression writer errors before throughput');
  CheckContains(LGoComparator, 'func mustReadAll(',
    'Go comparator checks decompression reader errors before throughput');
  CheckContains(LGoComparator, 'bytes.Equal(data, decompressed)',
    'Go comparator validates decompressed bytes before reporting throughput');
  CheckBefore(LDeflateDecompressBench, 'mustMatch("Deflate", data, decompressed)',
    'start := time.Now()',
    'Go Deflate comparator validates decompressed bytes before timing');
  CheckBefore(LGzipDecompressBench, 'mustMatch("Gzip", data, decompressed)',
    'start := time.Now()',
    'Go Gzip comparator validates decompressed bytes before timing');
  CheckContains(LReadme,
    'The Go comparator source covers Deflate and Gzip only.',
    'docs state Go comparator algorithm coverage');
  CheckContains(LReadme,
    'Default audit uses `go test ./...` as a compile-check; run `make -C core/tests/nextpas.core.compress/test_compress_audit go-comparator-run` for Go throughput evidence.',
    'docs state Go comparator evidence level');
  Check(CompareGoDirectoryHasNoTestFiles,
    'Go comparator compile-check precondition has no Go test files');
  CheckContains(LMakefile, 'go-comparator-compile:',
    'audit Makefile exposes Go comparator compile target');
  CheckContains(LMakefile, 'go-comparator-run:',
    'audit Makefile exposes optional Go comparator runtime target');
  CheckContains(LMakefile, 'benchmarks/nextpas.core.compress/bench_compress/compare_go',
    'audit Makefile points at current Go comparator directory');
  CheckContains(LMakefile, 'go test ./...',
    'audit Makefile compiles Go comparator without running throughput benchmark');
  CheckContains(LMakefile, 'go run .',
    'audit Makefile can run Go comparator throughput benchmark on demand');
  CheckContains(LMakefile,
    'test: run native-compile zlib-native-compile benchmark-compile go-comparator-compile',
    'audit test target includes Go comparator compile proof');
  CheckAbsent(LMakefile,
    'test: run native-compile zlib-native-compile benchmark-compile go-comparator-compile go-comparator-run',
    'default audit test must not require Go comparator throughput runtime proof');
  CheckContains(LMakefile, 'compress-go-comparator-compile=pass',
    'Go comparator compile gate emits stable pass marker');
  CheckContains(LMakefile, 'compress-go-comparator-run=pass',
    'Go comparator runtime gate emits stable pass marker');
end;

procedure TestCompressExampleRunGateIsInAuditPath;
var
  LReadme: string;
  LMakefile: string;
  LExample: string;
begin
  LReadme := ReadText('docs/compress/README.md');
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');
  LExample := ReadText(
    'examples/nextpas.core.compress/compress_roundtrip/compress_roundtrip.lpr');

  CheckContains(LMakefile, 'example-run:',
    'audit Makefile exposes compress example run target');
  CheckContains(LMakefile,
    'examples/nextpas.core.compress/compress_roundtrip run',
    'audit gate runs current compress example');
  CheckContains(LMakefile, 'compress-example-run=pass',
    'compress example gate emits stable pass marker');
  CheckContains(LMakefile, 'example-native-compile:',
    'audit Makefile exposes native facade-only example compile target');
  CheckContains(LMakefile, 'compress-example-native-lz4-compile=pass',
    'native facade-only example compile gate emits stable pass marker');
  CheckContains(LMakefile,
    'test: run native-compile zlib-native-compile benchmark-compile go-comparator-compile example-run example-native-compile heaptrc',
    'audit test target includes compress example run and native compile proof');
  CheckContains(LExample, 'compress-roundtrip-status=pass',
    'compress example emits stable pass marker');
  CheckContains(LExample, 'DeflateDecompressWithMaxOutputSize',
    'compress example covers bounded Deflate helper');
  CheckContains(LExample, 'GzipDecompressWithMaxOutputSize',
    'compress example covers bounded Gzip helper');
  CheckContains(LExample, 'Lz4DecompressWithMaxOutputSize',
    'compress example covers bounded LZ4 helper');
  CheckContains(LExample, 'Lz4CompressBound',
    'compress example covers root facade LZ4 bound helper');
  CheckAbsent(LExample, 'DeflateWriter',
    'compress example does not cover Deflate streaming writer');
  CheckAbsent(LExample, 'DeflateReader',
    'compress example does not cover Deflate streaming reader');
  CheckAbsent(LExample, 'GzipWriter',
    'compress example does not cover Gzip streaming writer');
  CheckAbsent(LExample, 'GzipReader',
    'compress example does not cover Gzip streaming reader');
  CheckContains(LReadme,
    'The runnable example covers one-shot and bounded facade helpers; streaming snippets are contract-tested by the audit gate, not by the example.',
    'docs state runnable example scope');
end;

procedure TestHeaptrcGateIsInAuditPath;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile, 'heaptrc:',
    'audit Makefile exposes heaptrc target');
  CheckContains(LMakefile, 'HEAPTRC_LOG',
    'audit Makefile uses a fixed heaptrc log path');
  CheckContains(LMakefile, 'RUN_LOG',
    'audit Makefile uses a separate program output log path');
  CheckContains(LMakefile, 'HEAPTRC_ENV ?= HEAPTRC=log=$(HEAPTRC_LOG)',
    'audit Makefile directs heaptrc to an explicit log file');
  CheckContains(LMakefile, 'rm -f $(RUN_LOG) $(HEAPTRC_LOG)',
    'audit heaptrc target clears stale logs before leak proof');
  CheckContains(LMakefile, '0 unfreed memory blocks',
    'audit heaptrc target asserts zero unfreed blocks');
  CheckContains(LMakefile, 'compress-audit-heaptrc=pass',
    'audit heaptrc gate emits stable pass marker');
end;

procedure TestDocsContractGateIsInAuditPath;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile, 'docs-contract-run:',
    'audit Makefile exposes docs-contract target');
  CheckContains(LMakefile,
    'tests/nextpas.core.compress/test_compress_docs_contract test',
    'audit docs-contract target runs current docs contract');
  CheckContains(LMakefile,
    'test: run native-compile zlib-native-compile benchmark-compile go-comparator-compile example-run example-native-compile heaptrc docs-contract-run basic-test-run deep-test-run',
    'audit test target includes docs-contract and module runtime proof');
  CheckContains(LMakefile, 'compress-docs-contract-run=pass',
    'audit docs-contract gate emits stable pass marker');
end;

procedure TestAuditTestTargetIncludesHeaptrc;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile,
    'test: run native-compile zlib-native-compile benchmark-compile go-comparator-compile example-run example-native-compile heaptrc',
    'audit test target includes heaptrc proof');
  CheckContains(LMakefile, 'basic-test-run:',
    'audit Makefile exposes basic module test proxy');
  CheckContains(LMakefile, 'deep-test-run:',
    'audit Makefile exposes deep module test proxy');
  CheckContains(LMakefile,
    'tests/nextpas.core.compress/test_compress test',
    'audit Makefile runs basic module test gate');
  CheckContains(LMakefile,
    'tests/nextpas.core.compress/test_compress_deep test',
    'audit Makefile runs deep module test gate');
  CheckContains(LMakefile, 'compress-basic-test-run=pass',
    'audit basic module test proxy emits stable pass marker');
  CheckContains(LMakefile, 'compress-deep-test-run=pass',
    'audit deep module test proxy emits stable pass marker');
end;

procedure TestAuditLandingGateIncludesHeaptrc;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile, '.PHONY: build run test audit-gate',
    'audit Makefile exposes a named landing gate');
  CheckContains(LMakefile, 'audit-gate: test',
    'audit landing gate aliases runtime, compile-only, benchmark, and heaptrc proof');
end;

procedure TestAuditCleanCoversProxiedGates;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_audit/Makefile');

  CheckContains(LMakefile,
    'tests/nextpas.core.compress/test_compress_docs_contract clean',
    'audit clean proxies docs-contract gate cleanup');
  CheckContains(LMakefile,
    'benchmarks/nextpas.core.compress/bench_compress clean',
    'audit clean proxies benchmark gate cleanup');
end;

procedure TestDeepHeaptrcGateIsExplicit;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_deep/Makefile');

  CheckContains(LMakefile, 'HEAPTRC_LOG',
    'deep Makefile uses a fixed heaptrc log path');
  CheckContains(LMakefile, 'RUN_LOG',
    'deep Makefile uses a separate program output log path');
  CheckContains(LMakefile, 'HEAPTRC_ENV ?= HEAPTRC=log=$(HEAPTRC_LOG)',
    'deep Makefile directs heaptrc to an explicit log file');
  CheckContains(LMakefile, 'rm -f $(RUN_LOG) $(HEAPTRC_LOG)',
    'deep heaptrc target clears stale logs before leak proof');
  CheckContains(LMakefile, '.PHONY: build run test heaptrc clean',
    'deep Makefile exposes heaptrc as an explicit target');
  CheckContains(LMakefile, 'test: run heaptrc',
    'deep test target includes heaptrc proof');
  CheckContains(LMakefile, '0 unfreed memory blocks',
    'deep heaptrc target asserts zero unfreed blocks');
  CheckContains(LMakefile, 'compress-deep-heaptrc=pass',
    'deep heaptrc gate emits stable pass marker');
end;

procedure TestBasicHeaptrcGateIsExplicit;
var
  LMakefile: string;
begin
  LMakefile := ReadText('tests/nextpas.core.compress/test_compress/Makefile');

  CheckContains(LMakefile, 'HEAPTRC_LOG',
    'basic Makefile uses a fixed heaptrc log path');
  CheckContains(LMakefile, 'RUN_LOG',
    'basic Makefile uses a separate program output log path');
  CheckContains(LMakefile, 'HEAPTRC_ENV ?= HEAPTRC=log=$(HEAPTRC_LOG)',
    'basic Makefile directs heaptrc to an explicit log file');
  CheckContains(LMakefile, 'rm -f $(RUN_LOG) $(HEAPTRC_LOG)',
    'basic heaptrc target clears stale logs before leak proof');
  CheckContains(LMakefile, '.PHONY: build run test heaptrc clean',
    'basic Makefile exposes heaptrc as an explicit target');
  CheckContains(LMakefile, 'test: run heaptrc',
    'basic test target includes heaptrc proof');
  CheckContains(LMakefile, '0 unfreed memory blocks',
    'basic heaptrc target asserts zero unfreed blocks');
  CheckContains(LMakefile, 'compress-basic-heaptrc=pass',
    'basic heaptrc gate emits stable pass marker');
end;

procedure TestDocsContractHeaptrcGateIsExplicit;
var
  LMakefile: string;
begin
  LMakefile := ReadText(
    'tests/nextpas.core.compress/test_compress_docs_contract/Makefile');

  CheckContains(LMakefile, 'HEAPTRC_LOG',
    'docs-contract Makefile uses a fixed heaptrc log path');
  CheckContains(LMakefile, 'RUN_LOG',
    'docs-contract Makefile uses a separate program output log path');
  CheckContains(LMakefile, 'HEAPTRC_ENV ?= HEAPTRC=log=$(HEAPTRC_LOG)',
    'docs-contract Makefile directs heaptrc to an explicit log file');
  CheckContains(LMakefile, 'rm -f $(RUN_LOG) $(HEAPTRC_LOG)',
    'docs-contract heaptrc target clears stale logs before leak proof');
  CheckContains(LMakefile, '.PHONY: build run test heaptrc clean',
    'docs-contract Makefile exposes heaptrc as an explicit target');
  CheckContains(LMakefile, 'test: run heaptrc',
    'docs-contract test target includes heaptrc proof');
  CheckContains(LMakefile, '0 unfreed memory blocks',
    'docs-contract heaptrc target asserts zero unfreed blocks');
  CheckContains(LMakefile, 'compress-docs-contract-heaptrc=pass',
    'docs-contract heaptrc gate emits stable pass marker');
end;

begin
  T := TTestRunner.Create('nextpas.core.compress.docs-contract');
  T.Run('audit Makefile target parser rejects optional runtime',
    @TestAuditMakefileTargetPrerequisiteParserRejectsOptionalRuntime);
  T.Run('audit Makefile target prerequisites match gate policy',
    @TestAuditMakefileTargetPrerequisitesMatchGatePolicy);
  T.Run('compression level docs match source',
    @TestCompressionLevelDocsMatchSource);
  T.Run('facade example docs match current API',
    @TestFacadeExampleDocsMatchCurrentApi);
  T.Run('runnable compress example docs match files',
    @TestRunnableCompressExampleDocsMatchFiles);
  T.Run('supported formats table matches facade',
    @TestSupportedFormatsTableMatchesFacade);
  T.Run('Deflate format docs match source',
    @TestDeflateFormatDocsMatchSource);
  T.Run('Deflate interop note matches source',
    @TestDeflateInteropNoteMatchesSource);
  T.Run('Gzip cross-API audit contract',
    @TestGzipCrossApiAuditContract);
  T.Run('bounded Deflate docs match surface',
    @TestBoundedDeflateDocsMatchSurface);
  T.Run('Deflate invalid header contract matches audit',
    @TestDeflateInvalidHeaderContractMatchesAudit);
  T.Run('Gzip error model docs match audit',
    @TestGzipErrorModelDocsMatchAudit);
  T.Run('Gzip one-shot zlib state uses finally',
    @TestGzipOneShotZlibStateUsesFinally);
  T.Run('Gzip one-shot compression uses bounded allocation',
    @TestGzipOneShotCompressionUsesBoundedAllocation);
  T.Run('bounded Gzip docs match surface',
    @TestBoundedGzipDocsMatchSurface);
  T.Run('bounded output limit error docs match audit',
    @TestBoundedOutputLimitErrorDocsMatchAudit);
  T.Run('Gzip optional header errors match audit',
    @TestGzipOptionalHeaderErrorsMatchAudit);
  T.Run('Gzip trailer boundary matches audit',
    @TestGzipTrailerBoundaryMatchesAudit);
  T.Run('streaming lifecycle docs match contract',
    @TestStreamingLifecycleDocsMatchContract);
  T.Run('streaming docs show bounded readers for untrusted input',
    @TestStreamingDocsShowBoundedReadersForUntrustedInput);
  T.Run('streaming zlib avail narrowing matches source',
    @TestStreamingZlibAvailNarrowingMatchesSource);
  T.Run('streaming reader cap probe matches source',
    @TestStreamingReaderCapProbeMatchesSource);
  T.Run('Deflate pending corrupt read source contract',
    @TestDeflatePendingCorruptReadSourceContract);
  T.Run('Gzip pending corrupt read source contract',
    @TestGzipPendingCorruptReadSourceContract);
  T.Run('one-shot zlib width guards match source',
    @TestOneShotZlibWidthGuardsMatchSource);
  T.Run('one-shot inflate state cleanup matches source',
    @TestOneShotInflateStateCleanupMatchesSource);
  T.Run('bounded growth policy never exceeds cap',
    @TestBoundedGrowthPolicyNeverExceedsCap);
  T.Run('performance docs match current implementation',
    @TestPerformanceDocsMatchCurrentImplementation);
  T.Run('LZ4 native bound guard matches pure policy',
    @TestLz4NativeBoundGuardMatchesPurePolicy);
  T.Run('LZ4 native facade owner boundary',
    @TestLz4NativeFacadeOwnerBoundary);
  T.Run('LZ4 FFI unit is ABI-only and native owner boundary',
    @TestLz4FfiUnitIsAbiOnlyAndNativeOwnerBoundary);
  T.Run('LZ4 decode bound guard matches pure policy',
    @TestLz4DecodeBoundGuardMatchesPurePolicy);
  T.Run('LZ4 empty decode contract matches audit',
    @TestLz4EmptyDecodeContractMatchesAudit);
  T.Run('LZ4 raw block docs match frame guard',
    @TestLz4RawBlockDocsMatchFrameGuard);
  T.Run('LZ4 error model docs match audit',
    @TestLz4ErrorModelDocsMatchAudit);
  T.Run('LZ4 encoder block termination matches audit',
    @TestLz4EncoderBlockTerminationMatchesAudit);
  T.Run('native LZ4 compile gate is in audit path',
    @TestNativeLz4CompileGateIsInAuditPath);
  T.Run('native LZ4 runtime gate is optional',
    @TestNativeLz4RuntimeGateIsOptional);
  T.Run('native zlib compile gate is in audit path',
    @TestNativeZlibCompileGateIsInAuditPath);
  T.Run('native zlib runtime proof docs are explicit',
    @TestNativeZlibRuntimeProofDocsAreExplicit);
  T.Run('benchmark compile gate is in audit path',
    @TestBenchmarkCompileGateIsInAuditPath);
  T.Run('benchmark runtime gate is optional',
    @TestBenchmarkRunGateIsOptional);
  T.Run('Go comparator compile gate is in audit path',
    @TestGoComparatorCompileGateIsInAuditPath);
  T.Run('compress example run gate is in audit path',
    @TestCompressExampleRunGateIsInAuditPath);
  T.Run('heaptrc gate is in audit path',
    @TestHeaptrcGateIsInAuditPath);
  T.Run('docs-contract gate is in audit path',
    @TestDocsContractGateIsInAuditPath);
  T.Run('audit test target includes heaptrc',
    @TestAuditTestTargetIncludesHeaptrc);
  T.Run('audit landing gate includes heaptrc',
    @TestAuditLandingGateIncludesHeaptrc);
  T.Run('audit clean covers proxied gates',
    @TestAuditCleanCoversProxiedGates);
  T.Run('deep heaptrc gate is explicit',
    @TestDeepHeaptrcGateIsExplicit);
  T.Run('basic heaptrc gate is explicit',
    @TestBasicHeaptrcGateIsExplicit);
  T.Run('docs-contract heaptrc gate is explicit',
    @TestDocsContractHeaptrcGateIsExplicit);
  T.Summary;
end.
