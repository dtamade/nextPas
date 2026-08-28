unit nextpas.core.text.kv;

// @desc 通用 key=value 扫描器（L0，零后端依赖）。
// 统一形态：key=value 序列，分隔符为空格或 ';'（兼容 MySQL DSN
// 空格分隔与 ODBC connstr 分号分隔），value 可用单引号/双引号/花括号
// 包裹以含空格/@/= 等特殊字符。与 MySQL DSN、PG conninfo、ODBC
// connstr 等多处 DSN 形态同源，抽取为共享内核提升复用度。
// 词法与 nextpas.core.db.mysql.adapter.ParseMySqlDsn 同构并扩展：
// - 跳过空白与 ';'，寻 '=' 分隔；缺 '=' 或空 key -> 错 "malformed ... near offset X"
// - '=' 后若为引号或花括号则寻同形闭合，缺闭合 -> 错 "unterminated quoted value for key"
// - 否则读至空白或 ';' 截断；尾随 ';' 按分隔符跳过
// - 保留原大小写，交由调用方 SameText 比对（零分配大小写无关）
// - 不做键合法性校验，调用方按需 fail-fast（未知键/非法值）
// 单遍 O(n)，零 TextBuilder 分配，仅 Copy 结果分量。

{$I nextpas.core.settings.inc}

interface

type
  TKVPair = record
    Key: string;
    Value: string;
  end;
  TKVPairs = array of TKVPair;

{ 扫描 S 为 KV 对数组；错则抛 ENextPasError（消费方可转译为 EDbError）。 }
function ParseKV(const S: string): TKVPairs;

{ 迭代回调形态：每对即时回调，避免中间数组分配（热路径可选）。 }
type
  TKVCallback = reference to procedure(const AKey, AValue: string);
procedure ScanKV(const S: string; const ACallback: TKVCallback);

{ 零分配校验：仅检查词法（malformed/unterminated），不分配 Key/Value 拷贝；
  返回 True 表示语法合法且至少一对，False 时 AError 为诊断文案（不抛）。 }
function ValidateKV(const S: string; out AError: string): Boolean;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv;

function ParseKV(const S: string): TKVPairs;
var
  LCount, LCap: Integer;

  procedure GrowIfNeeded;
  begin
    if LCount >= LCap then
    begin
      if LCap = 0 then LCap := 4 else LCap := LCap * 2;
      SetLength(Result, LCap);
    end;
  end;

  procedure AddPair(const AKey, AValue: string);
  begin
    GrowIfNeeded;
    Result[LCount].Key := AKey;
    Result[LCount].Value := AValue;
    Inc(LCount);
  end;

var
  I, LLen, LQuote, LStart: Integer;
  LKey, LVal: string;
begin
  Result := nil;
  LCount := 0;
  LCap := 0;
  LLen := Length(S);
  I := 1;
  while I <= LLen do
  begin
    while (I <= LLen) and ((S[I] = ' ') or (S[I] = ';')) do
      Inc(I);
    if I > LLen then Break;
    LStart := I;
    while (I <= LLen) and (S[I] <> '=') do
      Inc(I);
    if (I - LStart = 0) or (I > LLen) then
      raise ENextPasError.CreateFmt('malformed dsn near offset %d', [I]);
    LKey := Copy(S, LStart, I - LStart);
    Inc(I);
    if (I <= LLen) and ((S[I] = '''') or (S[I] = '"') or (S[I] = '{')) then
    begin
      if S[I] = '{' then
        LQuote := Ord('}')
      else
        LQuote := Ord(S[I]);
      Inc(I);
      LStart := I;
      while (I <= LLen) and (Ord(S[I]) <> LQuote) do
        Inc(I);
      if I > LLen then
        raise ENextPasError.CreateFmt('unterminated quoted dsn value for "%s"', [LKey]);
      LVal := Copy(S, LStart, I - LStart);
      Inc(I);
    end
    else
    begin
      LStart := I;
      while (I <= LLen) and (S[I] <> ' ') and (S[I] <> ';') do
        Inc(I);
      LVal := Copy(S, LStart, I - LStart);
    end;
    AddPair(LKey, LVal);
  end;
  if LCount <> Length(Result) then
    SetLength(Result, LCount);
end;

procedure ScanKV(const S: string; const ACallback: TKVCallback);
var
  I, LLen, LQuote, LStart: Integer;
  LKey, LVal: string;
begin
  LLen := Length(S);
  I := 1;
  while I <= LLen do
  begin
    while (I <= LLen) and ((S[I] = ' ') or (S[I] = ';')) do
      Inc(I);
    if I > LLen then Break;
    LStart := I;
    while (I <= LLen) and (S[I] <> '=') do
      Inc(I);
    if (I - LStart = 0) or (I > LLen) then
      raise ENextPasError.CreateFmt('malformed dsn near offset %d', [I]);
    LKey := Copy(S, LStart, I - LStart);
    Inc(I);
    if (I <= LLen) and ((S[I] = '''') or (S[I] = '"') or (S[I] = '{')) then
    begin
      if S[I] = '{' then
        LQuote := Ord('}')
      else
        LQuote := Ord(S[I]);
      Inc(I);
      LStart := I;
      while (I <= LLen) and (Ord(S[I]) <> LQuote) do
        Inc(I);
      if I > LLen then
        raise ENextPasError.CreateFmt('unterminated quoted dsn value for "%s"', [LKey]);
      LVal := Copy(S, LStart, I - LStart);
      Inc(I);
    end
    else
    begin
      LStart := I;
      while (I <= LLen) and (S[I] <> ' ') and (S[I] <> ';') do
        Inc(I);
      LVal := Copy(S, LStart, I - LStart);
    end;
    ACallback(LKey, LVal);
  end;
end;

function ValidateKV(const S: string; out AError: string): Boolean;
var
  I, LLen, LQuote, LStart, LCount: Integer;
  LKey: string;
begin
  AError := '';
  LCount := 0;
  LLen := Length(S);
  I := 1;
  while I <= LLen do
  begin
    while (I <= LLen) and ((S[I] = ' ') or (S[I] = ';')) do
      Inc(I);
    if I > LLen then Break;
    LStart := I;
    while (I <= LLen) and (S[I] <> '=') do
      Inc(I);
    if (I - LStart = 0) or (I > LLen) then
    begin
      AError := 'malformed dsn near offset ' + IntToStr(I);
      Exit(False);
    end;
    LKey := Copy(S, LStart, I - LStart);
    Inc(I);
    if (I <= LLen) and ((S[I] = '''') or (S[I] = '"') or (S[I] = '{')) then
    begin
      if S[I] = '{' then
        LQuote := Ord('}')
      else
        LQuote := Ord(S[I]);
      Inc(I);
      LStart := I;
      while (I <= LLen) and (Ord(S[I]) <> LQuote) do
        Inc(I);
      if I > LLen then
      begin
        AError := 'unterminated quoted dsn value for "' + LKey + '"';
        Exit(False);
      end;
      Inc(I);
    end
    else
    begin
      while (I <= LLen) and (S[I] <> ' ') and (S[I] <> ';') do
        Inc(I);
    end;
    Inc(LCount);
  end;
  if LCount = 0 then
  begin
    AError := 'empty dsn';
    Exit(False);
  end;
  Result := True;
end;

end.
