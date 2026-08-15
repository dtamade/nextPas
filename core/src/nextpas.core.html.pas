unit nextpas.core.html;

{**
 * @desc 容错 HTML→纯文本提取 + 实体解码（B2 批次）。
 * 单遍扫描、不构建 DOM；对任何畸形输入不抛异常，只对超长输入抛 EArgumentError
 * （防御性上限，Try 形态返回 False）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.html.base;

const
  { 输入长度上限（64 MiB）。超出视为拒绝：HtmlTextOf 抛 EArgumentError，
    TryHtmlTextOf 返回 False。防止恶意超长输入放大内存/CPU。 }
  MaxHtmlInputLength = 64 * 1024 * 1024;

type
  THtmlExtractOptions = nextpas.core.html.base.THtmlExtractOptions;

const
  { 与 base 的默认值一致；type 别名 + 值重声明，供只 uses 门面方直接使用。 }
  DefaultHtmlExtractOptions: THtmlExtractOptions = (
    KeepLinks: False;
    KeepHeadings: False;
    CollapseWhitespace: True
  );

{ HTML→纯文本，默认选项。永远不抛异常（除超过 MaxHtmlInputLength）。 }
function HtmlTextOf(const AHtml: string): string; inline;
function HtmlTextOf(const AHtml: string; const AOptions: THtmlExtractOptions): string;
function TryHtmlTextOf(const AHtml: string; out AText: string): Boolean; inline;
function TryHtmlTextOf(const AHtml: string; const AOptions: THtmlExtractOptions;
  out AText: string): Boolean;

{ 仅实体解码（不解标签、不折叠空白）。未知/畸形实体原样保留。 }
function HtmlDecodeEntities(const AStr: string): string;

implementation

uses
  nextpas.core.text.builder,
  nextpas.core.text.char,
  nextpas.core.text.utf8;

function EntityUTF8(const AName: string; out AOut: string): Boolean;
begin
  Result := True;
  case AName of
    'amp':                AOut := '&';
    'lt':                 AOut := '<';
    'gt':                 AOut := '>';
    'quot':               AOut := '"';
    'apos':               AOut := '''';
    'nbsp':               AOut := #$C2#$A0;
    'iexcl':              AOut := #$C2#$A1;
    'cent':               AOut := #$C2#$A2;
    'pound':              AOut := #$C2#$A3;
    'curren':             AOut := #$C2#$A4;
    'yen':                AOut := #$C2#$A5;
    'brvbar':             AOut := #$C2#$A6;
    'sect':               AOut := #$C2#$A7;
    'uml':                AOut := #$C2#$A8;
    'copy':               AOut := #$C2#$A9;
    'ordf':               AOut := #$C2#$AA;
    'laquo':              AOut := #$C2#$AB;
    'not':                AOut := #$C2#$AC;
    'shy':                AOut := #$C2#$AD;
    'reg':                AOut := #$C2#$AE;
    'macr':               AOut := #$C2#$AF;
    'deg':                AOut := #$C2#$B0;
    'plusmn':             AOut := #$C2#$B1;
    'sup2':               AOut := #$C2#$B2;
    'sup3':               AOut := #$C2#$B3;
    'acute':              AOut := #$C2#$B4;
    'micro':              AOut := #$C2#$B5;
    'para':               AOut := #$C2#$B6;
    'middot':             AOut := #$C2#$B7;
    'cedil':              AOut := #$C2#$B8;
    'sup1':               AOut := #$C2#$B9;
    'ordm':               AOut := #$C2#$BA;
    'raquo':              AOut := #$C2#$BB;
    'frac14':             AOut := #$C2#$BC;
    'frac12':             AOut := #$C2#$BD;
    'frac34':             AOut := #$C2#$BE;
    'iquest':             AOut := #$C2#$BF;
    'szlig':              AOut := #$C3#$9F;
    'agrave':             AOut := #$C3#$A0;
    'aacute':             AOut := #$C3#$A1;
    'acirc':              AOut := #$C3#$A2;
    'atilde':             AOut := #$C3#$A3;
    'auml':               AOut := #$C3#$A4;
    'aring':              AOut := #$C3#$A5;
    'aelig':              AOut := #$C3#$A6;
    'ccedil':             AOut := #$C3#$A7;
    'egrave':             AOut := #$C3#$A8;
    'eacute':             AOut := #$C3#$A9;
    'ecirc':              AOut := #$C3#$AA;
    'euml':               AOut := #$C3#$AB;
    'igrave':             AOut := #$C3#$AC;
    'iacute':             AOut := #$C3#$AD;
    'icirc':              AOut := #$C3#$AE;
    'iuml':               AOut := #$C3#$AF;
    'eth':                AOut := #$C3#$B0;
    'ntilde':             AOut := #$C3#$B1;
    'ograve':             AOut := #$C3#$B2;
    'oacute':             AOut := #$C3#$B3;
    'ocirc':              AOut := #$C3#$B4;
    'otilde':             AOut := #$C3#$B5;
    'ouml':               AOut := #$C3#$B6;
    'oslash':             AOut := #$C3#$B8;
    'ugrave':             AOut := #$C3#$B9;
    'uacute':             AOut := #$C3#$BA;
    'ucirc':              AOut := #$C3#$BB;
    'uuml':               AOut := #$C3#$BC;
    'yacute':             AOut := #$C3#$BD;
    'thorn':              AOut := #$C3#$BE;
    'yuml':               AOut := #$C3#$BF;
    'times':              AOut := #$C3#$97;
    'divide':             AOut := #$C3#$B7;
    'Alpha':              AOut := #$CE#$91;
    'Beta':               AOut := #$CE#$92;
    'Gamma':              AOut := #$CE#$93;
    'Delta':              AOut := #$CE#$94;
    'Epsilon':            AOut := #$CE#$95;
    'Zeta':               AOut := #$CE#$96;
    'Eta':                AOut := #$CE#$97;
    'Theta':              AOut := #$CE#$98;
    'Iota':               AOut := #$CE#$99;
    'Kappa':              AOut := #$CE#$9A;
    'Lambda':             AOut := #$CE#$9B;
    'Mu':                 AOut := #$CE#$9C;
    'Nu':                 AOut := #$CE#$9D;
    'Xi':                 AOut := #$CE#$9E;
    'Omicron':            AOut := #$CE#$9F;
    'Pi':                 AOut := #$CE#$A0;
    'Rho':                AOut := #$CE#$A1;
    'Sigma':              AOut := #$CE#$A3;
    'Tau':                AOut := #$CE#$A4;
    'Upsilon':            AOut := #$CE#$A5;
    'Phi':                AOut := #$CE#$A6;
    'Chi':                AOut := #$CE#$A7;
    'Psi':                AOut := #$CE#$A8;
    'Omega':              AOut := #$CE#$A9;
    'alpha':              AOut := #$CE#$B1;
    'beta':               AOut := #$CE#$B2;
    'gamma':              AOut := #$CE#$B3;
    'delta':              AOut := #$CE#$B4;
    'epsilon':            AOut := #$CE#$B5;
    'zeta':               AOut := #$CE#$B6;
    'eta':                AOut := #$CE#$B7;
    'theta':              AOut := #$CE#$B8;
    'iota':               AOut := #$CE#$B9;
    'kappa':              AOut := #$CE#$BA;
    'lambda':             AOut := #$CE#$BB;
    'mu':                 AOut := #$CE#$BC;
    'nu':                 AOut := #$CE#$BD;
    'xi':                 AOut := #$CE#$BE;
    'omicron':            AOut := #$CE#$BF;
    'pi':                 AOut := #$CF#$80;
    'rho':                AOut := #$CF#$81;
    'sigma':              AOut := #$CF#$83;
    'tau':                AOut := #$CF#$84;
    'upsilon':            AOut := #$CF#$85;
    'phi':                AOut := #$CF#$86;
    'chi':                AOut := #$CF#$87;
    'psi':                AOut := #$CF#$88;
    'omega':              AOut := #$CF#$89;
    'ensp':               AOut := #$E2#$80#$82;
    'emsp':               AOut := #$E2#$80#$83;
    'thinsp':             AOut := #$E2#$80#$89;
    'zwnj':               AOut := #$E2#$80#$8C;
    'zwj':                AOut := #$E2#$80#$8D;
    'lsquo':              AOut := #$E2#$80#$98;
    'rsquo':              AOut := #$E2#$80#$99;
    'ldquo':              AOut := #$E2#$80#$9C;
    'rdquo':              AOut := #$E2#$80#$9D;
    'bull':               AOut := #$E2#$80#$A2;
    'hellip':             AOut := #$E2#$80#$A6;
    'dagger':             AOut := #$E2#$80#$A0;
    'Dagger':             AOut := #$E2#$80#$A1;
    'permil':             AOut := #$E2#$80#$B0;
    'prime':              AOut := #$E2#$80#$B2;
    'Prime':              AOut := #$E2#$80#$B3;
    'larr':               AOut := #$E2#$86#$90;
    'uarr':               AOut := #$E2#$86#$91;
    'rarr':               AOut := #$E2#$86#$92;
    'darr':               AOut := #$E2#$86#$93;
    'harr':               AOut := #$E2#$86#$94;
    'trade':              AOut := #$E2#$84#$A2;
    'euro':               AOut := #$E2#$82#$AC;
    'ndash':              AOut := #$E2#$80#$93;
    'mdash':              AOut := #$E2#$80#$94;
    'num':                AOut := '#';
    'sol':                AOut := '/';
    'comma':              AOut := ',';
    'period':             AOut := '.';
    'semi':               AOut := ';';
    'colon':              AOut := ':';
    'quest':              AOut := '?';
    'excl':               AOut := '!';
    'commat':             AOut := '@';
    'lsqb':               AOut := '[';
    'rsqb':               AOut := ']';
    'lcub':               AOut := '{';
    'rcub':               AOut := '}';
    'lowbar':             AOut := '_';
  else
    Result := False;
  end;
end;

{ 从 APos（指向 '&'）解析数字实体 &#D; / &#xH;。成功时 APos 越过构造末尾
  （分号可选），返回 True；失败时 APos 不动、返回 False（字面保留）。 }
function TryNumericEntity(const S: string; var APos: Integer; out ACodePoint: UInt32): Boolean;
var
  LLen, P, LDigits: Integer;
  LIsHex: Boolean;
  LValue: UInt64;
begin
  LLen := Length(S);
  if (APos >= LLen) or (S[APos] <> '&') or (S[APos + 1] <> '#') then
    Exit(False);
  P := APos + 2;
  LIsHex := (P <= LLen) and ((S[P] = 'x') or (S[P] = 'X'));
  if LIsHex then
    Inc(P);
  LValue := 0;
  LDigits := 0;
  while P <= LLen do
  begin
    if LIsHex then
    begin
      if not IsHexDigit(Byte(S[P])) then
        Break;
      LValue := (LValue shl 4) or UInt64(HexDigitValue(Byte(S[P])));
    end
    else
    begin
      if not IsDigit(Byte(S[P])) then
        Break;
      LValue := LValue * 10 + UInt64(Byte(S[P]) - Ord('0'));
    end;
    Inc(LDigits);
    Inc(P);
    { 7 位以上必然超出 Unicode 上限，提前拒绝避免无界循环/溢出 }
    if LDigits > 7 then
      Exit(False);
  end;
  if LDigits = 0 then
    Exit(False);
  if (LValue = 0) or (LValue > $10FFFF) then
    Exit(False);
  if (LValue >= $D800) and (LValue <= $DFFF) then
    Exit(False);
  ACodePoint := UInt32(LValue);
  if (P <= LLen) and (S[P] = ';') then
    Inc(P);
  APos := P;
  Result := True;
end;

{ 从 APos（指向 '&'）解析命名实体（大小写敏感）。分号可选，但仅当下一个
  字符不是字母数字时接受（HTML5 要求分号；宽容接受旧式 &amp 不带分号，
  但 &ampx 不被误吞）。失败时 APos 不动。 }
function TryNamedEntity(const S: string; var APos: Integer; out AOut: string): Boolean;
var
  LLen, P, N: Integer;
  LName: string;
begin
  LLen := Length(S);
  if (APos > LLen) or (S[APos] <> '&') then
    Exit(False);
  P := APos + 1;
  if (P > LLen) or not IsAlpha(Byte(S[P])) then
    Exit(False);
  while (P <= LLen) and IsAlphaNum(Byte(S[P])) do
    Inc(P);
  N := P - (APos + 1);
  if N = 0 then
    Exit(False);
  LName := Copy(S, APos + 1, N);
  if not EntityUTF8(LName, AOut) then
    Exit(False);
  if (P <= LLen) and (S[P] = ';') then
    Inc(P)
  else if (P <= LLen) and IsAlphaNum(Byte(S[P])) then
    Exit(False);
  APos := P;
  Result := True;
end;

{ 仅实体解码：未知/畸形构造原样输出。BOM 保留（解码是逐字变换）。 }
function HtmlDecodeEntities(const AStr: string): string;
var
  LLen, LPos, LRunStart: Integer;
  LCP: UInt32;
  LDecoded: string;
  LOut: TStringBuilder;
begin
  Result := '';
  LLen := Length(AStr);
  if LLen = 0 then
    Exit;
  LOut.Init(256);
  try
    LPos := 1;
    while LPos <= LLen do
    begin
      if (AStr[LPos] <> '&') then
      begin
        LRunStart := LPos;
        while (LPos <= LLen) and (AStr[LPos] <> '&') do
          Inc(LPos);
        LOut.AppendBytes(@AStr[LRunStart], SizeUInt(LPos - LRunStart));
      end
      else if TryNumericEntity(AStr, LPos, LCP) then
      begin
        LDecoded := UTF8EncodeToStr(LCP);
        LOut.AppendStr(LDecoded);
      end
      else if TryNamedEntity(AStr, LPos, LDecoded) then
        LOut.AppendStr(LDecoded)
      else
      begin
        LOut.AppendChar('&');
        Inc(LPos);
      end;
    end;
    Result := LOut.ToString;
  finally
    LOut.Done;
  end;
end;

type
  THtmlExtractState = record
    Out: TStringBuilder;
    Options: THtmlExtractOptions;
    { 待落地的单个块级换行（标志位天然去重连续块边界） }
    PendingBreak: Boolean;
    AtLineStart: Boolean;
    { 折叠模式下待定的单个空格：延迟到下一个非空白字符才落，
      块边界/行尾处自然丢弃（尾部不留空格、块前不留空格）。 }
    PendingSpace: Boolean;
    AnchorHref: string;
    AnchorHadText: Boolean;
  end;

function AsciiLowerCase(const AStr: string): string;
var
  I: Integer;
  B: Byte;
begin
  Result := AStr;
  for I := 1 to Length(Result) do
  begin
    B := Byte(Result[I]);
    if (B >= Ord('A')) and (B <= Ord('Z')) then
      Result[I] := AnsiChar(B + 32);
  end;
end;

function IsHeadingElement(const AName: string): Boolean;
begin
  case AName of
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6': Result := True;
  else
    Result := False;
  end;
end;

function IsBlockElement(const AName: string): Boolean;
begin
  case AName of
    'p', 'div', 'section', 'article', 'aside', 'nav', 'main', 'header',
    'footer', 'ul', 'ol', 'li', 'menu', 'dir', 'dl', 'dt', 'dd',
    'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th', 'caption',
    'colgroup', 'blockquote', 'pre', 'address', 'figure', 'figcaption',
    'details', 'summary', 'form', 'fieldset', 'hr':
      Result := True;
  else
    Result := False;
  end;
end;

function IsHiddenElement(const AName: string): Boolean;
begin
  case AName of
    'script', 'style', 'noscript', 'head': Result := True;
  else
    Result := False;
  end;
end;

procedure FlushBreak(var AState: THtmlExtractState); inline;
begin
  if not AState.PendingBreak then
    Exit;
  AState.PendingBreak := False;
  AState.PendingSpace := False; { 块边界前的空白由换行取代 }
  if not AState.AtLineStart then
    AState.Out.AppendChar(#10);
  AState.AtLineStart := True;
end;

{ 追加一段文本（折叠/保留空白取决于选项）。断言之首先落待定的块级换行。 }
procedure AppendTextRun(var AState: THtmlExtractState; const AData: PAnsiChar;
  const ALen: SizeInt);
var
  I: SizeInt;
  LCh: Byte;
begin
  FlushBreak(AState);
  I := 0;
  while I < ALen do
  begin
    LCh := Byte(AData[I]);
    if (LCh = $C2) and (I + 1 < ALen) and (Byte(AData[I + 1]) = $A0) then
    begin
      { U+00A0（含 &nbsp; 解码结果）视同空白 }
      if not AState.AtLineStart then
      begin
        if AState.Options.CollapseWhitespace then
          AState.PendingSpace := True
        else
          AState.Out.AppendBytes(AData + I, 2);
      end;
      Inc(I, 2);
    end
    else if IsWhitespace(LCh) then
    begin
      if not AState.AtLineStart then
      begin
        if AState.Options.CollapseWhitespace then
          AState.PendingSpace := True
        else
          AState.Out.AppendChar(AnsiChar(LCh));
      end;
    end
    else
    begin
      if AState.Options.CollapseWhitespace and AState.PendingSpace and
        not AState.AtLineStart then
      begin
        AState.Out.AppendChar(' ');
        AState.PendingSpace := False;
      end;
      AState.Out.AppendChar(AnsiChar(LCh));
      AState.AtLineStart := False;
      if AState.AnchorHref <> '' then
        AState.AnchorHadText := True;
    end;
    Inc(I);
  end;
end;

procedure AppendTextRun(var AState: THtmlExtractState; const AStr: string);
begin
  if AStr = '' then
    Exit;
  AppendTextRun(AState, @AStr[1], Length(AStr));
end;

{ 从 APos 扫描 '>'（尊重属性值引号），结束后 APos 位于 '>' 之后；
  未闭合（截断输入）时 APos = Length(S)+1。 }
procedure SkipToCloseBracket(const S: string; var APos: Integer; const ALen: Integer;
  const AQuoteAware: Boolean);
var
  LQuote: AnsiChar;
begin
  LQuote := #0;
  while APos <= ALen do
  begin
    if AQuoteAware and (LQuote <> #0) then
    begin
      if S[APos] = LQuote then
        LQuote := #0;
    end
    else if S[APos] = '>' then
    begin
      Inc(APos);
      Exit;
    end
    else if AQuoteAware and ((S[APos] = '"') or (S[APos] = '''')) then
      LQuote := S[APos];
    Inc(APos);
  end;
end;

{ 解析开标签属性和结束位置。AFrom 在标签名后。输出 href/alt 值
  （未解码，按原文捕获）与 '>' 结束位置（未闭合时 = ALen+1）。 }
procedure ParseOpenTag(const S: string; AFrom: Integer;
  out AHref, AAlt: string; out AEndPos: Integer);
var
  ALen, P, LNameStart, LNameLen, LValStart, LValEnd: Integer;
  LName: string;
  LQuote: AnsiChar;
begin
  AHref := '';
  AAlt := '';
  ALen := Length(S);
  P := AFrom;
  while P <= ALen do
  begin
    while (P <= ALen) and (S[P] in [#9, #10, #13, ' ']) do
      Inc(P);
    if P > ALen then
      Break;
    if S[P] = '>' then
    begin
      AEndPos := P + 1;
      Exit;
    end;
    if S[P] = '/' then
    begin
      Inc(P);
      Continue; { 自闭合前缀 }
    end;
    LNameStart := P;
    while (P <= ALen) and (IsAlphaNum(Byte(S[P])) or
      (S[P] in ['-', '_', ':', '.'])) do
      Inc(P);
    LNameLen := P - LNameStart;
    if LNameLen = 0 then
    begin
      { 非法属性起始字符：若为 '>' 则标签结束，否则容错跳过 }
      Inc(P);
      Continue;
    end;
    LName := AsciiLowerCase(Copy(S, LNameStart, LNameLen));
    while (P <= ALen) and (S[P] in [#9, #10, #13, ' ']) do
      Inc(P);
    if (P <= ALen) and (S[P] = '=') then
    begin
      Inc(P);
      while (P <= ALen) and (S[P] in [#9, #10, #13, ' ']) do
        Inc(P);
      if (P <= ALen) and ((S[P] = '"') or (S[P] = '''')) then
      begin
        LQuote := S[P];
        Inc(P);
        LValStart := P;
        while (P <= ALen) and (S[P] <> LQuote) do
          Inc(P);
        LValEnd := P;
        if P <= ALen then
          Inc(P); { 越过闭合引号 }
      end
      else
      begin
        LValStart := P;
        while (P <= ALen) and not (S[P] in [#9, #10, #13, ' ', '>']) do
          Inc(P);
        LValEnd := P;
      end;
      if LValEnd >= LValStart then
      begin
        if LName = 'href' then
          AHref := Copy(S, LValStart, LValEnd - LValStart)
        else if LName = 'alt' then
          AAlt := Copy(S, LValStart, LValEnd - LValStart);
      end;
    end;
  end;
  AEndPos := ALen + 1; { 未闭合：吃掉剩余输入 }
end;

{ 从 AFrom 起找大小写不敏感的 '</name'（name 后须为非字母数字边界），
  找到后 AAfterGt 指向其后 '>' 之后。 }
function FindCloseTag(const S: string; AFrom: Integer; const AName: string;
  out AAfterGt: Integer): Boolean;
var
  ALen, I, J, K, N: Integer;
begin
  ALen := Length(S);
  N := Length(AName);
  I := AFrom;
  while I + N + 1 <= ALen do
  begin
    if (S[I] = '<') and (S[I + 1] = '/') then
    begin
      J := I + 2;
      while (J <= ALen) and (S[J] in [#9, #10, #13, ' ']) do
        Inc(J);
      if J + N - 1 <= ALen then
      begin
        K := 0;
        while (K < N) and (ToLower(Byte(S[J + K])) = ToLower(Byte(AName[K + 1]))) do
          Inc(K);
        if (K = N) and ((J + N > ALen) or not IsAlphaNum(Byte(S[J + N]))) then
        begin
          AAfterGt := J + N;
          SkipToCloseBracket(S, AAfterGt, ALen, False);
          Exit(True);
        end;
      end;
    end;
    Inc(I);
  end;
  Result := False;
end;

function FindMarker(const S: string; AFrom: Integer; const AMarker: string;
  out AAfter: Integer): Boolean;
var
  ALen, N, I: Integer;
begin
  ALen := Length(S);
  N := Length(AMarker);
  I := AFrom;
  while I + N - 1 <= ALen do
  begin
    if Copy(S, I, N) = AMarker then
    begin
      AAfter := I + N;
      Exit(True);
    end;
    Inc(I);
  end;
  Result := False;
end;

{ 处理 LPos 处的 '<' 构造，返回新的扫描位置（所有路径都前进，不会死循环）。 }
function HandleMarkup(const S: string; const ALen: Integer; LPos: Integer;
  var AState: THtmlExtractState): Integer;
var
  LName: string;
  LHref, LAlt: string;
  LP2, LSkip, LEnd, NStart, NEnd: Integer;
begin
  if LPos + 1 > ALen then
  begin
    AppendTextRun(AState, @S[LPos], 1);
    Exit(LPos + 1);
  end;
  case S[LPos + 1] of
    '!':
      begin
        if (LPos + 3 <= ALen) and (S[LPos + 2] = '-') and (S[LPos + 3] = '-') then
        begin
          { <!-- 注释 --> }
          if FindMarker(S, LPos + 4, '-->', LEnd) then
            Exit(LEnd)
          else
            Exit(ALen + 1);
        end
        else if (LPos + 8 <= ALen) and (Copy(S, LPos + 2, 7) = '[CDATA[') then
        begin
          { <![CDATA[ ... ]]>：内容整体舍弃 }
          if FindMarker(S, LPos + 9, ']]>', LEnd) then
            Exit(LEnd)
          else
            Exit(ALen + 1);
        end
        else
        begin
          { <!DOCTYPE ...> 等声明 }
          LP2 := LPos + 2;
          SkipToCloseBracket(S, LP2, ALen, True);
          Exit(LP2);
        end;
      end;
    '?':
      begin
        { <?xml ... ?> 处理指令 }
        LP2 := LPos + 2;
        SkipToCloseBracket(S, LP2, ALen, False);
        Exit(LP2);
      end;
    '/':
      begin
        { 闭合标签 }
        LP2 := LPos + 2;
        while (LP2 <= ALen) and (S[LP2] in [#9, #10, #13, ' ']) do
          Inc(LP2);
        NStart := LP2;
        while (LP2 <= ALen) and (IsAlphaNum(Byte(S[LP2])) or (S[LP2] = '-')) do
          Inc(LP2);
        if LP2 > NStart then
        begin
          LName := AsciiLowerCase(Copy(S, NStart, LP2 - NStart));
          SkipToCloseBracket(S, LP2, ALen, False);
          Result := LP2;
          if LName = 'a' then
          begin
            if AState.Options.KeepLinks and (AState.AnchorHref <> '') and
              AState.AnchorHadText then
            begin
              AState.Out.AppendStr(' (');
              AState.Out.AppendStr(AState.AnchorHref);
              AState.Out.AppendStr(')');
            end;
            AState.AnchorHref := '';
            AState.AnchorHadText := False;
          end
          else if IsBlockElement(LName) or
            (AState.Options.KeepHeadings and IsHeadingElement(LName)) then
            AState.PendingBreak := True;
        end
        else
        begin
          { 空标签名 '</>'：整体跳过 }
          SkipToCloseBracket(S, LP2, ALen, False);
          Result := LP2;
        end;
      end;
  else
    begin
      { 打开标签（或字面 '<' 文本） }
      if not IsAlpha(Byte(S[LPos + 1])) then
      begin
        AppendTextRun(AState, @S[LPos], 1);
        Exit(LPos + 1);
      end;
      NEnd := LPos + 1;
      while (NEnd <= ALen) and (IsAlphaNum(Byte(S[NEnd])) or (S[NEnd] = '-')) do
        Inc(NEnd);
      LName := AsciiLowerCase(Copy(S, LPos + 1, NEnd - (LPos + 1)));
      ParseOpenTag(S, NEnd, LHref, LAlt, LEnd);
      Result := LEnd;
      if IsHiddenElement(LName) then
      begin
        { script/style/noscript/head：内容剔除；找不到闭合则吞掉剩余输入 }
        if FindCloseTag(S, LEnd, LName, LSkip) then
          Result := LSkip
        else
          Result := ALen + 1;
      end
      else if LName = 'a' then
      begin
        AState.AnchorHref := HtmlDecodeEntities(LHref);
        AState.AnchorHadText := False;
      end
      else if LName = 'img' then
      begin
        LAlt := HtmlDecodeEntities(LAlt);
        if LAlt <> '' then
          AppendTextRun(AState, LAlt);
      end
      else if (LName = 'br') or (LName = 'hr') then
        AState.PendingBreak := True
      else if IsBlockElement(LName) or
        (AState.Options.KeepHeadings and IsHeadingElement(LName)) then
        AState.PendingBreak := True;
    end;
  end;
end;

function TrimEndsWs(const AStr: string): string;
var
  L, LStart: Integer;
begin
  L := Length(AStr);
  while (L > 0) and (Byte(AStr[L]) in [9, 10, 12, 13, 32]) do
    Dec(L);
  LStart := 1;
  while (LStart <= L) and (Byte(AStr[LStart]) in [9, 10, 12, 13, 32]) do
    Inc(LStart);
  Result := Copy(AStr, LStart, L - LStart + 1);
end;

function ExtractText(const AHtml: string; const AOptions: THtmlExtractOptions): string;
var
  ALen, LPos, LRunStart: Integer;
  LCP: UInt32;
  LDecoded: string;
  AState: THtmlExtractState;
begin
  ALen := Length(AHtml);
  AState.Options := AOptions;
  AState.PendingBreak := False;
  AState.AtLineStart := True;
  AState.PendingSpace := False;
  AState.AnchorHref := '';
  AState.AnchorHadText := False;
  AState.Out.Init(256);
  try
    LPos := 1;
    if (ALen >= 3) and (AHtml[1] = #$EF) and (AHtml[2] = #$BB) and (AHtml[3] = #$BF) then
      LPos := 4; { 跳过 UTF-8 BOM }
    while LPos <= ALen do
    begin
      case AHtml[LPos] of
        '<':
          LPos := HandleMarkup(AHtml, ALen, LPos, AState);
        '&':
          begin
            if TryNumericEntity(AHtml, LPos, LCP) then
            begin
              LDecoded := UTF8EncodeToStr(LCP);
              AppendTextRun(AState, @LDecoded[1], Length(LDecoded));
            end
            else if TryNamedEntity(AHtml, LPos, LDecoded) then
              AppendTextRun(AState, LDecoded)
            else
            begin
              AppendTextRun(AState, @AHtml[LPos], 1);
              Inc(LPos);
            end;
          end;
      else
        begin
          LRunStart := LPos;
          while (LPos <= ALen) and (AHtml[LPos] <> '<') and (AHtml[LPos] <> '&') do
            Inc(LPos);
          AppendTextRun(AState, @AHtml[LRunStart], LPos - LRunStart);
        end;
      end;
    end;
    Result := TrimEndsWs(AState.Out.ToString);
  finally
    AState.Out.Done;
  end;
end;

function HtmlTextOf(const AHtml: string): string;
begin
  Result := HtmlTextOf(AHtml, DefaultHtmlExtractOptions);
end;

function HtmlTextOf(const AHtml: string; const AOptions: THtmlExtractOptions): string;
begin
  if Length(AHtml) > MaxHtmlInputLength then
    raise EArgumentError.CreateFmt('html input length %d exceeds MaxHtmlInputLength',
      [Length(AHtml)]);
  Result := ExtractText(AHtml, AOptions);
end;

function TryHtmlTextOf(const AHtml: string; out AText: string): Boolean;
begin
  Result := TryHtmlTextOf(AHtml, DefaultHtmlExtractOptions, AText);
end;

function TryHtmlTextOf(const AHtml: string; const AOptions: THtmlExtractOptions;
  out AText: string): Boolean;
begin
  if Length(AHtml) > MaxHtmlInputLength then
  begin
    AText := '';
    Exit(False);
  end;
  AText := ExtractText(AHtml, AOptions);
  Result := True;
end;

end.