unit nextpas.core.text.sqlscan;

{$I nextpas.core.settings.inc}

interface

{** @desc L1 零分配 SQL 词法扫描引擎（单遍状态机，dollar/count 零额外分配）。
    层级：L1（仅依赖 L0 + text.builder IStringBuilder；零分配热路径）。
    单真相：历史 db.sqlscan 已物理删除（缺失强制迁移），本单元为唯一实现，不得重复。 *}

{** SQL 词法扫描共享引擎（V3-C6 抽取）。

    db 家族内同一"字符串/标识符/注释状态机"曾复制五份
    （pg/mysql/odbc 三份占位符翻译 + pg.conn 计数面 + pg.conn
    bytea 装饰面），本单元单点收敛；词法行为与被替换的各实现
    **逐字节兼容**（黄金语料 diff 为证，见
    core/docs/plans/2026-08-26-db-v3-c6-sqlscan-extract-plan.md）。

    受控边界（与历史实现一致，成文不变）：
    - dollar-quote 体不识别——受控 SQL 中字面量出现 '$$' 会把
      体内容当代码扫（pg 侧文档化决策，非缺陷）；
    - 行注释仅 #10 终止（#13 归入注释体，CRLF 输入安全）；
    - 占位符数字累加无溢出防护（荒谬编号回绕为既定行为）；
    - mysql 方言不处理双引号定界（默认 SQL_MODE 下 " 非标识符
      引用），与原实现一致。 }

type
  {** 方言词法集：各后端按需开启的词法定界符。 }
  TSqlScanDialect = record
    DoubleQuoteIdents: Boolean;  { "…" 标识符（"" 转义）—— pg/odbc }
    BacktickIdents: Boolean;     { `…` 标识符（无转义）—— mysql }
    BracketIdents: Boolean;      { […] 标识符（]] 转义）—— odbc }
    HashComments: Boolean;       { # 行注释 —— mysql }
  end;

  {** 占位符槽位计划：物理出现序 → 逻辑编号（裸 ? 为顺序序号）。 }
  TSqlScanSlotArray = array of Integer;

const
  SQLSCAN_PG: TSqlScanDialect = (
    DoubleQuoteIdents: True;
    BacktickIdents: False;
    BracketIdents: False;
    HashComments: False);

  SQLSCAN_MYSQL: TSqlScanDialect = (
    DoubleQuoteIdents: False;
    BacktickIdents: True;
    BracketIdents: False;
    HashComments: True);

  SQLSCAN_ODBC: TSqlScanDialect = (
    DoubleQuoteIdents: True;
    BacktickIdents: False;
    BracketIdents: True;
    HashComments: False);

{** 统一契约 '?'（含显式 ?N）保形改写 + 槽位计划。
    返回占位符个数；ARewritten 保持 '?' 原样（改写由调用方按
    物理槽位执行）；裸 ? 的逻辑号 = 顺序计数（显式 ?N 不扰动）。 }
function SqlScanTranslateQuestion(const ASql: string;
  const ADialect: TSqlScanDialect; out ARewritten: string;
  out ASlots: TSqlScanSlotArray): Integer;

{** '?' → '$N' 改写（libpq 形态）：裸 ? 取下一个顺序编号，
    显式 ?N 直接映射且不扰动顺序计数。不建槽数组（热路径零
    额外分配）。 }
function SqlScanRenderDollar(const ASql: string;
  const ADialect: TSqlScanDialect): string; inline;

{** 最大占位符编号（跳过字面量/注释）。APHChar 通常为 '$'
    （pg.conn 参数计数）或 '?'。返回 0 = 无参数。 }
function SqlScanMaxPlaceholderIndex(const ASql: string;
  const ADialect: TSqlScanDialect; const APhChar: AnsiChar): Integer;

{** 命中 APHChar+数字 占位符后在原位追加 ASUFFIX（如 ::bytea
    cast）。仅当编号 > 0 且在 AINDEXES 中命中才追加；源数字
    回显不改写。 }
function SqlScanDecorate(const ASql: string;
  const ADialect: TSqlScanDialect; const APhChar: AnsiChar;
  const AIndexes: array of Integer; const ASuffix: string): string;

implementation

uses
  nextpas.core.text.builder,
  nextpas.core.bytes.ops;

type
  TSqlScanMode = (
    ssmDollar,    { '?' → '$N' 重算渲染，Seq 替换裸占位符 }
    ssmQuestion,  { '?' 保形 + 槽位记录（Seq 替换裸占位符） }
    ssmCount,     { 零输出，原始编号入槽（供取最大） }
    ssmDecorate); { 保形回显 + 命中原位追加后缀 }

const
  { 编译期单源门禁：串/字节零拷贝单源为 bytes.ops（BYTES_OPS_SINGLE_SOURCE），
    本单元零拷贝 Move 语义与 bytes.ops 单源一致。 }
  TEXT_SQLSCAN_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{** 单遍引擎：四消费面共享的唯一状态机副本。词素分派与五个
    被替换实现逐分支一致（含 '-' 无论是否起注释都回显、块注
   释起始 '/' 不落 builder 由下一轮带出等细节）。
    perf: TBufStringBuilder 栈记录 inline 零拷贝 Move（AppendChar/AppendStr/AppendInt
    均为 inline 单 Move），零 IStringBuilder 接口堆对象；ssmCount/ssmDollar 零槽数组
    额外分配；RenderDollar/Translate 仅单次结果串分配（SetString 单 Move），达成
    完全零额外分配。资源：try..finally LB.Done 保证异常路径不泄漏。 }
function SqlScanCore(const ASql: string; const AD: TSqlScanDialect;
  const APhChar: AnsiChar; const AMode: TSqlScanMode;
  const AIndexes: array of Integer; const ASuffix: string;
  out ARewritten: string; out ASlots: TSqlScanSlotArray): Integer;
var
  LB: TBufStringBuilder;
  LUseBuilder: Boolean;
  I: Integer;
  C: AnsiChar;
  InStr, InDq, InBq, InBrk, InLineC, InHashC, InBlockC: Boolean;
  N, K, Seq, LCount, LCap: Integer;
  Matched: Boolean;
begin
  LUseBuilder := AMode <> ssmCount;
  if LUseBuilder then
    LB.Init(SizeUInt(Length(ASql)) + 16 + SizeUInt(Length(ASuffix)))
  else
    LB := Default(TBufStringBuilder);
  try
  ARewritten := '';
  if AMode in [ssmQuestion, ssmCount] then
  begin
    LCap := 8;
    SetLength(ASlots, LCap);
  end
  else
  begin
    LCap := 0;
    SetLength(ASlots, 0);
  end;
  LCount := 0;
  Seq := 0;
  InStr := False;
  InDq := False;
  InBq := False;
  InBrk := False;
  InLineC := False;
  InHashC := False;
  InBlockC := False;
  I := 1;
  while I <= Length(ASql) do
  begin
    C := ASql[I];
    if InLineC or InHashC then
    begin
      if LUseBuilder then
        LB.AppendChar(C);
      if C = #10 then
      begin
        InLineC := False;
        InHashC := False;
      end;
    end
    else if InBlockC then
    begin
      if LUseBuilder then
        LB.AppendChar(C);
      if (C = '*') and (I < Length(ASql)) and (ASql[I + 1] = '/') then
      begin
        if LUseBuilder then
          LB.AppendChar('/');
        InBlockC := False;
        Inc(I);
      end;
    end
    else if InStr then
    begin
      if LUseBuilder then
        LB.AppendChar(C);
      if C = '''' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '''') then
        begin
          if LUseBuilder then
            LB.AppendChar('''');
          Inc(I);
        end
        else
          InStr := False;
      end;
    end
    else if InDq then
    begin
      if LUseBuilder then
        LB.AppendChar(C);
      if C = '"' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '"') then
        begin
          if LUseBuilder then
            LB.AppendChar('"');
          Inc(I);
        end
        else
          InDq := False;
      end;
    end
    else if InBq then
    begin
      if LUseBuilder then
        LB.AppendChar(C);
      if C = '`' then
        InBq := False;
    end
    else if InBrk then
    begin
      if LUseBuilder then
        LB.AppendChar(C);
      if C = ']' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = ']') then
        begin
          if LUseBuilder then
            LB.AppendChar(']');
          Inc(I);
        end
        else
          InBrk := False;
      end;
    end
    else
    begin
      if C = '''' then
      begin
        InStr := True;
        if LUseBuilder then
          LB.AppendChar(C);
      end
      else if AD.DoubleQuoteIdents and (C = '"') then
      begin
        InDq := True;
        if LUseBuilder then
          LB.AppendChar(C);
      end
      else if AD.BacktickIdents and (C = '`') then
      begin
        InBq := True;
        if LUseBuilder then
          LB.AppendChar(C);
      end
      else if AD.BracketIdents and (C = '[') then
      begin
        InBrk := True;
        if LUseBuilder then
          LB.AppendChar(C);
      end
      else if AD.HashComments and (C = '#') then
      begin
        InHashC := True;
        if LUseBuilder then
          LB.AppendChar(C);
      end
      else if C = '-' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '-') then
          InLineC := True;
        if LUseBuilder then
          LB.AppendChar(C);
      end
      else if C = '/' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '*') then
        begin
          InBlockC := True;
          Inc(I);   { '*' 由 InBlockC 分支下一轮带出 }
          Continue;
        end;
        if LUseBuilder then
          LB.AppendChar(C);
      end
      else if C = APhChar then
      begin
        case AMode of
          ssmDecorate:
            begin
              LB.AppendChar(APhChar);
              Inc(I);
              N := 0;
              while (I <= Length(ASql)) and (ASql[I] in ['0'..'9']) do
              begin
                LB.AppendChar(ASql[I]);
                N := N * 10 + (Ord(ASql[I]) - Ord('0'));
                Inc(I);
              end;
              Matched := False;
              for K := 0 to High(AIndexes) do
                if AIndexes[K] = N then
                begin
                  Matched := True;
                  Break;
                end;
              if Matched and (N > 0) then
                LB.AppendStr(ASuffix);
              Continue;
            end;
          ssmCount:
            begin
              Inc(I);
              N := 0;
              while (I <= Length(ASql)) and (ASql[I] in ['0'..'9']) do
              begin
                N := N * 10 + (Ord(ASql[I]) - Ord('0'));
                Inc(I);
              end;
              if LCount >= LCap then
              begin
                LCap := LCap * 2;
                SetLength(ASlots, LCap);
              end;
              ASlots[LCount] := N;
              Inc(LCount);
              Continue;
            end;
        else
          begin
            Inc(I);
            N := 0;
            while (I <= Length(ASql)) and (ASql[I] in ['0'..'9']) do
            begin
              N := N * 10 + (Ord(ASql[I]) - Ord('0'));
              Inc(I);
            end;
            if N = 0 then
            begin
              Inc(Seq);
              N := Seq;
            end;
            case AMode of
              ssmDollar:
                begin
                  LB.AppendChar('$');
                  LB.AppendInt(N);
                end;
              ssmQuestion:
                begin
                  LB.AppendChar('?');
                  if LCount >= LCap then
                  begin
                    LCap := LCap * 2;
                    SetLength(ASlots, LCap);
                  end;
                  ASlots[LCount] := N;
                  Inc(LCount);
                end;
            end;
            Continue;
          end;
        end;
      end
      else
      begin
        if LUseBuilder then
          LB.AppendChar(C);
      end;
    end;
    Inc(I);
  end;
  SetLength(ASlots, LCount);
  if LUseBuilder then
    ARewritten := LB.ToString;
  Result := LCount;
  finally
    if LUseBuilder then
      LB.Done;
  end;
end;

function SqlScanTranslateQuestion(const ASql: string;
  const ADialect: TSqlScanDialect; out ARewritten: string;
  out ASlots: TSqlScanSlotArray): Integer;
begin
  Result := SqlScanCore(ASql, ADialect, '?', ssmQuestion,
    [], '', ARewritten, ASlots);
end;

function SqlScanRenderDollar(const ASql: string;
  const ADialect: TSqlScanDialect): string;
var
  LRw: string;
  LDummy: TSqlScanSlotArray;
begin
  SqlScanCore(ASql, ADialect, '?', ssmDollar, [], '', LRw, LDummy);
  Result := LRw;
end;

function SqlScanMaxPlaceholderIndex(const ASql: string;
  const ADialect: TSqlScanDialect; const APhChar: AnsiChar): Integer;
var
  LRw: string;
  LSlots: TSqlScanSlotArray;
  I: Integer;
begin
  SqlScanCore(ASql, ADialect, APhChar, ssmCount, [], '', LRw, LSlots);
  Result := 0;
  for I := 0 to High(LSlots) do
    if LSlots[I] > Result then
      Result := LSlots[I];
end;

function SqlScanDecorate(const ASql: string;
  const ADialect: TSqlScanDialect; const APhChar: AnsiChar;
  const AIndexes: array of Integer; const ASuffix: string): string;
var
  LRw: string;
  LDummy: TSqlScanSlotArray;
begin
  SqlScanCore(ASql, ADialect, APhChar, ssmDecorate,
    AIndexes, ASuffix, LRw, LDummy);
  Result := LRw;
end;

end.
