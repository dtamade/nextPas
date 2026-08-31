unit nextpas.core.db.bulk;

{** @desc BulkCopy 缓冲复用（V4.3+）：5 后端共用的表/列/行缓冲与校验。
       零后端依赖（仅 db.base 的 TDbKind/EDbError/DbBulk* 文本单源），L3 家族复用件（依托 db.base/text.sql 单源），
       零 SysUtils，PAnsiChar 预估+DbBulkWrite* 单遍直写（零 LCap 双扫，无 L1 builder 直引）。
       适配器各持一份实例，BeginCopy/WriteRow/AbortCopy 委托本缓冲，
       EndCopy 的事务分支与 Exec 通道仍由适配器自管（事务模型各异）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base;

type
  TDbBulkRows = array of array of string;

  TDbBulkBuffer = record
  private
    FTable: string;
    FCols: array of string;
    FRows: TDbBulkRows;
    FRowCount: Integer;
    FActive: Boolean;
  public
    procedure Clear;
    procedure BeginCopy(const ATable: string; const AColumns: array of string); overload;
    procedure BeginCopy(const ATable: string; const AColumns: array of string; const AExpectedRows: Integer); overload;
    procedure BeginCopy(const ABackend: TDbKind; const ATable: string; const AColumns: array of string); overload;
    procedure BeginCopy(const ABackend: TDbKind; const ATable: string; const AColumns: array of string; const AExpectedRows: Integer); overload;
    procedure WriteRow(const ABackend: TDbKind; const AValues: array of string);
    function IsActive: Boolean; inline;
    function TableName: string; inline;
    function Columns: TDbStringArray; inline;
    function Rows: TDbBulkRows; inline;
    function ColumnCount: Integer; inline;
    function RowCount: Integer; inline;
  end;

  { 语句缓存容量与 Bulk fallback 单源于 db.base（接口默认值可见性要求） }

{ Bulk text single-source via nextpas.core.text.sql (SqlEscape/SqlQuoteIdent single scan, 0 SysUtils).
  薄包装转译 ESqlError/通用异常为 EDbError 指定 Backend，零 SysUtils。 }
function DbBulkEscape(const S: string): string; overload;
function DbBulkEscape(const S: string; const ABackend: TDbKind): string; overload;
function DbBulkEscapeLen(const S: string): Integer; overload;
function DbBulkEscapeLen(const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkWriteEscape(Dst: PAnsiChar; const S: string): Integer; overload;
function DbBulkWriteEscape(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkQuoteIdent(const AIdent: string): string; overload;
function DbBulkQuoteIdent(const AIdent: string; const ABackend: TDbKind): string; overload;
function DbBulkQuotedIdentLen(const AIdent: string): Integer; overload;
function DbBulkQuotedIdentLen(const AIdent: string; const ABackend: TDbKind): Integer; overload;
function DbBulkWriteQuotedIdent(Dst: PAnsiChar; const S: string): Integer; overload;
function DbBulkWriteQuotedIdent(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload;
procedure DbBulkValidateIdent(const ABackend: TDbKind; const AIdent: string);
function DbBulkLiteralNull: string; inline;
function DbBulkLiteralText(const S: string): string; overload;
function DbBulkLiteralText(const S: string; const ABackend: TDbKind): string; overload;
function DbBulkLiteralTextLen(const S: string): Integer; overload;
function DbBulkLiteralTextLen(const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkWriteLiteralText(Dst: PAnsiChar; const S: string): Integer; overload;
function DbBulkWriteLiteralText(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer; overload;
function DbBulkLiteralBlob(const ABytes: array of Byte): string;
function DbBulkCheckNul(const S: string): Integer; overload;
function DbBulkCheckNul(const S: string; const ABackend: TDbKind): Integer; overload;

{ SQL stitch helpers (V4.3 reuse close): ColList/ValList/INSERT built once }
function DbBulkColList(const ACols: TDbStringArray): string;
function DbBulkValList(const ARow: array of string): string;
function DbBulkInsertSql(const ATable, AColList: string; const ARow: array of string): string;
function DbBulkMultiInsertSql(const ATable: string; const ACols: TDbStringArray;
  const ARows: TDbBulkRows; const AFrom, ACount: Integer): string;
{ Chunk sizing derived from MaxPlaceholders (conservative 999) and column count }
function DbBulkChunkRows(const AMaxPlaceholders, AColumnCount, ARowCount: Integer): Integer;

{ Flush helper: single-source for InTransaction branching (avoid 5× duplicate loops). 0 SysUtils. }
type
  TDbBulkExecProc = procedure(const ASql: string) of object;
  TDbBulkBeginProc = procedure(const AImmediate: Boolean) of object;
  TDbBulkTxnProc = procedure of object;
procedure DbBulkFlushChunked(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const AChunkRows: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc);
{ Buffer-level wrapper: collapses 4× identical LCols/LRows/LChunk/Flush stanza
  (sqlite/odbc/mysql/dm) into single TDbBulkBuffer call. Keeps InTransaction
  branching inside DbBulkFlushChunked; chunk derived from MaxPlaceholders. }
procedure DbBulkFlushBuffer(
  const ABuffer: TDbBulkBuffer;
  const AMaxPlaceholders: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc);

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.sql;

function DbBulkEscape(const S: string): string;
begin
  Result := DbBulkEscape(S, dbkUnknown);
end;

function DbBulkEscape(const S: string; const ABackend: TDbKind): string;
begin
  try
    Result := SqlEscape(S);
  except
    on E: EDbError do
      if E.Backend = dbkUnknown then
        raise EDbError.CreateWithCategory(ABackend, E.Category, E.Constraint, E.Message)
      else raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkQuoteIdent(const AIdent: string): string;
begin
  Result := DbBulkQuoteIdent(AIdent, dbkUnknown);
end;

function DbBulkQuoteIdent(const AIdent: string; const ABackend: TDbKind): string;
begin
  try
    Result := SqlQuoteIdent(AIdent);
  except
    on E: EDbError do
      if E.Backend = dbkUnknown then
        raise EDbError.CreateWithCategory(ABackend, E.Category, E.Constraint, E.Message)
      else raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkLiteralNull: string;
begin
  Result := 'NULL';
end;

function DbBulkLiteralText(const S: string): string;
begin
  Result := DbBulkLiteralText(S, dbkUnknown);
end;

function DbBulkLiteralText(const S: string; const ABackend: TDbKind): string;
begin
  try
    Result := '''' + DbBulkEscape(S, ABackend) + '''';
  except
    on E: EDbError do raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkLiteralTextLen(const S: string): Integer;
begin
  Result := DbBulkLiteralTextLen(S, dbkUnknown);
end;

function DbBulkLiteralTextLen(const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := DbBulkEscapeLen(S, ABackend) + 2;
  except
    on E: EDbError do raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkLiteralBlob(const ABytes: array of Byte): string;
const
  Hex: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
var
  N, I: Integer;
begin
  N := Length(ABytes);
  SetLength(Result, 2 + N*2 + 1);
  Result[1] := 'X';
  Result[2] := '''';
  for I := 0 to N - 1 do
  begin
    Result[3 + I*2] := Hex[(ABytes[I] shr 4) and $F];
    Result[4 + I*2] := Hex[ABytes[I] and $F];
  end;
  Result[Length(Result)] := '''';
end;

function DbBulkEscapeLen(const S: string): Integer;
begin
  Result := DbBulkEscapeLen(S, dbkUnknown);
end;

function DbBulkEscapeLen(const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlEscapeLen(S);
  except
    on E: EDbError do
      if E.Backend = dbkUnknown then
        raise EDbError.CreateWithCategory(ABackend, E.Category, E.Constraint, E.Message)
      else raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkQuotedIdentLen(const AIdent: string): Integer;
begin
  Result := DbBulkQuotedIdentLen(AIdent, dbkUnknown);
end;

function DbBulkQuotedIdentLen(const AIdent: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlQuotedIdentLen(AIdent);
  except
    on E: EDbError do
      if E.Backend = dbkUnknown then
        raise EDbError.CreateWithCategory(ABackend, E.Category, E.Constraint, E.Message)
      else raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkWriteEscape(Dst: PAnsiChar; const S: string): Integer;
begin
  Result := DbBulkWriteEscape(Dst, S, dbkUnknown);
end;

function DbBulkWriteEscape(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlWriteEscape(Dst, S);
  except
    on E: EDbError do
      if E.Backend = dbkUnknown then
        raise EDbError.CreateWithCategory(ABackend, E.Category, E.Constraint, E.Message)
      else raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkWriteQuotedIdent(Dst: PAnsiChar; const S: string): Integer;
begin
  Result := DbBulkWriteQuotedIdent(Dst, S, dbkUnknown);
end;

function DbBulkWriteQuotedIdent(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlWriteQuotedIdent(Dst, S);
  except
    on E: EDbError do
      if E.Backend = dbkUnknown then
        raise EDbError.CreateWithCategory(ABackend, E.Category, E.Constraint, E.Message)
      else raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

function DbBulkWriteLiteralText(Dst: PAnsiChar; const S: string): Integer;
begin
  Result := DbBulkWriteLiteralText(Dst, S, dbkUnknown);
end;

function DbBulkWriteLiteralText(Dst: PAnsiChar; const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlWriteLiteralText(Dst, S);
  except
    on E: EDbError do
      if E.Backend = dbkUnknown then
        raise EDbError.CreateWithCategory(ABackend, E.Category, E.Constraint, E.Message)
      else raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

procedure DbBulkValidateIdent(const ABackend: TDbKind; const AIdent: string);
begin
  DbBulkQuotedIdentLen(AIdent, ABackend);
end;

function DbBulkCheckNul(const S: string): Integer;
begin
  Result := DbBulkCheckNul(S, dbkUnknown);
end;

function DbBulkCheckNul(const S: string; const ABackend: TDbKind): Integer;
begin
  try
    Result := SqlEscapeLen(S);
  except
    on E: EDbError do
      if E.Backend = dbkUnknown then
        raise EDbError.CreateWithCategory(ABackend, E.Category, E.Constraint, E.Message)
      else raise;
    on E: Exception do raise EDbError.CreateSimple(ABackend, E.Message);
  end;
end;

procedure TDbBulkBuffer.Clear;
var I: Integer;
begin
  FActive := False;
  FTable := '';
  SetLength(FCols, 0);
  for I := 0 to FRowCount - 1 do
    FRows[I] := nil;
  FRowCount := 0;
end;

procedure TDbBulkBuffer.BeginCopy(const ATable: string; const AColumns: array of string);
begin
  BeginCopy(dbkUnknown, ATable, AColumns, 0);
end;

procedure TDbBulkBuffer.BeginCopy(const ATable: string; const AColumns: array of string; const AExpectedRows: Integer);
begin
  BeginCopy(dbkUnknown, ATable, AColumns, AExpectedRows);
end;

procedure TDbBulkBuffer.BeginCopy(const ABackend: TDbKind; const ATable: string; const AColumns: array of string);
begin
  BeginCopy(ABackend, ATable, AColumns, 0);
end;

procedure TDbBulkBuffer.BeginCopy(const ABackend: TDbKind; const ATable: string; const AColumns: array of string; const AExpectedRows: Integer);
var I: Integer;
  procedure ValidateIdent(const S: string);
  begin
    DbBulkValidateIdent(ABackend, S);
  end;
begin
  if FActive then Clear;
  ValidateIdent(ATable);
  if Length(AColumns) = 0 then
    raise EDbError.CreateSimple(ABackend, 'BulkCopy columns empty');
  for I := 0 to High(AColumns) do ValidateIdent(AColumns[I]);
  FTable := ATable;
  SetLength(FCols, Length(AColumns));
  for I := 0 to High(AColumns) do FCols[I] := AColumns[I];
  if AExpectedRows > 0 then
  begin
    if Length(FRows) < AExpectedRows then
      SetLength(FRows, AExpectedRows);
  end;
  FRowCount := 0;
  FActive := True;
end;

procedure TDbBulkBuffer.WriteRow(const ABackend: TDbKind; const AValues: array of string);
var Row: array of string; I, LCap, LNewCap: Integer;
begin
  if not FActive then raise EDbError.CreateSimple(ABackend, 'BulkCopy not started');
  if Length(AValues) <> Length(FCols) then raise EDbError.CreateSimple(ABackend, 'BulkCopy column count mismatch');
  SetLength(Row, Length(AValues));
  for I := 0 to High(AValues) do Row[I] := AValues[I];
  if FRowCount >= Length(FRows) then
  begin
    LCap := Length(FRows);
    if LCap = 0 then LNewCap := 16 else LNewCap := LCap * 2;
    while LNewCap <= FRowCount do LNewCap := LNewCap * 2;
    SetLength(FRows, LNewCap);
  end;
  FRows[FRowCount] := Row;
  Inc(FRowCount);
end;

function TDbBulkBuffer.IsActive: Boolean;
begin
  Result := FActive;
end;

function TDbBulkBuffer.TableName: string;
begin
  Result := FTable;
end;

function TDbBulkBuffer.Columns: TDbStringArray;
begin
  Result := FCols;
end;

function TDbBulkBuffer.Rows: TDbBulkRows;
var I: Integer;
begin
  if FRowCount = 0 then Exit(nil);
  if FRowCount = Length(FRows) then Exit(FRows);
  SetLength(Result, FRowCount);
  for I := 0 to FRowCount - 1 do Result[I] := FRows[I];
end;

function TDbBulkBuffer.ColumnCount: Integer;
begin
  Result := Length(FCols);
end;

function TDbBulkBuffer.RowCount: Integer;
begin
  Result := FRowCount;
end;

{ SQL stitch — raw PAnsiChar 单遍：预估 LCap+DbBulkWrite* 直写（零 L1 builder，零 LCap 双扫）；零 SysUtils }

function DbBulkColList(const ACols: TDbStringArray): string;
var I, L, LCap: Integer; P, P0: PAnsiChar;
begin
  if Length(ACols) = 0 then Exit('');
  LCap := 0;
  for I := 0 to High(ACols) do Inc(LCap, Length(ACols[I]) * 2 + 2 + 2);
  SetLength(Result, LCap);
  P := PAnsiChar(Result); P0 := P;
  for I := 0 to High(ACols) do
  begin
    if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
    L := DbBulkWriteQuotedIdent(P, ACols[I]); Inc(P, L);
  end;
  SetLength(Result, P - P0);
end;

function DbBulkValList(const ARow: array of string): string;
var I, L, LCap: Integer; P, P0: PAnsiChar;
begin
  if Length(ARow) = 0 then Exit('');
  LCap := 0;
  for I := 0 to High(ARow) do Inc(LCap, Length(ARow[I]) * 2 + 2 + 2);
  SetLength(Result, LCap);
  P := PAnsiChar(Result); P0 := P;
  for I := 0 to High(ARow) do
  begin
    if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
    L := DbBulkWriteLiteralText(P, ARow[I]); Inc(P, L);
  end;
  SetLength(Result, P - P0);
end;

function DbBulkInsertSql(const ATable, AColList: string; const ARow: array of string): string;
const CIns = 'INSERT INTO '; CParen = ' ('; CValues = ') VALUES ('; CRParen = ')';
var I, L, LCap: Integer; P, P0: PAnsiChar;
begin
  LCap := Length(CIns) + Length(ATable) * 2 + 2 + Length(CParen) + Length(AColList) + Length(CValues) + Length(CRParen);
  for I := 0 to High(ARow) do Inc(LCap, Length(ARow[I]) * 2 + 2 + 2);
  SetLength(Result, LCap);
  P := PAnsiChar(Result); P0 := P;
  Move(PAnsiChar(CIns)^, P^, Length(CIns)); Inc(P, Length(CIns));
  L := DbBulkWriteQuotedIdent(P, ATable); Inc(P, L);
  Move(PAnsiChar(CParen)^, P^, Length(CParen)); Inc(P, Length(CParen));
  if Length(AColList) > 0 then begin Move(PAnsiChar(AColList)^, P^, Length(AColList)); Inc(P, Length(AColList)); end;
  Move(PAnsiChar(CValues)^, P^, Length(CValues)); Inc(P, Length(CValues));
  for I := 0 to High(ARow) do
  begin
    if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
    L := DbBulkWriteLiteralText(P, ARow[I]); Inc(P, L);
  end;
  Move(PAnsiChar(CRParen)^, P^, Length(CRParen)); Inc(P, Length(CRParen));
  SetLength(Result, P - P0);
end;

function DbBulkMultiInsertSql(const ATable: string; const ACols: TDbStringArray;
  const ARows: TDbBulkRows; const AFrom, ACount: Integer): string;
const CIns = 'INSERT INTO '; CParen = ' ('; CValues = ') VALUES ';
var I, J, E, L, LCap: Integer; P, P0: PAnsiChar;
begin
  if ACount <= 0 then Exit('');
  LCap := Length(CIns) + Length(ATable) * 2 + 2 + Length(CParen) + Length(CValues);
  for I := 0 to High(ACols) do Inc(LCap, Length(ACols[I]) * 2 + 2 + 2);
  E := AFrom + ACount - 1;
  for I := AFrom to E do
  begin
    Inc(LCap, 2); // '(' ')'
    for J := 0 to High(ARows[I]) do Inc(LCap, Length(ARows[I][J]) * 2 + 2 + 2);
    Inc(LCap, 2); // ', ' between rows
  end;
  SetLength(Result, LCap);
  P := PAnsiChar(Result); P0 := P;
  Move(PAnsiChar(CIns)^, P^, Length(CIns)); Inc(P, Length(CIns));
  L := DbBulkWriteQuotedIdent(P, ATable); Inc(P, L);
  Move(PAnsiChar(CParen)^, P^, Length(CParen)); Inc(P, Length(CParen));
  for I := 0 to High(ACols) do
  begin
    if I > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
    L := DbBulkWriteQuotedIdent(P, ACols[I]); Inc(P, L);
  end;
  Move(PAnsiChar(CValues)^, P^, Length(CValues)); Inc(P, Length(CValues));
  for I := AFrom to E do
  begin
    if I > AFrom then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
    P[0] := '('; Inc(P);
    for J := 0 to High(ARows[I]) do
    begin
      if J > 0 then begin P[0] := ','; P[1] := ' '; Inc(P, 2); end;
      L := DbBulkWriteLiteralText(P, ARows[I][J]); Inc(P, L);
    end;
    P[0] := ')'; Inc(P);
  end;
  SetLength(Result, P - P0);
end;

function DbBulkChunkRows(const AMaxPlaceholders, AColumnCount, ARowCount: Integer): Integer;
var
  LCols, LChunk: Integer;
begin
  LCols := AColumnCount;
  if LCols < 1 then LCols := 1;
  if AMaxPlaceholders <= 0 then
    LChunk := DbBulkFallbackChunkRows
  else
    LChunk := AMaxPlaceholders div LCols;
  if LChunk < 1 then LChunk := 1;
  if (ARowCount > 0) and (LChunk > ARowCount) then
    LChunk := ARowCount;
  Result := LChunk;
end;

procedure DbBulkFlushChunked(
  const ATable: string;
  const ACols: TDbStringArray;
  const ARows: TDbBulkRows;
  const AChunkRows: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc);
  procedure DoFlush;
  var I, LRemain: Integer;
  begin
    I := 0;
    while I < Length(ARows) do
    begin
      LRemain := Length(ARows) - I;
      if LRemain > AChunkRows then
        AExec(DbBulkMultiInsertSql(ATable, ACols, ARows, I, AChunkRows))
      else
        AExec(DbBulkMultiInsertSql(ATable, ACols, ARows, I, LRemain));
      Inc(I, AChunkRows);
    end;
  end;
const
  CBulkSp = 'np_bulk_sp';
begin
  if (Length(ARows) = 0) or (AChunkRows <= 0) then Exit;
  if AInTxn then
  begin
    try
      AExec('SAVEPOINT ' + CBulkSp);
    except
      try
        DoFlush;
      except
        try ARollbackTxn(); except end;
        raise;
      end;
      Exit;
    end;
    try
      DoFlush;
      try
        AExec('RELEASE SAVEPOINT ' + CBulkSp);
      except
        try AExec('RELEASE ' + CBulkSp); except end;
      end;
    except
      try AExec('ROLLBACK TO SAVEPOINT ' + CBulkSp); except try AExec('ROLLBACK TO ' + CBulkSp); except end; end;
      try AExec('RELEASE SAVEPOINT ' + CBulkSp); except try AExec('RELEASE ' + CBulkSp); except end; end;
      raise;
    end;
  end
  else
  begin
    ABeginTxn(False);
    try
      DoFlush;
      ACommitTxn();
    except
      try ARollbackTxn(); except end;
      raise;
    end;
  end;
end;

procedure DbBulkFlushBuffer(
  const ABuffer: TDbBulkBuffer;
  const AMaxPlaceholders: Integer;
  const AInTxn: Boolean;
  const AExec: TDbBulkExecProc;
  const ABeginTxn: TDbBulkBeginProc;
  const ACommitTxn, ARollbackTxn: TDbBulkTxnProc);
var
  LCols: TDbStringArray;
  LRows: TDbBulkRows;
  LChunk: Integer;
begin
  if ABuffer.RowCount = 0 then Exit;
  LCols := ABuffer.Columns;
  LRows := ABuffer.Rows;
  LChunk := DbBulkChunkRows(AMaxPlaceholders, Length(LCols), ABuffer.RowCount);
  DbBulkFlushChunked(ABuffer.TableName, LCols, LRows, LChunk, AInTxn,
    AExec, ABeginTxn, ACommitTxn, ARollbackTxn);
end;

end.
