unit nextpas.core.mail.imap.base;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail IMAP 服务器基础面（L3，mail 家族）。
 *
 * 协议语法原语与数据契约：请求行/字面量标记/序列集解析、能力串、
 * 会话快照与邮件行模型、存储 SPI（IImapMailboxStore）、认证与吊销缝、
 * 服务器配置。协议层零 SQL：存储由应用实现，core 只定义契约
 * （边界设计 core/docs/plans/2026-08-26-imap-server-module-boundary.md）。
 *
 * 行为基线 = 原版 fafafa-mail-server src/smtp/imap.rs 务实子集；
 * 偏离点在 CONTRACT v0.3 §偏离表逐条登记。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

const
  MAIL_IMAP_LINE_LIMIT = 65536;               { 命令行上限；超限即断开（防失控客户端） }
  MAIL_IMAP_DEFAULT_MAX_LITERAL = 67108864;   { literal 上限 64 MiB，对齐 mime 默认 }
  MAIL_IMAP_OUTBOUND_DEFAULT_LIMIT = 262144;  { 回复队列 256 KiB（FETCH 批量响应大于 SMTP 单回复） }
  MAIL_IMAP_DEFAULT_IDLE_POLL_MS = 15000;     { IDLE ChangeVersion 轮询周期 }
  MAIL_IMAP_DEFAULT_IDLE_TIMEOUT_MS = 1800000; { IDLE 总时长上限，对齐原版 1800s }

type
  EImapError = class(ENextPasError);
  { 存储失败（临时错误）：会话捕获后回「tag NO Temporary server error」 }
  EImapTempError = class(EImapError);

  { 会话顶层态（RFC 3501 §3 务实简化；断开终态由传输层表达） }
  TImapSessionPhase = (
    ispNotAuthenticated,
    ispAuthenticated,
    ispSelected
  );

  { 选中邮箱快照：SELECT/EXAMINE 时由存储一次给定，命令间只读传递 }
  TImapMailboxSnapshot = record
    Name: string;            { 邮箱名（应用命名空间原样） }
    Exists: Int64;           { EXISTS 消息数 }
    Unseen: Int64;           { 未读数 }
    UidNext: Int64;
    UidValidity: UInt64;     { 原版恒 1；语义归存储 }
    ReadOnly: Boolean;       { EXAMINE 为 True }
  end;

  { 邮件行元数据；BODY[] 内容经 LoadContent 惰性取，不随行装载 }
  TImapMailRow = record
    Uid: Int64;
    Seq: Int64;              { 会话按选中序赋值（ListUids 下标 + 1） }
    Seen: Boolean;           { 原版唯一旗标 \Seen（is_read 映射） }
    Size: Int64;             { RFC822.SIZE 语义 = 内容字节数 }
    Subject: string;         { ENVELOPE 用；'' 由会话以 '(no subject)' 兜底（原版同） }
    FromAddr: string;
    ToAddr: string;
    InternalDate: string;    { 存储侧格式原样透传 }
  end;
  TImapMailRowArray = array of TImapMailRow;

  TImapUidArray = array of Int64;

  { SEARCH 谓词下推最小形态（原版仅 UNSEEN 键）；扩展键在此加字段 }
  TImapSearchPred = record
    Unseen: Boolean;
    class function UnseenOnly: TImapSearchPred; static;
  end;

  { 认证三态：对齐原版 LOGIN 成功/凭证无效/存储不可用三分文案 }
  TImapAuthResult = (iarOk, iarInvalid, iarUnavailable);
  TImapRevocationStatus = (irsActive, irsRevoked, irsUnavailable);

  { 凭证校验缝：应用接认证引擎；nil = LOGIN/AUTHENTICATE 一律拒（fail-closed） }
  IImapLoginCheck = interface
    function Verify(const AUsername, APassword: string;
      out AUserId: string): TImapAuthResult;
  end;

  { 会话吊销缝：每命令分发前调用（对齐原版 per-command active 检查）；
    nil = 关闭。实现须满足「短、非阻塞」纪律（同 ISmtpMailPolicyHook 先例）。 }
  IImapRevocationCheck = interface
    function Check(const AUserId: string): TImapRevocationStatus;
  end;

  { 存储 SPI：core 不见 SQL/连接池。所有方法在 reactor 线程被同步调用，
    实现须遵守「短事务、非阻塞」纪律（池内短事务/WAL；长任务自行卸载）。
    预期失败用返回值（False/空），存储故障抛 EImapTempError。 }
  IImapMailboxStore = interface
    { 用户邮箱枚举（INBOX 由服务器固定输出，不要求包含在内）；
      故障抛 EImapTempError。 }
    function ListMailboxes(const AUserId: string): TStringArray;
    { 打开邮箱取快照；False = 不存在。INBOX 大小写不敏感归一化属实现责任。 }
    function OpenMailbox(const AUserId, AName: string;
      out ABox: TImapMailboxSnapshot): Boolean;
    { 选中邮箱 UID 全集，严格升序（下标 i = 序号 i+1）——序列算术在协议层
      完成，存储每命令一次有序扫描即可。 }
    function ListUids(const ABox: TImapMailboxSnapshot): TImapUidArray;
    { 批量装元数据（不含正文）；缺失 UID 可跳过（原版同）。
      实现按 AUids 升序返回；会话按下标回填 Seq。 }
    function LoadRows(const ABox: TImapMailboxSnapshot;
      const AUids: TImapUidArray): TImapMailRowArray;
    { BODY[] 正文原始字节。 }
    function LoadContent(const ABox: TImapMailboxSnapshot;
      AUid: Int64): TBytes;
    { STORE \Seen；只读邮箱由会话先行拒绝，此处不必复查。 }
    procedure SetSeen(const ABox: TImapMailboxSnapshot; AUid: Int64;
      ASeen: Boolean);
    { SEARCH 谓词执行（谓词下推），返回 UID 集（升序）。 }
    function Search(const ABox: TImapMailboxSnapshot;
      const APred: TImapSearchPred): TImapUidArray;
    { APPEND：向用户邮箱追加一封；False = 目标不存在。
      AFlagSeen 对应 APPEND FLAGS 内 \Seen；AInternalDate 原样透传。 }
    function Append(const AUserId, AName: string; const AContent: TBytes;
      AFlagSeen: Boolean; const AInternalDate: string;
      out ANewUid: Int64): Boolean;
    { COPY：源快照内 uid 集复制到目标名；False = 目标不存在。 }
    function CopyTo(const ASource: TImapMailboxSnapshot;
      const AUids: TImapUidArray; const ATargetName: string): Boolean;
    { IDLE 版本缝：邮箱内容变更时返回值必须变化（单调递增推荐）；
      实现须廉价——IDLE 轮询高频调用。 }
    function ChangeVersion(const ABox: TImapMailboxSnapshot): Int64;
  end;

  TImapServerConfig = record
    ServerName: string;              { 问候横幅产品名；'' → 'IMAP4rev1' }
    MaxLiteral: Int64;               { literal 字节上限；<=0 → 64 MiB }
    LineLimit: SizeUInt;             { 命令行上限；0 → 64 KiB }
    OutboundQueueLimit: SizeUInt;    { 回复队列上限；0 → 256 KiB }
    IdleTimeoutMs: Int64;            { IDLE 总时长上限；<=0 → 30 min }
    IdlePollMs: Int64;               { ChangeVersion 轮询周期；<=0 → 15 s }
    LoginCheck: IImapLoginCheck;          { nil = LOGIN/AUTHENTICATE 一律 NO }
    RevocationCheck: IImapRevocationCheck; { nil = 关闭吊销检查 }
    { 探测位：影响 CAPABILITY 与 LOGIN 门控（原版分支）。True 形态宣告
      STARTTLS 而本批无握手缝，tls 批次 landing 前不得置 True。 }
    TlsAvailable: Boolean;
    TlsActive: Boolean;
    class function Default: TImapServerConfig; static;
  end;

  { ── 协议语法原语（纯函数；会话与 bench 共用） ────────────────── }

  { 解析请求行 "TAG VERB args"：tag 非空、verb 大写化（ASCII）。
    与原版 parse_imap_request_line 同语义：任一段为空 → False。
    单遍扫描零中间分配。 }
  function ImapParseRequestLine(const ALine: string;
    out ATag, AVerb, AArgs: string): Boolean;

  { 能力串：tls 可用且未激活 → 追加 STARTTLS LOGINDISABLED（原版分支），
    否则 AUTH=PLAIN。基串恒含 IMAP4rev1 LITERAL+ SASL-IR IDLE。 }
  function ImapCapabilityString(ATlsAvailable, ATlsActive: Boolean): string;

  { LOGIN 门控：not TlsAvailable or TlsActive（原版 imap_login_allowed）。 }
  function ImapLoginAllowed(ATlsAvailable, ATlsActive: Boolean): Boolean;

  { 判定行是否以 literal 标记（左花括号 + 数字 + 右花括号，可带加号形态）
    结尾；命中给出右花括号的位置、字节数与 plus 形态。
    数字段空/溢出 → False。 }
  function ImapExtractLiteralTail(const ALine: string;
    out AClosingBracePos: SizeUInt; out ALen: Int64;
    out APlus: Boolean): Boolean;

  { 序列集解析并对齐到升序 UID 表：seq 模式按「序号 = 下标+1」映射，
    uid 模式按值匹配；支持 n / n:m / * / 反向区间 / 逗号并集。
    语法非法或非正数 → False；合法但解不出目标（越界）→ True 空集
    （原版 OFFSET 越界跳过语义）。O(N + E·logN)。 }
  function ImapResolveSequenceSet(const ASet: string;
    const AUids: TImapUidArray; AUidMode: Boolean;
    out AOut: TImapUidArray): Boolean;

  { ASCII 大写化（verb/键名归一用；非 ASCII 字节原样保留） }
  function ImapAsciiUpper(const AStr: string): string;

  { ── 参数词法助手（会话/测试/基准共用） ────────────────────── }

  { 大小写不敏感子串包含（SEARCH UNSEEN / STORE 词法判定） }
  function ImapContainsCI(const AHaystack, ANeedle: string): Boolean;

  { 去首尾空白与成对双引号（原版 trim_matches('"') 同形） }
  function ImapUnquoteArg(const AVal: string): string;

  { 取第一个空白或左括号前的原子；ARest 为余部 }
  function ImapFirstAtom(const AArgs: string; out ARest: string): string;

  { 取成对圆括号段内容；无括号返回 False }
  function ImapTryParenSegment(const ASrc: string;
    out AInner, ARest: string): Boolean;

  { 引号转义（LIST 名 / ENVELOPE subject）：反斜杠与双引号前置反斜杠 }
  function ImapEscapeQuoted(const ASrc: string): string;

  { FETCH 项列表词法展平：括号与逗号归一为空格，便于 token 精确匹配 }
  function ImapFlattenItems(const ASrc: string): string;

  { 取 args 首词大写化；余部经 ARest 返回（去一个分隔空格）。
    AArgs 为 var：调用方传局部副本。 }
  procedure ImapSplitVerbToken(var AArgs: string; out AVerb: string);

implementation

uses
  nextpas.core.text.char,
  nextpas.core.text.conv;

class function TImapSearchPred.UnseenOnly: TImapSearchPred;
begin
  Result := Default(TImapSearchPred);
  Result.Unseen := True;
end;

class function TImapServerConfig.Default: TImapServerConfig;
begin
  Result.ServerName := 'IMAP4rev1';
  Result.MaxLiteral := MAIL_IMAP_DEFAULT_MAX_LITERAL;
  Result.LineLimit := MAIL_IMAP_LINE_LIMIT;
  Result.OutboundQueueLimit := MAIL_IMAP_OUTBOUND_DEFAULT_LIMIT;
  Result.IdleTimeoutMs := MAIL_IMAP_DEFAULT_IDLE_TIMEOUT_MS;
  Result.IdlePollMs := MAIL_IMAP_DEFAULT_IDLE_POLL_MS;
  Result.LoginCheck := nil;
  Result.RevocationCheck := nil;
  Result.TlsAvailable := False;
  Result.TlsActive := False;
end;

function ImapAsciiUpper(const AStr: string): string;
var
  I: Integer;
begin
  Result := AStr;
  for I := 1 to Length(Result) do
    if IsLower(Byte(Result[I])) then
      Result[I] := Chr(ToUpper(Byte(Result[I])));
end;

function ImapParseRequestLine(const ALine: string;
  out ATag, AVerb, AArgs: string): Boolean;
var
  LLen, LSp1, LSp2, I: Integer;
begin
  ATag := '';
  AVerb := '';
  AArgs := '';
  LLen := Length(ALine);
  LSp1 := 0;
  for I := 1 to LLen do
    if ALine[I] = ' ' then
    begin
      LSp1 := I;
      Break;
    end;
  if (LSp1 <= 1) or (LSp1 = LLen) then
    Exit(False);
  LSp2 := 0;
  for I := LSp1 + 1 to LLen do
    if ALine[I] = ' ' then
    begin
      LSp2 := I;
      Break;
    end;
  ATag := Copy(ALine, 1, LSp1 - 1);
  if LSp2 = 0 then
  begin
    AVerb := ImapAsciiUpper(Copy(ALine, LSp1 + 1, LLen - LSp1));
    Result := AVerb <> '';
  end
  else
  begin
    if LSp2 = LSp1 + 1 then
      Exit(False);
    AVerb := ImapAsciiUpper(Copy(ALine, LSp1 + 1, LSp2 - LSp1 - 1));
    AArgs := Copy(ALine, LSp2 + 1, LLen - LSp2);
    Result := True;
  end;
end;

function ImapCapabilityString(ATlsAvailable, ATlsActive: Boolean): string;
const
  BASE_CAPS = 'IMAP4rev1 LITERAL+ SASL-IR IDLE';
begin
  if ATlsAvailable and (not ATlsActive) then
    Result := BASE_CAPS + ' STARTTLS LOGINDISABLED'
  else
    Result := BASE_CAPS + ' AUTH=PLAIN';
end;

function ImapLoginAllowed(ATlsAvailable, ATlsActive: Boolean): Boolean;
begin
  Result := (not ATlsAvailable) or ATlsActive;
end;

function ImapExtractLiteralTail(const ALine: string;
  out AClosingBracePos: SizeUInt; out ALen: Int64;
  out APlus: Boolean): Boolean;
var
  I, LSegEnd: SizeUInt;
  LLen: SizeInt;
begin
  Result := False;
  AClosingBracePos := 0;
  ALen := 0;
  APlus := False;
  LLen := Length(ALine);
  if LLen < 3 then
    Exit;
  I := SizeUInt(LLen);
  if ALine[I] <> '}' then
    Exit;
  AClosingBracePos := I;
  Dec(I);
  LSegEnd := I;                     { 右侧数字段末位（标记内最后字符） }
  while (I >= 1) and IsDigit(Byte(ALine[I])) do
    Dec(I);
  if (I >= 1) and (ALine[I] = '+') then
  begin
    { 加号形态：数字位于加号之前 }
    APlus := True;
    LSegEnd := I - 1;
    Dec(I);
    while (I >= 1) and IsDigit(Byte(ALine[I])) do
      Dec(I);
  end;
  if (I < 1) or (ALine[I] <> '{') then
    Exit;
  if LSegEnd <= I then
    Exit;  { 数字段为空 }
  ALen := 0;
  for I := SizeUInt(I + 1) to LSegEnd do
  begin
    if ALen > (High(Int64) - 9) div 10 then
      Exit;  { 溢出防护：超出 Int64 即视为非法标记 }
    ALen := ALen * 10 + (Byte(ALine[I]) - Byte('0'));
  end;
  Result := True;
end;

{ 序列元素边界解析：正整数或 '*'（= ALastVal）；失败 False }
function ParseBound(const ARaw: string; ALastVal: Int64;
  out AVal: Int64): Boolean;
var
  I: Integer;
begin
  Result := False;
  if ARaw = '' then
    Exit(False);
  if ARaw = '*' then
  begin
    AVal := ALastVal;
    Exit(True);
  end;
  AVal := 0;
  for I := 1 to Length(ARaw) do
  begin
    if not IsDigit(Byte(ARaw[I])) then
      Exit(False);
    if AVal > (High(Int64) - 9) div 10 then
      Exit(False);
    AVal := AVal * 10 + (Byte(ARaw[I]) - Byte('0'));
  end;
  Result := AVal >= 1;
end;

{ 第一个 >= AUid 的下标（升序二分）；全小于则 Length(AUids) }
function UidLowerBound(const AUids: TImapUidArray; AUid: Int64): SizeInt;
var
  LLo, LHi, LMid: SizeInt;
begin
  LLo := 0;
  LHi := Length(AUids);
  while LLo < LHi do
  begin
    LMid := LLo + (LHi - LLo) div 2;
    if AUids[LMid] < AUid then
      LLo := LMid + 1
    else
      LHi := LMid;
  end;
  Result := LLo;
end;

function ImapResolveSequenceSet(const ASet: string;
  const AUids: TImapUidArray; AUidMode: Boolean;
  out AOut: TImapUidArray): Boolean;
var
  LElem, LA, LB: string;
  LElemStart, LComma, LColon, LP: SizeInt;
  LBoundA, LBoundB, LTmp, LLastVal: Int64;
  LMarks: array of Boolean;
  LCount: SizeInt;
  I, LIdxA, LIdxB: SizeInt;
begin
  Result := False;
  AOut := nil;
  LCount := Length(AUids);
  if ASet = '' then
    Exit(False);
  if AUidMode then
  begin
    if LCount > 0 then
      LLastVal := AUids[LCount - 1]
    else
      LLastVal := 0;
  end
  else
    LLastVal := LCount;   { seq 模式 '*' = 最后序号 }

  SetLength(LMarks, LCount);
  if LCount > 0 then
    FillChar(LMarks[0], SizeOf(Boolean) * LCount, 0);

  LElemStart := 1;
  repeat
    LComma := 0;
    for LP := LElemStart to Length(ASet) do
      if ASet[LP] = ',' then
      begin
        LComma := LP;
        Break;
      end;
    if LComma = 0 then
      LElem := Copy(ASet, LElemStart, Length(ASet) - LElemStart + 1)
    else
    begin
      if LComma = LElemStart then
        Exit(False);  { 空元素（",x" / "x,,y"） }
      LElem := Copy(ASet, LElemStart, LComma - LElemStart);
    end;
    if LElem = '' then
      Exit(False);

    LColon := 0;
    for LP := 1 to Length(LElem) do
      if LElem[LP] = ':' then
      begin
        LColon := LP;
        Break;
      end;
    if LColon = 0 then
    begin
      if not ParseBound(LElem, LLastVal, LBoundA) then
        Exit(False);
      LBoundB := LBoundA;
    end
    else
    begin
      LA := Copy(LElem, 1, LColon - 1);
      LB := Copy(LElem, LColon + 1, Length(LElem) - LColon);
      if (LA = '') or (LB = '') then
        Exit(False);
      if not ParseBound(LA, LLastVal, LBoundA) then
        Exit(False);
      if not ParseBound(LB, LLastVal, LBoundB) then
        Exit(False);
      if LBoundA > LBoundB then
      begin
        LTmp := LBoundA;
        LBoundA := LBoundB;
        LBoundB := LTmp;
      end;
    end;

    if LCount > 0 then
    begin
      if AUidMode then
      begin
        LIdxA := UidLowerBound(AUids, LBoundA);
        if LBoundB = High(Int64) then
          LIdxB := LCount
        else
          LIdxB := UidLowerBound(AUids, LBoundB + 1);  { 第一个 > LBoundB }
      end
      else
      begin
        LIdxA := LBoundA - 1;
        if LIdxA < 0 then
          LIdxA := 0;
        LIdxB := LBoundB;  { 序号 B → 下标 B-1，右界取开区间 }
        if LIdxB > LCount then
          LIdxB := LCount;
      end;
      if LIdxB > LCount then
        LIdxB := LCount;
      for I := LIdxA to LIdxB - 1 do
        LMarks[I] := True;
    end;

    if LComma = 0 then
      Break;
    LElemStart := LComma + 1;
  until False;

  SetLength(AOut, 0);
  for I := 0 to LCount - 1 do
    if LMarks[I] then
    begin
      SetLength(AOut, Length(AOut) + 1);
      AOut[High(AOut)] := AUids[I];
    end;
  Result := True;
end;

function ImapContainsCI(const AHaystack, ANeedle: string): Boolean;
var
  I, J: Integer;
  LMatch: Boolean;
begin
  Result := False;
  if Length(ANeedle) = 0 then
    Exit(True);
  if Length(ANeedle) > Length(AHaystack) then
    Exit(False);
  for I := 1 to Length(AHaystack) - Length(ANeedle) + 1 do
  begin
    LMatch := True;
    for J := 0 to Length(ANeedle) - 1 do
      if UpCase(AHaystack[I + J]) <> UpCase(ANeedle[J + 1]) then
      begin
        LMatch := False;
        Break;
      end;
    if LMatch then
      Exit(True);
  end;
end;

function ImapUnquoteArg(const AVal: string): string;
var
  LT: string;
begin
  LT := Trim(AVal);
  if (Length(LT) >= 2) and (LT[1] = '"') and (LT[Length(LT)] = '"') then
    Result := Copy(LT, 2, Length(LT) - 2)
  else
    Result := LT;
end;

function ImapFirstAtom(const AArgs: string; out ARest: string): string;
var
  I, LEnd: Integer;
begin
  LEnd := Length(AArgs);
  for I := 1 to Length(AArgs) do
    if (AArgs[I] = ' ') or (AArgs[I] = '(') then
    begin
      LEnd := I - 1;
      Break;
    end;
  Result := Copy(AArgs, 1, LEnd);
  ARest := Copy(AArgs, LEnd + 1, Length(AArgs) - LEnd);
end;

function ImapTryParenSegment(const ASrc: string;
  out AInner, ARest: string): Boolean;
var
  LStart, LEndP, I: Integer;
begin
  Result := False;
  AInner := '';
  ARest := ASrc;
  LStart := 0;
  for I := 1 to Length(ASrc) do
    if ASrc[I] = '(' then
    begin
      LStart := I;
      Break;
    end;
  if LStart = 0 then
    Exit;
  LEndP := 0;
  for I := LStart + 1 to Length(ASrc) do
    if ASrc[I] = ')' then
    begin
      LEndP := I;
      Break;
    end;
  if LEndP = 0 then
    Exit;
  AInner := Copy(ASrc, LStart + 1, LEndP - LStart - 1);
  ARest := Copy(ASrc, LEndP + 1, Length(ASrc) - LEndP);
  Result := True;
end;

function ImapEscapeQuoted(const ASrc: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(ASrc) do
  begin
    if (ASrc[I] = '\') or (ASrc[I] = '"') then
      Result := Result + '\';
    Result := Result + ASrc[I];
  end;
end;

function ImapFlattenItems(const ASrc: string): string;
var
  I: Integer;
begin
  SetLength(Result, Length(ASrc));
  for I := 1 to Length(ASrc) do
    if (ASrc[I] = '(') or (ASrc[I] = ')') or (ASrc[I] = ',') then
      Result[I] := ' '
    else
      Result[I] := ASrc[I];
end;

procedure ImapSplitVerbToken(var AArgs: string; out AVerb: string);
var
  I: Integer;
begin
  AArgs := TrimLeft(AArgs);
  I := 1;
  while (I <= Length(AArgs)) and (AArgs[I] <> ' ') do
    Inc(I);
  AVerb := ImapAsciiUpper(Copy(AArgs, 1, I - 1));
  if I <= Length(AArgs) then
    AArgs := Copy(AArgs, I + 1, Length(AArgs) - I)
  else
    AArgs := '';
end;

end.
