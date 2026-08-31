unit nextpas.core.db.capprobe;

{** @desc L2 版本探针纯函数（V3-E）。零后端依赖，L1 语义。
       解析 ServerVersion 串为整数 `major*10000 + minor*100 + patch`，
       与 pg `server_version_num` 同构；能力探针仅按整数阈值判断，
       扩展存在性由调用方传入（HasExtension）。
       Bulk single-source honesty: SupportsBulkCopy via ProbeSupportsBulkCopy
       (universal 5/6 true, redis false) single-source；COPY BINARY fast-path
       via ProbeBulkCopy/ProbeCopyBinary (PG≥140000) single-source；reuse
       DbBulkEscape/TDbBulkBuffer + InTransaction branching preserved via
       db.bulk，0 SysUtils, heaptrc0。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base;

{** 解析版本串为整数。接受 "17.1" "8.0.33" "3.46.0" 等，忽略后缀
    "-beta" 等非数字尾。失败返回 0。 *}
function ParseServerVersion(const AVersion: string): Integer;

{** pgvector 是否可用：PG≥15 且扩展已装（HasExtension=true）。
    单独阈值，MariaDB/MySQL 的 VECTOR 另由 mysql 侧判定。 *}
function ProbeNativeVector(const AServerVersion: Integer;
  const AHasExtension: Boolean): Boolean;

{** jsonb_path_query 是否可用：PG≥12 *}
function ProbeJsonPath(const AServerVersion: Integer): Boolean;

{** multirange 是否可用：PG≥14 *}
function ProbeRangeTypes(const AServerVersion: Integer): Boolean;

{** bulk copy 是否可用：PG-only PG≥14 COPY BINARY 高速路径阈值
    （ProbeBulkCopy/ProbeCopyBinary 0→false honest，≥140000→true）。
    Universal 单事务批量 SupportsBulkCopy  via ProbeSupportsBulkCopy single-source
    (sqlite/pg/mysql/odbc/dm true, redis false; 0 SysUtils, reuse DbBulkEscape/
    TDbBulkBuffer, InTransaction branching preserved via db.bulk). *}
function ProbeBulkCopy(const AServerVersion: Integer): Boolean;
function ProbeCopyBinary(const AServerVersion: Integer): Boolean;
function ProbeSupportsBulkCopy(const AKind: TDbKind): Boolean; overload;
function ProbeSupportsBulkCopy(const AKind: TDbKind; const AServerVersion: Integer): Boolean; overload;

implementation

function TrimAscii(const S: string): string;
var I, J: Integer;
begin
  I := 1; J := Length(S);
  while (I <= J) and (S[I] in [#9, #10, #13, ' ']) do Inc(I);
  while (J >= I) and (S[J] in [#9, #10, #13, ' ']) do Dec(J);
  if I > J then Result := '' else Result := Copy(S, I, J - I + 1);
end;

function LastDelimiterAscii(const ADelim, S: string): Integer;
var I: Integer;
begin
  Result := 0;
  for I := Length(S) downto 1 do
    if Pos(S[I], ADelim) > 0 then Exit(I);
end;

function ParseServerVersion(const AVersion: string): Integer;
var
  S, Part, Tok: string;
  P, Code, Major, Minor, Patch: Integer;
  I, N, Start, Len: Integer;
begin
  Result := 0;
  S := TrimAscii(AVersion);
  if S = '' then Exit;
  // verbose 版本串兼容：扫描首个以数字开头且仅含数字/'.'的 token（如 "PostgreSQL 17.1 on x86_64 ..." -> "17.1"）
  if Pos(' ', S) > 0 then
  begin
    Start := 1;
    Len := Length(S);
    for I := 1 to Len + 1 do
    begin
      if (I > Len) or (S[I] = ' ') then
      begin
        if I > Start then
        begin
          Part := TrimAscii(Copy(S, Start, I - Start));
          while (Length(Part) > 0) and (Part[1] = '(') do
            Part := Copy(Part, 2, MaxInt);
          while (Length(Part) > 0) and (Part[Length(Part)] in [')', ',', ';']) do
            Part := Copy(Part, 1, Length(Part) - 1);
          Part := TrimAscii(Part);
          if (Length(Part) > 0) and (Part[1] in ['0'..'9']) then
          begin
            Tok := Part;
            P := Pos('-', Tok);
            if P > 0 then Tok := Copy(Tok, 1, P - 1);
            P := Pos('(', Tok);
            if P > 0 then Tok := Copy(Tok, 1, P - 1);
            Tok := TrimAscii(Tok);
            if Tok <> '' then
            begin
              P := 1;
              while (P <= Length(Tok)) and (Tok[P] in ['0'..'9', '.']) do Inc(P);
              if P > Length(Tok) then
              begin
                S := Part;
                Break;
              end;
            end;
          end;
        end;
        Start := I + 1;
      end;
    end;
  end;
  P := Pos('-', S);
  if P > 0 then S := Copy(S, 1, P-1);
  P := Pos('(', S);
  if P > 0 then S := TrimAscii(Copy(S, 1, P-1));
  // 解析 major.minor.patch
  Major := 0; Minor := 0; Patch := 0;
  N := 0;
  Part := '';
  for I := 1 to Length(S) + 1 do
  begin
    if (I > Length(S)) or (S[I] = '.') then
    begin
      Val(Part, Code, Code);
      if N = 0 then Val(Part, Major, Code)
      else if N = 1 then Val(Part, Minor, Code)
      else if N = 2 then Val(Part, Patch, Code);
      if Code <> 0 then
      begin
        // 非数字片段按 0 处理
        if N = 0 then Major := 0
        else if N = 1 then Minor := 0
        else Patch := 0;
      end;
      Part := '';
      Inc(N);
      if N > 3 then Break;
    end
    else
      Part := Part + S[I];
  end;
  Result := Major * 10000 + Minor * 100 + Patch;
end;

function ProbeNativeVector(const AServerVersion: Integer;
  const AHasExtension: Boolean): Boolean;
begin
  if AServerVersion = 0 then Exit(False); // gateway/key-value honest 0→false
  Result := (AServerVersion >= 150000) and AHasExtension;
end;

function ProbeJsonPath(const AServerVersion: Integer): Boolean;
begin
  if AServerVersion = 0 then Exit(False);
  Result := AServerVersion >= 120000;
end;

function ProbeRangeTypes(const AServerVersion: Integer): Boolean;
begin
  if AServerVersion = 0 then Exit(False);
  Result := AServerVersion >= 140000;
end;

function ProbeBulkCopy(const AServerVersion: Integer): Boolean;
begin
  if AServerVersion = 0 then Exit(False); // gateway/key-value honest 0→false, CONTRACT §2.22
  Result := AServerVersion >= 140000; // PG≥14 COPY BINARY threshold reserved
end;

function ProbeCopyBinary(const AServerVersion: Integer): Boolean;
begin
  Result := ProbeBulkCopy(AServerVersion);
end;

function ProbeSupportsBulkCopy(const AKind: TDbKind): Boolean;
begin
  Result := AKind in [dbkSqlite, dbkPostgres, dbkMysql, dbkOdbc, dbkDm];
end;

function ProbeSupportsBulkCopy(const AKind: TDbKind; const AServerVersion: Integer): Boolean;
begin
  if AKind = dbkRedis then Exit(False);
  // gateway 0 honest but odbc universal still true via Kind single-source (honest luxury removed)
  if AServerVersion = 0 then Exit(AKind = dbkOdbc);
  Result := ProbeSupportsBulkCopy(AKind);
end;

end.
