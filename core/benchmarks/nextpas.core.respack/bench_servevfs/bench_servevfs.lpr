program bench_servevfs;
{$I nextpas.core.settings.inc}
{** @desc S5 基准：ServeVfs handler 直调的每响应开销，三后端横向对比。
    embedded（respack blob 零拷贝窗口）/ memtree（内存树）/ os（真盘 tmpdir），
    内容源为同一棵 65 文件树；差值即 IVfs 定位+读源成本。
    另测 206 定位读与 404 miss 两形态。数字记入 respack README「嵌入载体」节。 }
uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.vfs,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.respack;

const
  FILE_COUNT = 64;
  FILE_SIZE = 4 * 1024;
  BENCH_FILE = 'assets/file0000.bin';
  RANGE_HDR = 'bytes=0-255';
  INDEX_BODY = '<!doctype html><html><body>servevfs bench</body></html>';
  { budgets: README 7.0µs/16.3µs measured, 800ms suite budget text → code gate 5× headroom }
  BUDGET_EMBEDDED_NS = 35000;
  BUDGET_MEMTREE_NS = 35000;
  BUDGET_OS_NS = 80000;
  BUDGET_RANGE_NS = 35000;
  BUDGET_MISS_NS = 35000;

type
  { 最小请求桩：ServeVfs 只触 Path/PathParam/GetHeaders }
  TBenchRequest = class(TInterfacedObject, IHttpRequest)
  private
    FPath: string;
    FPathParam: string;
    FHeaders: IHttpHeaders;
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetTrailers: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetRemoteAddr: string;
    function GetRemoteIp: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
  public
    constructor Create(const ARelative, ARange: string);
  end;

  { 响应记录器：计数不落网络 }
  TBenchRecorder = class(TInterfacedObject, IHttpResponseWriter)
  private
    FStatus: UInt16;
    FHeaders: IHttpHeaders;
    FBytes: Int64;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Status: UInt16 read FStatus;
    property BodyBytes: Int64 read FBytes;
  end;

var
  GEmbedded, GMemtree, GOs: IVfs;
  GHEmbedded, GHMemtree, GHOs: THttpHandlerFunc;
  GFullReq, GRangeReq, GMissReq: IHttpRequest;
  GOsDir: string;

{ ── 工具 ── }

function StrBytes(const S: string): TBytes;
var
  LI: SizeInt;
begin
  SetLength(Result, Length(S));
  for LI := 1 to Length(S) do
    Result[LI - 1] := Byte(Ord(S[LI]));
end;

function Fnv1a32(const AData: TBytes): UInt32;
const
  OFFSET = UInt32(2166136261);
  PRIME = UInt32(16777619);
var
  LI: SizeInt;
begin
  Result := OFFSET;
  for LI := 0 to Length(AData) - 1 do
    Result := (Result xor UInt32(AData[LI])) * PRIME;
end;

function ZeroPad4(AVal: Integer): string;
var
  LName: string;
  LJ: Integer;
begin
  Str(AVal: 4, LName);
  for LJ := 1 to Length(LName) do
    if LName[LJ] = ' ' then
      LName[LJ] := '0';
  Result := LName;
end;

procedure Expect(const ACond: Boolean; const AMsg: string);
begin
  if not ACond then
    raise Exception.Create('bench: ' + AMsg);
end;

{ ── 请求桩 ── }

constructor TBenchRequest.Create(const ARelative, ARange: string);
begin
  inherited Create;
  FPath := '/assets/' + ARelative;
  FPathParam := ARelative;
  FHeaders := NewHttpHeaders;
  if ARange <> '' then
    FHeaders.SetHeader('range', ARange);
end;

function TBenchRequest.GetMethod: THttpMethod;
begin
  Result := hmGet;
end;

function TBenchRequest.GetUrl: TUrl;
begin
  Result := Default(TUrl);
end;

function TBenchRequest.GetPath: string;
begin
  Result := FPath;
end;

function TBenchRequest.GetRawQuery: string;
begin
  Result := '';
end;

function TBenchRequest.GetVersion: THttpVersion;
begin
  Result := hvHttp11;
end;

function TBenchRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TBenchRequest.GetTrailers: IHttpHeaders;
begin
  Result := nil;
end;

function TBenchRequest.GetBody: IReader;
begin
  Result := nil;
end;

function TBenchRequest.GetContentLength: Int64;
begin
  Result := 0;
end;

function TBenchRequest.GetRemoteAddr: string;
begin
  Result := '127.0.0.1';
end;

function TBenchRequest.GetRemoteIp: string;
begin
  Result := '127.0.0.1';
end;

function TBenchRequest.PathParam(const AName: string): string;
begin
  if AName = 'filepath' then
    Result := FPathParam
  else
    Result := '';
end;

function TBenchRequest.QueryParam(const AName: string): string;
begin
  Result := '';
end;

{ ── 响应记录器 ── }

constructor TBenchRecorder.Create;
begin
  inherited Create;
  FHeaders := NewHttpHeaders;
end;

procedure TBenchRecorder.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
end;

function TBenchRecorder.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TBenchRecorder.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TBenchRecorder.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Inc(FBytes, Int64(ACount));
  Result := ACount;
end;

procedure TBenchRecorder.Flush;
begin
end;

{ ── 载荷与三后端装配 ── }

procedure SetupBackends;
var
  LIndexData: TBytes;
  LContents: array of TBytes;
  LItems: array of TVfsMemEntry;
  LEntries: array of TResPackInputEntry;
  LBlob: TResPackBlob;
  LI, LJ: Integer;
begin
  LIndexData := StrBytes(INDEX_BODY);
  SetLength(LContents, FILE_COUNT);
  for LI := 0 to FILE_COUNT - 1 do
  begin
    SetLength(LContents[LI], FILE_SIZE);
    for LJ := 0 to FILE_SIZE - 1 do
      LContents[LI][LJ] := Byte((LJ * 31 + LI * 7) mod 251);
  end;

  { memtree：条目带 fnv32，贴近 rp_pack 产物形态 }
  SetLength(LItems, FILE_COUNT + 1);
  LItems[0].Name := 'index.html';
  LItems[0].Data := LIndexData;
  LItems[0].ModTime := 1700000000;
  LItems[0].Hash := Fnv1a32(LIndexData);
  for LI := 0 to FILE_COUNT - 1 do
  begin
    LItems[LI + 1].Name := 'assets/file' + ZeroPad4(LI) + '.bin';
    LItems[LI + 1].Data := LContents[LI];
    LItems[LI + 1].ModTime := 1700000000;
    LItems[LI + 1].Hash := Fnv1a32(LContents[LI]);
  end;
  GMemtree := CreateMemTreeVfs(LItems);

  { embedded：respack blob（默认 Hashes=True），VFS 持有 blob 所有权 }
  SetLength(LEntries, FILE_COUNT + 1);
  LEntries[0].Path := 'index.html';
  LEntries[0].Data := @LIndexData[0];
  LEntries[0].DataSize := SizeUInt(Length(LIndexData));
  LEntries[0].ModTime := 1700000000;
  for LI := 0 to FILE_COUNT - 1 do
  begin
    LEntries[LI + 1].Path := 'assets/file' + ZeroPad4(LI) + '.bin';
    LEntries[LI + 1].Data := @LContents[LI][0];
    LEntries[LI + 1].DataSize := SizeUInt(FILE_SIZE);
    LEntries[LI + 1].ModTime := 1700000000;
  end;
  LBlob := ResPackBuild(LEntries, ResPackDefaultOptions);
  GEmbedded := CreateEmbeddedVfs(LBlob.Data, LBlob.Size, True);

  { os：同一棵树落到真实盘 }
  GOsDir := GetTempDir + '/rp-bench-servevfs';
  RemoveAll(GOsDir);
  MkdirAll(GOsDir + '/assets');
  WriteFile(GOsDir + '/index.html', LIndexData);
  for LI := 0 to FILE_COUNT - 1 do
    WriteFile(GOsDir + '/assets/file' + ZeroPad4(LI) + '.bin', LContents[LI]);
  GOs := CreateOsVfs(GOsDir);
end;

{ ── 基准体 ── }

procedure BenchEmbFull(const ACtx: IBenchContext);
var
  LRec: TBenchRecorder;
begin
  LRec := TBenchRecorder.Create;
  GHEmbedded(GFullReq, LRec);
  if LRec.Status <> 200 then
    raise Exception.Create('bench: embedded full request failed');
  ACtx.SetBytes(LRec.BodyBytes);
end;

procedure BenchMemFull(const ACtx: IBenchContext);
var
  LRec: TBenchRecorder;
begin
  LRec := TBenchRecorder.Create;
  GHMemtree(GFullReq, LRec);
  if LRec.Status <> 200 then
    raise Exception.Create('bench: memtree full request failed');
  ACtx.SetBytes(LRec.BodyBytes);
end;

procedure BenchOsFull(const ACtx: IBenchContext);
var
  LRec: TBenchRecorder;
begin
  LRec := TBenchRecorder.Create;
  GHOs(GFullReq, LRec);
  if LRec.Status <> 200 then
    raise Exception.Create('bench: os full request failed');
  ACtx.SetBytes(LRec.BodyBytes);
end;

procedure BenchEmbRange(const ACtx: IBenchContext);
var
  LRec: TBenchRecorder;
begin
  LRec := TBenchRecorder.Create;
  GHEmbedded(GRangeReq, LRec);
  if LRec.Status <> 206 then
    raise Exception.Create('bench: embedded range request failed');
  ACtx.SetBytes(LRec.BodyBytes);
end;

procedure BenchEmbMiss(const ACtx: IBenchContext);
var
  LRec: TBenchRecorder;
begin
  LRec := TBenchRecorder.Create;
  GHEmbedded(GMissReq, LRec);
  if LRec.Status <> 404 then
    raise Exception.Create('bench: embedded miss request failed');
end;

procedure CheckBudgetThresholds(const AResults: IBenchResults);
var
  R: TBenchResult;
  REmb, ROs: TBenchResult;
  Ratio: Double;
begin
  R := AResults.GetByName('servevfs/embedded/200-full-4k');
  if R.NsPerOp > BUDGET_EMBEDDED_NS then
    raise Exception.CreateFmt('budget exceeded embedded/200-full: %.0f > %d ns/op', [R.NsPerOp, BUDGET_EMBEDDED_NS]);
  REmb := R;
  R := AResults.GetByName('servevfs/memtree/200-full-4k');
  if R.NsPerOp > BUDGET_MEMTREE_NS then
    raise Exception.CreateFmt('budget exceeded memtree/200-full: %.0f > %d ns/op', [R.NsPerOp, BUDGET_MEMTREE_NS]);
  R := AResults.GetByName('servevfs/os/200-full-4k');
  if R.NsPerOp > BUDGET_OS_NS then
    raise Exception.CreateFmt('budget exceeded os/200-full: %.0f > %d ns/op', [R.NsPerOp, BUDGET_OS_NS]);
  ROs := R;
  // ratio gate locks README 2.3× claim (embedded zero-copy window vs os stat/open)
  if (REmb.NsPerOp > 0) and (ROs.NsPerOp > 0) then
  begin
    Ratio := ROs.NsPerOp / REmb.NsPerOp;
    if (Ratio < 1.5) or (Ratio > 4.0) then
      raise Exception.CreateFmt('budget exceeded os/embedded ratio %.2f outside [1.5,4.0] (README 2.3x)', [Ratio]);
    WriteLn('ratio: os/embedded=', Ratio:0:2, 'x');
  end;
  R := AResults.GetByName('servevfs/embedded/206-range');
  if R.NsPerOp > BUDGET_RANGE_NS then
    raise Exception.CreateFmt('budget exceeded embedded/206-range: %.0f > %d ns/op', [R.NsPerOp, BUDGET_RANGE_NS]);
  R := AResults.GetByName('servevfs/embedded/404-miss');
  if R.NsPerOp > BUDGET_MISS_NS then
    raise Exception.CreateFmt('budget exceeded embedded/404-miss: %.0f > %d ns/op', [R.NsPerOp, BUDGET_MISS_NS]);
  WriteLn('budget: all 5 within threshold (embedded ', BUDGET_EMBEDDED_NS, ' os ', BUDGET_OS_NS, ' ns/op)');
end;

{ 计时区外的正确性首验：任何一项语义漂移直接失败，不让基准测错误路径 }
procedure VerifySmoke;
var
  LRec: TBenchRecorder;
begin
  LRec := TBenchRecorder.Create;
  GHEmbedded(GFullReq, LRec);
  Expect((LRec.Status = 200) and (LRec.BodyBytes = FILE_SIZE),
    'embedded full should be 200 x 4KiB');

  LRec := TBenchRecorder.Create;
  GHMemtree(GFullReq, LRec);
  Expect((LRec.Status = 200) and (LRec.BodyBytes = FILE_SIZE),
    'memtree full should be 200 x 4KiB');

  LRec := TBenchRecorder.Create;
  GHOs(GFullReq, LRec);
  Expect((LRec.Status = 200) and (LRec.BodyBytes = FILE_SIZE),
    'os full should be 200 x 4KiB');

  LRec := TBenchRecorder.Create;
  GHEmbedded(GRangeReq, LRec);
  Expect((LRec.Status = 206) and (LRec.BodyBytes = 256),
    'embedded range should be 206 x 256B');

  LRec := TBenchRecorder.Create;
  GHEmbedded(GMissReq, LRec);
  Expect(LRec.Status = 404, 'embedded miss should be 404');
end;

begin
  try
    SetupBackends;
    GHEmbedded := ServeVfs(GEmbedded);
    GHMemtree := ServeVfs(GMemtree);
    GHOs := ServeVfs(GOs);
    GFullReq := TBenchRequest.Create(BENCH_FILE, '');
    GRangeReq := TBenchRequest.Create(BENCH_FILE, RANGE_HDR);
    GMissReq := TBenchRequest.Create('assets/nope.bin', '');
    VerifySmoke;

    WriteLn('=== servevfs handler-direct benchmark ===');
    WriteLn('payload: ', FILE_COUNT + 1, ' entries; full=4KiB, range=256B');
    WriteLn;
    CheckBudgetThresholds(
      TBenchSuite.Create('servevfs')
        .SetWarmupIters(50)
        .SetMinSamples(15)
        .SetMaxIterations(20000)
        .SetMinDuration(TDuration.FromMilliseconds(300))
        .Add('servevfs/embedded/200-full-4k', @BenchEmbFull)
        .Add('servevfs/memtree/200-full-4k', @BenchMemFull)
        .Add('servevfs/os/200-full-4k', @BenchOsFull)
        .Add('servevfs/embedded/206-range', @BenchEmbRange)
        .Add('servevfs/embedded/404-miss', @BenchEmbMiss)
        .Run);

    RemoveAll(GOsDir);
  except
    on E: Exception do
    begin
      WriteLn('bench: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
