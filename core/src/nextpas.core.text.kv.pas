unit nextpas.core.text.kv;

{** @desc 通用 key=value 空格分词扫描器（L0，零后端依赖）。
       形态：空格分隔的 key=value 序列，value 可用 ' 或 " 包裹以含
       空格/@/= 等特殊字符。与 MySQL DSN、PG conninfo、ODBC connstr
       等多处 DSN 形态同源，抽取为共享内核提升复用度与可测试性。

       词法与 nextpas.core.db.mysql.adapter.ParseMySqlDsn 同构：
       - 跳过空白，寻 '=' 分隔；缺 '=' 或空 key → 错 "malformed ... near offset X"
       - '=' 后若为引号则寻同引号闭合，缺闭合 → 错 "unterminated quoted value for \"key\""
       - 否则读至空白截断
       - 保留原大小写，交由调用方 SameText 比对（零分配大小写无关）
       - 不做键合法性校验，调用方按需 fail-fast（未知键/非法值）
       单遍 O(n)，零 TextBuilder 分配，仅 Copy 结果分量。 *}

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
    while (I <= LLen) and (S[I] = ' ') do
      Inc(I);
    if I > LLen then Break;
    LStart := I;
    while (I <= LLen) and (S[I] <> '=') do
      Inc(I);
    if (I - LStart = 0) or (I > LLen) then
      raise ENextPasError.CreateFmt('malformed dsn near offset %d', [I]);
    LKey := Copy(S, LStart, I - LStart);
    Inc(I);
    if (I <= LLen) and ((S[I] = '''') or (S[I] = '"')) then
    begin
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
      while (I <= LLen) and (S[I] <> ' ') do
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
    while (I <= LLen) and (S[I] = ' ') do
      Inc(I);
    if I > LLen then Break;
    LStart := I;
    while (I <= LLen) and (S[I] <> '=') do
      Inc(I);
    if (I - LStart = 0) or (I > LLen) then
      raise ENextPasError.CreateFmt('malformed dsn near offset %d', [I]);
    LKey := Copy(S, LStart, I - LStart);
    Inc(I);
    if (I <= LLen) and ((S[I] = '''') or (S[I] = '"')) then
    begin
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
      while (I <= LLen) and (S[I] <> ' ') do
        Inc(I);
      LVal := Copy(S, LStart, I - LStart);
    end;
    ACallback(LKey, LVal);
  end;
end;

end.
