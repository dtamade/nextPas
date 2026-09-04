unit nextpas.core.db.capprobe;

{** @desc L2 版本探针纯函数（V3-E）。零后端依赖，L1 语义。
       解析 ServerVersion 串为整数 `major*10000 + minor*100 + patch`，
       与 pg `server_version_num` 同构；能力探针仅按整数阈值判断，
       扩展存在性由调用方传入（HasExtension）。
       Bulk single-source honesty: SupportsBulkCopy via ProbeSupportsBulkCopy
       (universal 5/6 true pre-probe even at ServerVersion 0, redis false) single-source；COPY BINARY fast-path
       via ProbeBulkCopy/ProbeCopyBinary (PG≥140000, 0→false honest isolated) single-source；reuse
       DbBulkEscape/TDbBulkBuffer + InTransaction branching preserved via
       db.bulk，0 SysUtils, heaptrc0。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf;

{** 解析版本串为整数。接受 "17.1" "8.0.33" "3.46.0" 等，忽略后缀
    "-beta" 等非数字尾。失败返回 0。 *}
function ParseServerVersion(const AVersion: string): Integer; inline;

{** pgvector 是否可用：PG≥15 且扩展已装（HasExtension=true）。
    单独阈值，MariaDB/MySQL 的 VECTOR 另由 mysql 侧判定。 *}
function ProbeNativeVector(const AServerVersion: Integer;
  const AHasExtension: Boolean): Boolean; inline;

{** jsonb_path_query 是否可用：PG≥12 *}
function ProbeJsonPath(const AServerVersion: Integer): Boolean; inline;

{** multirange 是否可用：PG≥14 *}
function ProbeRangeTypes(const AServerVersion: Integer): Boolean; inline;

{** bulk copy 是否可用：PG-only PG≥14 COPY BINARY 高速路径阈值
    （ProbeBulkCopy/ProbeCopyBinary 0→false honest，≥140000→true，isolated from universal SupportsBulkCopy）。
    Universal 单事务批量 SupportsBulkCopy  via ProbeSupportsBulkCopy single-source
    (sqlite/pg/mysql/odbc/dm true pre-probe even at 0, redis false honest via Kind; 0 SysUtils, reuse DbBulkEscape/
    TDbBulkBuffer, InTransaction branching preserved via db.bulk). *}
function ProbeBulkCopy(const AServerVersion: Integer): Boolean; inline;
function ProbeCopyBinary(const AServerVersion: Integer): Boolean; inline;
function ProbeSupportsBulkCopy(const AKind: TDbKind): Boolean; inline; overload;
function ProbeSupportsBulkCopy(const AKind: TDbKind; const AServerVersion: Integer): Boolean; inline; overload;

{ ---- 门面探测薄转发单源（L2 owner，facade 纯聚合） ---- }
{ perf: inline 薄转发，bytes.ops 单源，零拷贝接口引用计数自动归还，try..finally 不丢 }
function DbProbeCapabilities(const AConn: IDbConnection): IDbCapabilities; inline;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.text.view;



function ParseServerVersion(const AVersion: string): Integer; inline;
var
  V, Candidate, Tok: TStringView;
  LRest, LToken: TStringView;
  P: PtrInt;
  I: SizeUInt;
  C: Byte;
  Major, Minor, Patch: Integer;
  SegVal: Integer;
  HasDigits, SegInvalid: Boolean;
  SegIdx: Integer;
  Qualified: Boolean;
begin
  Result := 0;
  // single-source trim via text.view (zero-copy view, no self ascii trim loop), bytes.ops sentinel
  V := TStringView.FromStr(AVersion).Trim;
  if V.IsEmpty then Exit;
  // verbose 版本串兼容：零拷贝 view 扫描首个以数字开头且仅含数字/'.'的 token（如 "PostgreSQL 17.1 on x86_64 ..." -> "17.1"），无 Part 拼接
  if V.IndexOf(' ') >= 0 then
  begin
    LRest := V;
    Qualified := False;
    while not LRest.IsEmpty do
    begin
      if LRest.SplitFirst(' ', LToken, LRest) then
        { LToken/LRest already split }
      else
      begin
        { 未命中时 SplitFirst 已置 LToken=剩余整体、LRest=空；勿再用 LRest 回盖 LToken }
        LRest := TStringView.Empty;
      end;
      LToken := LToken.Trim;
      if LToken.IsEmpty then Continue;
      // strip leading '(' without alloc (view Advance)
      while (LToken.Len > 0) and (LToken.Data[0] = '(') do
        LToken := LToken.Slice(1, LToken.Len - 1);
      // strip trailing ')', ',', ';'
      while (LToken.Len > 0) and ((LToken.Data[LToken.Len - 1] = ')') or (LToken.Data[LToken.Len - 1] = ',') or (LToken.Data[LToken.Len - 1] = ';')) do
        LToken := LToken.Slice(0, LToken.Len - 1);
      LToken := LToken.Trim;
      if LToken.IsEmpty then Continue;
      if not (Byte(LToken.Data[0]) in [48..57]) then Continue;
      Candidate := LToken;
      Tok := Candidate;
      P := Tok.IndexOf('-');
      if P >= 0 then Tok := Tok.Slice(0, SizeUInt(P));
      P := Tok.IndexOf('(');
      if P >= 0 then Tok := Tok.Slice(0, SizeUInt(P));
      Tok := Tok.Trim;
      if Tok.IsEmpty then Continue;
      // verify Tok only contains digits/dot single pass, zero-copy no linear scan per char via Pos
      Qualified := True;
      for I := 0 to Tok.Len - 1 do
      begin
        C := Byte(Tok.Data[I]);
        if not (((C >= 48) and (C <= 57)) or (C = Byte('.'))) then
        begin
          Qualified := False;
          Break;
        end;
      end;
      if not Qualified then Continue;
      V := Candidate;
      Break;
    end;
  end;
  P := V.IndexOf('-');
  if P >= 0 then V := V.Slice(0, SizeUInt(P));
  P := V.IndexOf('(');
  if P >= 0 then V := V.Slice(0, SizeUInt(P)).Trim;
  if V.IsEmpty then Exit(0);
  // 解析 major.minor.patch：零拷贝整数累加，无逐字符拼接 O(n²) 分配
  Major := 0; Minor := 0; Patch := 0;
  SegIdx := 0; SegVal := 0; HasDigits := False; SegInvalid := False;
  for I := 0 to V.Len do
  begin
    if (I = V.Len) or (Byte(V.Data[I]) = Byte('.')) then
    begin
      if SegInvalid or not HasDigits then
      begin
        if SegIdx = 0 then Major := 0 else if SegIdx = 1 then Minor := 0 else if SegIdx = 2 then Patch := 0;
      end else
      begin
        if SegIdx = 0 then Major := SegVal else if SegIdx = 1 then Minor := SegVal else if SegIdx = 2 then Patch := SegVal;
      end;
      SegVal := 0; HasDigits := False; SegInvalid := False;
      Inc(SegIdx);
      if SegIdx > 3 then Break;
    end
    else
    begin
      C := Byte(V.Data[I]);
      if (C >= 48) and (C <= 57) then
      begin
        if not SegInvalid then
          SegVal := SegVal * 10 + (C - 48);
        HasDigits := True;
      end else
        SegInvalid := True;
    end;
  end;
  Result := Major * 10000 + Minor * 100 + Patch;
end;

function ProbeNativeVector(const AServerVersion: Integer;
  const AHasExtension: Boolean): Boolean; inline;
begin
  if AServerVersion = 0 then Exit(False); // gateway/key-value honest 0→false
  Result := (AServerVersion >= 150000) and AHasExtension;
end;

function ProbeJsonPath(const AServerVersion: Integer): Boolean; inline;
begin
  if AServerVersion = 0 then Exit(False);
  Result := AServerVersion >= 120000;
end;

function ProbeRangeTypes(const AServerVersion: Integer): Boolean; inline;
begin
  if AServerVersion = 0 then Exit(False);
  Result := AServerVersion >= 140000;
end;

function ProbeBulkCopy(const AServerVersion: Integer): Boolean; inline;
begin
  if AServerVersion = 0 then Exit(False); // gateway/key-value honest 0→false, CONTRACT §2.22
  Result := AServerVersion >= 140000; // PG≥14 COPY BINARY threshold reserved
end;

function ProbeCopyBinary(const AServerVersion: Integer): Boolean; inline;
begin
  Result := ProbeBulkCopy(AServerVersion);
end;

function ProbeSupportsBulkCopy(const AKind: TDbKind): Boolean; inline;
begin
  Result := AKind in [dbkSqlite, dbkPostgres, dbkMysql, dbkOdbc, dbkDm];
end;

{$PUSH}{$HINTS OFF}
function ProbeSupportsBulkCopy(const AKind: TDbKind; const AServerVersion: Integer): Boolean; inline;
begin
  // CONTRACT §2.22 5/6 universal true intentionally ignores version (sqlite ParseSqlite libversion, pg/mysql/odbc lazy ProductVersion early window stays true)
  Result := ProbeSupportsBulkCopy(AKind);
end;
{$POP}

function DbProbeCapabilities(const AConn: IDbConnection): IDbCapabilities; inline;
begin
  // perf: inline 薄转发，bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE，零拷贝接口引用计数自动归还，nil 安全
  Result := nil;
  if AConn = nil then Exit;
  Supports(AConn, IDbCapabilities, Result);
end;

end.
