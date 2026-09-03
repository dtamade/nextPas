unit nextpas.core.deliverability.dkim;
{**
 * @desc DKIM 验签/签名(RFC 6376 rsa-sha256 + RFC 8463 ed25519-sha256)。
 *       simple/relaxed 头体规范化、body hash 前置校验、SPKI 公钥解析、
 *       PKCS#1 v1.5 常量时间比较(INV-5~8, 契约 §3/§4)。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.deliverability.base;

{ 解析 DKIM-Signature 头值 tag=value; 缺必需 tag 或坏 base64 → False }
function DkimParseSignature(const AValue: string; out ASig: TDkimSignature;
  out AError: string): Boolean;

{ 规范化(RFC 6376 §3.4): 头/体; 结果行间 CRLF、体尾部单 CRLF }
function DkimCanonicalizeBody(const ABody: string; const ACanon: TCanonMode): string;
function DkimCanonicalizeHeader(const AName, AValue: string;
  const ACanon: TCanonMode): string;

{ 构建签名数据(h= 自底向上 + DKIM-Signature b= 置空; CRLF 连接无尾 CRLF) }
function DkimBuildHeaderHashInput(const ARawMail: string;
  const ASig: TDkimSignature; out AData: TBytes; out AError: string): Boolean;

{ 验签: 校验 body hash 后取 <selector>._domainkey.<domain> TXT 的 p= }
function DkimVerify(const ADns: IDeliverabilityDns; const ARawMail: string;
  const ATimeoutMs: Int32; out AError: string): TDkimResult;

{ 签名(底层): rsa-sha256 = PKCS#1 v1.5 编码后 EM^d mod n;
  ed25519-sha256 = RFC 8463 §5.4 对输入原文直接 Ed25519 签名 }
function DkimSign(const AHdrHashInput: TBytes; const AAlgo: TDkimAlgo;
  const ARsaModulus, ARsaPrivateExponent: TBytes;
  const AEd25519PrivateKey: TBytes; out ASignature: TBytes;
  out AError: string): Boolean;

{ 提取/展开首个 DKIM-Signature 头值(含折叠展开); 无 → False }
function DkimExtractSignatureValue(const ARawMail: string;
  out AValue: string): Boolean;

{ DKIM-Signature 值中 b= 的值置空(RFC 6376 §3.7), 其余 tag 原样; 避开 bh= }
function DkimRemoveBValue(const AValue: string): string;

{ 加载 RSA 私钥 PEM(无加密 PKCS#8 "BEGIN PRIVATE KEY" 与传统 PKCS#1
  "BEGIN RSA PRIVATE KEY"); 取 n/d; 加密块/非 RSA/坏 DER → False }
function DkimLoadRsaPrivateKey(const APemText: string; out AModulus,
  APrivateExponent: TBytes; out AError: string): Boolean;

{ 签名组装(RFC 6376 §3.5/§3.7): bh → 构造 DKIM-Signature(物理第一个
  头, b= 空占位)→ DkimBuildHeaderHashInput + DkimSign → 填 b= 输出完整
  邮件; h= 须含 from; 线格式钉死见契约 §3(plan 2026-08-25) }
function DkimSignMail(const ARawMail: string; const ADomain,
  ASelector: string; const ASignedHeaders: TDeliverabilityStringArray;
  const ACanonHeader, ACanonBody: TCanonMode; const AAlgo: TDkimAlgo;
  const ARsaModulus, ARsaPrivateExponent: TBytes;
  const AEd25519PrivateKey: TBytes; out ASignedMail: string;
  out AError: string): Boolean;

implementation

uses
  nextpas.core.crypto.asn1,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.rsa,
  nextpas.core.encoding.base64,
  nextpas.core.exception,
  nextpas.core.hash,
  nextpas.core.io.intf,
  nextpas.core.tls.pem;

{ ── 助手(无 SysUtils) ────────────────────────────────────────── }

function TrimAscii(const AStr: string): string;
var
  L, R: Integer;
begin
  L := 1;
  while (L <= Length(AStr)) and (AStr[L] <= ' ') do
    Inc(L);
  R := Length(AStr);
  while (R >= L) and (AStr[R] <= ' ') do
    Dec(R);
  Result := Copy(AStr, L, R - L + 1);
end;

function LowerAscii(const AStr: string): string;
var
  I: Integer;
begin
  Result := AStr;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Inc(Result[I], 32);
end;

function Sha256Of(const AData: TBytes): TBytes;
var
  LH: IHasher;
begin
  LH := NewSHA256;
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  Result := LH.SumBytes;
end;

function BytesToString(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(AData));
  for I := 1 to Length(AData) do
    Result[I] := Chr(AData[I - 1]);
end;

function StrToBytes(const AStr: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AStr));
  for I := 1 to Length(AStr) do
    Result[I - 1] := Byte(AStr[I]);
end;

{ 宽松 base64: 去空白、补 padding(RFC 4648 §3.2 允许省略 '=') }
function DecodeBase64Loose(const AEncoded: string; out AData: TBytes): Boolean;
var
  LClean: string;
  LI, LRem: Integer;
begin
  Result := False;
  LClean := '';
  for LI := 1 to Length(AEncoded) do
    if AEncoded[LI] > ' ' then
      LClean := LClean + AEncoded[LI];
  LRem := Length(LClean) mod 4;
  if LRem = 1 then
    Exit;
  if LRem = 2 then
    LClean := LClean + '=='
  else if LRem = 3 then
    LClean := LClean + '=';
  { 预检字符集: Base64Decode 对非法字符 raise EConvertError(core 无
    异常捕获), 错误路径必须优雅返回 False }
  for LI := 1 to Length(LClean) do
    if not ((LClean[LI] in ['A'..'Z', 'a'..'z', '0'..'9', '+', '/', '='])) then
      Exit;
  AData := Base64Decode(LClean);
  if Length(LClean) > 0 then
  begin
    { Base64Decode 失败返回什么?长度 0 与合法空串冲突, 以内容长度校验 }
    if Length(AData) = 0 then
      Exit;
  end;
  Result := True;
end;

{ tag-list 中取值(RFC 6376 §3.2: ';' 分段, tag 名大小写不敏感);
  首 tag 若为 v= 且值 ≠ DKIM1 → 该记录作废(Result=False, AIsVersionMismatch) }
function FindKeyTagValue(const ARecord: string; const ATagName: string;
  out AValue: string; out AFirstIsV, AVersionMismatch: Boolean): Boolean;
var
  LI, LEq: Integer;
  LPart, LTag: string;
  LFirst: Boolean;
begin
  Result := False;
  AFirstIsV := False;
  AVersionMismatch := False;
  AValue := '';
  LFirst := True;
  LI := 1;
  while LI <= Length(ARecord) do
  begin
    LPart := '';
    while (LI <= Length(ARecord)) and (ARecord[LI] <> ';') do
    begin
      LPart := LPart + ARecord[LI];
      Inc(LI);
    end;
    LPart := TrimAscii(LPart);
    if LPart <> '' then
    begin
      LEq := Pos('=', LPart);
      if LEq = 0 then
        Exit;                    { 无 '=' 段: 记录格式错误 }
      LTag := LowerAscii(TrimAscii(Copy(LPart, 1, LEq - 1)));
      if LFirst then
      begin
        LFirst := False;
        AFirstIsV := LTag = 'v';
        if LTag = 'v' then
        begin
          AVersionMismatch := TrimAscii(Copy(LPart, LEq + 1, MaxInt))
            <> 'DKIM1';
          if AVersionMismatch then
            Exit;
        end;
      end;
      if (not Result) and (LTag = ATagName) then
      begin
        AValue := TrimAscii(Copy(LPart, LEq + 1, MaxInt));
        Result := True;
      end;
    end;
    if LI <= Length(ARecord) then
      Inc(LI);
  end;
end;

{ ── 行/头解析 ────────────────────────────────────────────────── }

type
  THeaderLine = record
    Name: string;
    Value: string;               { 含折叠换行(\r\n 保留) }
  end;
  THeaderArray = array of THeaderLine;

{ 按 \n 分行, 去行尾 \r; body 规范化共用 }
function SplitLines(const AText: string): TDeliverabilityStringArray;
var
  LStart, LP: Integer;
begin
  Result := nil;
  LStart := 1;
  LP := 1;
  while LP <= Length(AText) + 1 do
  begin
    if (LP > Length(AText)) or (AText[LP] = #10) then
    begin
      SetLength(Result, Length(Result) + 1);
      if (LP > LStart) and (AText[LP - 1] = #13) then
        Result[High(Result)] := Copy(AText, LStart, LP - 1 - LStart)
      else
        Result[High(Result)] := Copy(AText, LStart, LP - LStart);
      LStart := LP + 1;
    end;
    Inc(LP);
  end;
end;

{ 头区 = 首个空行前; 空行以 \r\n\r\n 或 \n\n 判定 }
function ExtractHeadersSection(const ARawMail: string; out ABody: string;
  out AHasBody: Boolean): string;
var
  LIdx: Integer;
begin
  AHasBody := False;
  LIdx := Pos(#13#10#13#10, ARawMail);
  if LIdx > 0 then
  begin
    Result := Copy(ARawMail, 1, LIdx - 1);
    ABody := Copy(ARawMail, LIdx + 4, MaxInt);
    AHasBody := True;
    Exit;
  end;
  LIdx := Pos(#10#10, ARawMail);
  if LIdx > 0 then
  begin
    Result := Copy(ARawMail, 1, LIdx - 1);
    ABody := Copy(ARawMail, LIdx + 2, MaxInt);
    AHasBody := True;
    Exit;
  end;
  Result := ARawMail;
  ABody := '';
end;

function ParseHeaders(const ASection: string): THeaderArray;
var
  LLines: TDeliverabilityStringArray;
  LI, LColon: Integer;
begin
  Result := nil;
  LLines := SplitLines(ASection);
  for LI := 0 to High(LLines) do
  begin
    if (Length(LLines[LI]) > 0) and
      ((LLines[LI][1] = ' ') or (LLines[LI][1] = #9)) then
    begin
      { 折叠续行 }
      if Length(Result) > 0 then
        Result[High(Result)].Value :=
          Result[High(Result)].Value + #13#10 + LLines[LI];
      Continue;
    end;
    LColon := Pos(':', LLines[LI]);
    if LColon <= 0 then
      Continue;                  { 非头行(空行已截断; 防御) }
    { 原始名/值保留(RFC 6376 §3.4.1 simple 要求原封不动) }
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].Name := Copy(LLines[LI], 1, LColon - 1);
    Result[High(Result)].Value := Copy(LLines[LI], LColon + 1, MaxInt);
  end;
end;

{ 找首个 DKIM-Signature 头值(含折叠展开) }
function DkimExtractSignatureValue(const ARawMail: string;
  out AValue: string): Boolean;
var
  LHeaders, LBody: string;
  LHasBody: Boolean;
  LList: THeaderArray;
  LV: string;
  LI: Integer;
begin
  Result := False;
  AValue := '';
  LHeaders := ExtractHeadersSection(ARawMail, LBody, LHasBody);
  LList := ParseHeaders(LHeaders);
  for LI := 0 to High(LList) do
    if LowerAscii(LList[LI].Name) = 'dkim-signature' then
    begin
      { 折叠展开: 去 \r\n }
      LV := LList[LI].Value;
      while Pos(#13#10, LV) > 0 do
        Delete(LV, Pos(#13#10, LV), 2);
      AValue := TrimAscii(LV);
      Result := AValue <> '';
      Exit;
    end;
end;

{ ── 签名解析 ─────────────────────────────────────────────────── }

function DkimParseSignature(const AValue: string; out ASig: TDkimSignature;
  out AError: string): Boolean;
var
  LTagMap: TDeliverabilityStringArray;
  LPart, LKey, LVal: string;
  LI, LEq: Integer;
  LAlgo: string;
  LCanon: string;
  LCSlash: Integer;
  LCHdr, LCBody: string;
  LHasV, LHasAlgo, LHasB, LHasBH, LHasD, LHasH, LHasS: Boolean;
begin
  Result := False;
  AError := '';
  { out 参数必须先显式置位; c= 缺省(simple/simple)分支不写 Canon*
    字段, 未初始化即使用 → 栈垃圾(RFC 6376 §3.5: c= 缺省 simple) }
  ASig.Algo := daRsaSha256;
  ASig.Domain := '';
  ASig.Selector := '';
  ASig.SignedHeaders := nil;
  ASig.CanonHeader := cmSimple;
  ASig.CanonBody := cmSimple;
  ASig.Signature := nil;
  ASig.BodyHash := nil;
  LHasV := False; LHasAlgo := False; LHasB := False; LHasBH := False;
  LHasD := False; LHasH := False; LHasS := False;
  { 分段 }
  LTagMap := nil;
  LI := 1;
  while LI <= Length(AValue) do
  begin
    LPart := '';
    while (LI <= Length(AValue)) and (AValue[LI] <> ';') do
    begin
      LPart := LPart + AValue[LI];
      Inc(LI);
    end;
    LPart := TrimAscii(LPart);
    LEq := Pos('=', LPart);
    if LEq > 0 then
    begin
      LKey := LowerAscii(TrimAscii(Copy(LPart, 1, LEq - 1)));
      LVal := TrimAscii(Copy(LPart, LEq + 1, MaxInt));
      if (LKey <> 'b') and (LKey <> 'bh') then
      begin
        SetLength(LTagMap, Length(LTagMap) + 1);
        LTagMap[High(LTagMap)] := LKey + '=' + LVal;
      end;
      { b=/bh= 单独取(去空白+宽松解码) }
      if LKey = 'b' then
      begin
        if not DecodeBase64Loose(LVal, ASig.Signature) then
        begin
          AError := 'invalid b= base64';
          Exit;
        end;
        LHasB := True;
      end
      else if LKey = 'bh' then
      begin
        if not DecodeBase64Loose(LVal, ASig.BodyHash) then
        begin
          AError := 'invalid bh= base64';
          Exit;
        end;
        LHasBH := True;
      end;
    end;
    if LI <= Length(AValue) then
      Inc(LI);
  end;

  { 必需 tag }
  for LI := 0 to High(LTagMap) do
  begin
    LPart := LTagMap[LI];
    LEq := Pos('=', LPart);
    LKey := Copy(LPart, 1, LEq - 1);
    LVal := Copy(LPart, LEq + 1, MaxInt);
    case LKey of
      'v':
        begin
          { RFC 6376 §3.5: v= REQUIRED 且必须为 1 }
          if LVal <> '1' then
          begin
            AError := 'unsupported DKIM version: ' + LVal;
            Exit;
          end;
          LHasV := True;
        end;
      'a':
        begin
          LAlgo := LowerAscii(LVal);
          LHasAlgo := True;
        end;
      'd':
        begin
          ASig.Domain := LowerAscii(LVal);
          LHasD := True;
        end;
      's':
        begin
          ASig.Selector := LowerAscii(LVal);
          LHasS := True;
        end;
      'c':
        begin
          { RFC 6376 §3.5 ABNF: c-hdr-alg ["/" c-body-alg]; 缺省体算法 = simple }
          LCanon := LowerAscii(LVal);
          LCSlash := Pos('/', LCanon);
          if LCSlash = 0 then
          begin
            LCHdr := LCanon;
            LCBody := 'simple';
          end
          else
          begin
            LCHdr := Copy(LCanon, 1, LCSlash - 1);
            LCBody := Copy(LCanon, LCSlash + 1, MaxInt);
          end;
          if LCHdr = 'relaxed' then
            ASig.CanonHeader := cmRelaxed
          else if LCHdr <> 'simple' then
          begin
            AError := 'unsupported header canonicalization: ' + LCHdr;
            Exit;
          end;
          if LCBody = 'relaxed' then
            ASig.CanonBody := cmRelaxed
          else if LCBody <> 'simple' then
          begin
            AError := 'unsupported body canonicalization: ' + LCBody;
            Exit;
          end;
        end;
      'h':
        begin
          { h= 冒号分隔, 小写 }
          SetLength(ASig.SignedHeaders, 0);
          while Length(LVal) > 0 do
          begin
            if Pos(':', LVal) = 0 then
            begin
              if TrimAscii(LVal) <> '' then
              begin
                SetLength(ASig.SignedHeaders,
                  Length(ASig.SignedHeaders) + 1);
                ASig.SignedHeaders[High(ASig.SignedHeaders)] :=
                  LowerAscii(TrimAscii(LVal));
              end;
              LVal := '';
            end
            else
            begin
              if TrimAscii(Copy(LVal, 1, Pos(':', LVal) - 1)) <> '' then
              begin
                SetLength(ASig.SignedHeaders,
                  Length(ASig.SignedHeaders) + 1);
                ASig.SignedHeaders[High(ASig.SignedHeaders)] :=
                  LowerAscii(TrimAscii(Copy(LVal, 1, Pos(':', LVal) - 1)));
              end;
              Delete(LVal, 1, Pos(':', LVal));
            end;
          end;
          LHasH := True;
        end;
    end;
  end;

  if LAlgo = 'rsa-sha256' then
    ASig.Algo := daRsaSha256
  else if LAlgo = 'ed25519-sha256' then
    ASig.Algo := daEd25519Sha256
  else
  begin
    AError := 'unsupported algorithm: ' + LAlgo;
    Exit;
  end;

  if not (LHasV and LHasAlgo and LHasB and LHasBH and LHasD and LHasH
    and LHasS) then
  begin
    AError := 'missing required tag';
    Exit;
  end;
  Result := True;
end;

{ ── 规范化 ───────────────────────────────────────────────────── }

function DkimCanonicalizeBody(const ABody: string; const ACanon: TCanonMode): string;
var
  LLines: TDeliverabilityStringArray;
  LTrimmed: string;
  LI, LJ, LCount: Integer;
  LLastWs: Boolean;
begin
  LLines := SplitLines(ABody);
  for LI := 0 to High(LLines) do
    if ACanon = cmRelaxed then
    begin
      { 压缩 WSP 序列 → 单 SP }
      LTrimmed := '';
      LLastWs := False;
      for LJ := 1 to Length(LLines[LI]) do
        if (LLines[LI][LJ] = ' ') or (LLines[LI][LJ] = #9) then
        begin
          if not LLastWs then
            LTrimmed := LTrimmed + ' ';
          LLastWs := True;
        end
        else
        begin
          LTrimmed := LTrimmed + LLines[LI][LJ];
          LLastWs := False;
        end;
      while (Length(LTrimmed) > 0) and (LTrimmed[Length(LTrimmed)] = ' ') do
        Delete(LTrimmed, Length(LTrimmed), 1);
      LLines[LI] := LTrimmed;
    end;
  { 去尾部空行 }
  LCount := High(LLines);
  while (LCount >= 0) and (LLines[LCount] = '') do
    Dec(LCount);
  if LCount < 0 then
  begin
    { RFC 6376 §3.4.3/§3.4.4: 空体 simple→单 CRLF, relaxed→null input }
    if ACanon = cmSimple then
      Result := #13#10
    else
      Result := '';
    Exit;
  end;
  Result := '';
  for LI := 0 to LCount do
  begin
    if LI > 0 then
      Result := Result + #13#10;
    Result := Result + LLines[LI];
  end;
  Result := Result + #13#10;    { RFC 6376 §3.4.3: 以单 CRLF 终止 }
end;

function DkimCanonicalizeHeader(const AName, AValue: string;
  const ACanon: TCanonMode): string;
var
  LName, LVal, LUnfolded: string;
  LI: Integer;
  LLastWs: Boolean;
begin
  if ACanon = cmSimple then
  begin
    { RFC 6376 §3.4.1: 原封不动(含冒号两侧空白与大小写) }
    Result := AName + ':' + AValue;
    Exit;
  end;
  { relaxed: 名小写(去 WSP) + 值折叠展开/压缩/去端部, 无 ':' 后空格 }
  LName := '';
  for LI := 1 to Length(AName) do
    if (AName[LI] <> ' ') and (AName[LI] <> #9) then
      LName := LName + AName[LI];
  LName := LowerAscii(LName);
  LUnfolded := '';
  for LI := 1 to Length(AValue) do
    if (AValue[LI] <> #10) and (AValue[LI] <> #13) then
      LUnfolded := LUnfolded + AValue[LI];
  LVal := '';
  LLastWs := False;
  for LI := 1 to Length(LUnfolded) do
    if (LUnfolded[LI] = ' ') or (LUnfolded[LI] = #9) then
    begin
      if not LLastWs then
        LVal := LVal + ' ';
      LLastWs := True;
    end
    else
    begin
      LVal := LVal + LUnfolded[LI];
      LLastWs := False;
    end;
  while (Length(LVal) > 0) and (LVal[Length(LVal)] = ' ') do
    Delete(LVal, Length(LVal), 1);
  while (Length(LVal) > 0) and (LVal[1] = ' ') do
    Delete(LVal, 1, 1);
  Result := LName + ':' + LVal;
end;

{ 去 DKIM-Signature 值中 b= 的值(保留 'b='; 避开 bh=);
  其余段原样保留(RFC 6376 §3.7: 仅 b= 值部分置空) }
function DkimRemoveBValue(const AValue: string): string;
var
  LOut, LPart, LTag: string;
  LI, LEq: Integer;
begin
  LOut := '';
  LI := 1;
  while LI <= Length(AValue) do
  begin
    LPart := '';
    while (LI <= Length(AValue)) and (AValue[LI] <> ';') do
    begin
      LPart := LPart + AValue[LI];
      Inc(LI);
    end;
    if LPart <> '' then
    begin
      LTag := LowerAscii(TrimAscii(LPart));
      if (Pos('b=', LTag) = 1) and (Pos('bh=', LTag) <> 1) then
      begin
        LEq := Pos('=', LPart);
        LOut := LOut + Copy(LPart, 1, LEq) + ';';
      end
      else
        LOut := LOut + LPart + ';';
    end;
    if LI <= Length(AValue) then
      Inc(LI);
  end;
  while (Length(LOut) > 0) and (LOut[Length(LOut)] = ';') do
    Delete(LOut, Length(LOut), 1);
  Result := LOut;
end;

{ ── 签名数据构建 ─────────────────────────────────────────────── }

function DkimBuildHeaderHashInput(const ARawMail: string;
  const ASig: TDkimSignature; out AData: TBytes; out AError: string): Boolean;
var
  LHeaders, LBody: string;
  LHasBody: Boolean;
  LList: THeaderArray;
  LUsed: array of Boolean;
  LOut: string;
  LWanted, LVal: string;
  LI, LJ: Integer;
  LFound: Boolean;
  LDkimIdx: Integer;
begin
  Result := False;
  AError := '';
  LHeaders := ExtractHeadersSection(ARawMail, LBody, LHasBody);
  LList := ParseHeaders(LHeaders);
  SetLength(LUsed, Length(LList));
  LOut := '';

  { 正在验证的 DKIM-Signature = 物理第一个(RFC 6376 §6.1) }
  LDkimIdx := -1;
  for LJ := 0 to High(LList) do
    if LowerAscii(LList[LJ].Name) = 'dkim-signature' then
    begin
      LDkimIdx := LJ;
      Break;
    end;
  if LDkimIdx < 0 then
  begin
    AError := 'dkim-signature header missing';
    Exit;
  end;

  { h= 依序取头(INV-6); 不存在的头 = null input(RFC 6376 §3.5 跳过) }
  for LI := 0 to High(ASig.SignedHeaders) do
  begin
    LWanted := ASig.SignedHeaders[LI];
    LFound := False;
    for LJ := High(LList) downto 0 do
      if (not LUsed[LJ]) and (LJ <> LDkimIdx) and
        (LowerAscii(LList[LJ].Name) = LWanted) then
      begin
        LUsed[LJ] := True;
        LFound := True;
        if LWanted = 'dkim-signature' then
          LVal := DkimRemoveBValue(LList[LJ].Value)
        else
          LVal := LList[LJ].Value;
        if LOut <> '' then
          LOut := LOut + #13#10;
        LOut := LOut + DkimCanonicalizeHeader(LList[LJ].Name, LVal,
          ASig.CanonHeader);
        Break;
      end;
    if not LFound then
      Continue;                  { null input: 不影响签名数据 }
  end;

  { DKIM-Signature 自身: 若 h= 未用, 追加(b= 置空, 无尾 CRLF) }
  if not LUsed[LDkimIdx] then
  begin
    LVal := DkimRemoveBValue(LList[LDkimIdx].Value);
    if LOut <> '' then
      LOut := LOut + #13#10;
    LOut := LOut + DkimCanonicalizeHeader(LList[LDkimIdx].Name, LVal,
      ASig.CanonHeader);
  end;

  SetLength(AData, Length(LOut));
  for LI := 1 to Length(LOut) do
    AData[LI - 1] := Byte(LOut[LI]);
  Result := True;
end;

{ ── 密钥解析 ─────────────────────────────────────────────────── }

{ DER INTEGER 符号位前导 00 → 数值无符号表示 }
procedure StripIntegerPad(var AData: TBytes);
begin
  if (Length(AData) > 1) and (AData[0] = 0) then
  begin
    Move(AData[1], AData[0], Length(AData) - 1);
    SetLength(AData, Length(AData) - 1);
  end;
end;

{ SPKI DER → RSA n/e(INTEGER 原始字节) }
function TryParseRsaSpki(const ADer: TBytes; out AModulus,
  AExponent: TBytes): Boolean;
var
  LReader, LInner: TASN1Reader;
  LRoot, LAlgoSeq, LKeySeq, LKeyBit, LN, LE: TASN1Node;
begin
  Result := False;
  LRoot := nil;
  LKeySeq := nil;
  LReader := TASN1Reader.Create(ADer);
  try
    LRoot := LReader.Parse;
    if LRoot = nil then
      Exit;
    if (LRoot.ChildCount < 2) or (not LRoot.IsSequence) then
      Exit;
    LAlgoSeq := LRoot.GetChild(0);
    LKeyBit := LRoot.GetChild(1);
    if (LAlgoSeq = nil) or (LKeyBit = nil) or (not LKeyBit.IsBitString) then
      Exit;
    { BIT STRING 内容 = 内部 SEQUENCE(INTEGER n, INTEGER e) }
    LInner := TASN1Reader.Create(LKeyBit.AsBitString);
    try
      LKeySeq := LInner.Parse;
    finally
      LInner.Free;
    end;
    if (LKeySeq = nil) or (LKeySeq.ChildCount < 2) or
      (not LKeySeq.IsSequence) then
      Exit;
    LN := LKeySeq.GetChild(0);
    LE := LKeySeq.GetChild(1);
    if (LN = nil) or (LE = nil) or (not LN.IsInteger) or
      (not LE.IsInteger) then
      Exit;
    AModulus := LN.AsBigInteger;
    AExponent := LE.AsBigInteger;
    { DER INTEGER 符号位前导 00 → 数值无符号表示(模长按实际位宽) }
    StripIntegerPad(AModulus);
    StripIntegerPad(AExponent);
    if (Length(AModulus) = 0) or (Length(AExponent) = 0) then
      Exit;
    Result := True;
  finally
    LRoot.Free;
    LKeySeq.Free;
    LReader.Free;
  end;
end;

{ RSAPrivateKey DER: SEQUENCE 内 version=0, n, e, d, p… → 取 n/d }
function TryParseRsaPkcs1Private(const ADer: TBytes; out AModulus,
  APrivateExponent: TBytes): Boolean;
var
  LReader: TASN1Reader;
  LRoot, LVer, LN, LD: TASN1Node;
begin
  Result := False;
  LRoot := nil;
  LReader := TASN1Reader.Create(ADer);
  try
    LRoot := LReader.Parse;
    if (LRoot = nil) or (not LRoot.IsSequence) or (LRoot.ChildCount < 4) then
      Exit;
    LVer := LRoot.GetChild(0);
    if (LVer = nil) or (not LVer.IsInteger) or (LVer.AsInteger <> 0) then
      Exit;                        { 仅 PKCS#1 v1.5 单素数形态(RFC 8017) }
    LN := LRoot.GetChild(1);
    LD := LRoot.GetChild(3);
    if (LN = nil) or (LD = nil) or (not LN.IsInteger) or
      (not LD.IsInteger) then
      Exit;
    AModulus := LN.AsBigInteger;
    APrivateExponent := LD.AsBigInteger;
    StripIntegerPad(AModulus);
    StripIntegerPad(APrivateExponent);
    Result := (Length(AModulus) > 0) and (Length(APrivateExponent) > 0);
  finally
    LRoot.Free;
    LReader.Free;
  end;
end;

{ PKCS#8 PrivateKeyInfo DER → 内层 RSAPrivateKey 的 n/d;
  algorithm OID 必须 rsaEncryption(非 RSA 私钥拒绝) }
function TryUnwrapPkcs8RsaPrivate(const ADer: TBytes; out AModulus,
  APrivateExponent: TBytes): Boolean;
var
  LReader: TASN1Reader;
  LRoot, LAlgoSeq, LOid, LOctet: TASN1Node;
  LKeyDer: TBytes;
begin
  Result := False;
  LRoot := nil;
  LReader := TASN1Reader.Create(ADer);
  try
    LRoot := LReader.Parse;
    if (LRoot = nil) or (not LRoot.IsSequence) or (LRoot.ChildCount < 3) then
      Exit;
    if (not LRoot.GetChild(0).IsInteger) or
      (LRoot.GetChild(0).AsInteger <> 0) then
      Exit;
    LAlgoSeq := LRoot.GetChild(1);
    if (LAlgoSeq = nil) or (not LAlgoSeq.IsSequence) or
      (LAlgoSeq.ChildCount < 1) then
      Exit;
    LOid := LAlgoSeq.GetChild(0);
    if (LOid = nil) or (not LOid.IsOID) then
      Exit;
    if LOid.AsOID <> '1.2.840.113549.1.1.1' then
      Exit;                        { rsaEncryption 以外不支持 }
    LOctet := LRoot.GetChild(2);
    if (LOctet = nil) or (not LOctet.IsOctetString) then
      Exit;
    LKeyDer := LOctet.AsOctetString;
    Result := TryParseRsaPkcs1Private(LKeyDer, AModulus, APrivateExponent);
  finally
    LRoot.Free;
    LReader.Free;
  end;
end;

function DkimLoadRsaPrivateKey(const APemText: string; out AModulus,
  APrivateExponent: TBytes; out AError: string): Boolean;
var
  LRdr: TPEMReader;
  LBlock: TPEMBlock;
begin
  Result := False;
  AError := '';
  AModulus := nil;
  APrivateExponent := nil;
  LRdr := TPEMReader.Create;
  try
    try
      LRdr.LoadFromString(APemText);
    except
      on LE: Exception do
      begin
        AError := 'pem parse failed: ' + LE.Message;
        Exit;
      end;
    end;
    { PKCS#8 优先, 传统 PKCS#1 兜底; 加密块明确报错不做解密 }
    LBlock := LRdr.GetFirstBlockOfType(pemPrivateKey);
    if Length(LBlock.Data) = 0 then
      LBlock := LRdr.GetFirstBlockOfType(pemRSAPrivateKey);
    if Length(LBlock.Data) = 0 then
    begin
      if Length(LRdr.GetFirstBlockOfType(pemEncryptedPrivateKey).Data) > 0 then
        AError := 'encrypted private key not supported'
      else
        AError := 'no rsa private key pem block';
      Exit;
    end;
    if LBlock.IsEncrypted then
    begin
      AError := 'encrypted private key not supported';
      Exit;
    end;
    try
      if LBlock.BlockType = pemPrivateKey then
        Result := TryUnwrapPkcs8RsaPrivate(LBlock.Data, AModulus,
          APrivateExponent)
      else
        Result := TryParseRsaPkcs1Private(LBlock.Data, AModulus,
          APrivateExponent);
    except
      on LE: Exception do
      begin
        AError := 'asn1 parse failed: ' + LE.Message;
        Exit;
      end;
    end;
    if not Result then
      AError := 'invalid rsa private key der';
  finally
    LRdr.Free;
  end;
end;

{ ── 签名组装(plan 2026-08-25 D1) ───────────────────────────── }

function DkimSignMail(const ARawMail: string; const ADomain,
  ASelector: string; const ASignedHeaders: TDeliverabilityStringArray;
  const ACanonHeader, ACanonBody: TCanonMode; const AAlgo: TDkimAlgo;
  const ARsaModulus, ARsaPrivateExponent: TBytes;
  const AEd25519PrivateKey: TBytes; out ASignedMail: string;
  out AError: string): Boolean;
var
  LI: Integer;
  LHNames: TDeliverabilityStringArray;
  LHasFrom: Boolean;
  LBody: string;
  LHasBody: Boolean;
  LBh: TBytes;
  LHdrs, LAlgoStr, LCh, LCb: string;
  LValue, LHdrLine, LSigB64: string;
  LMailNoB: string;
  LSigRec: TDkimSignature;
  LHashInput, LSigBytes: TBytes;
begin
  Result := False;
  AError := '';
  ASignedMail := '';

  { RFC 6376 §3.5: from 必签; 域/选择器必填 }
  SetLength(LHNames, Length(ASignedHeaders));
  LHasFrom := False;
  for LI := 0 to High(ASignedHeaders) do
  begin
    LHNames[LI] := LowerAscii(TrimAscii(ASignedHeaders[LI]));
    if LHNames[LI] = 'from' then
      LHasFrom := True;
  end;
  if not LHasFrom then
  begin
    AError := 'h= must include from';
    Exit;
  end;
  if (TrimAscii(ADomain) = '') or (TrimAscii(ASelector) = '') then
  begin
    AError := 'domain and selector required';
    Exit;
  end;

  { bh = SHA-256(canonicalize(body))(RFC 6376 §3.7 步骤 5.1/5.2) }
  ExtractHeadersSection(ARawMail, LBody, LHasBody);
  LBh := Sha256Of(StrToBytes(DkimCanonicalizeBody(LBody, ACanonBody)));

  { 头值(b= 空占位, 单物理行); tag 顺序 v,a,c,d,s,h,bh,b 钉死 }
  LHdrs := '';
  for LI := 0 to High(LHNames) do
  begin
    if LI > 0 then
      LHdrs := LHdrs + ':';
    LHdrs := LHdrs + LHNames[LI];
  end;
  if AAlgo = daRsaSha256 then
    LAlgoStr := 'rsa-sha256'
  else
    LAlgoStr := 'ed25519-sha256';
  if ACanonHeader = cmRelaxed then
    LCh := 'relaxed'
  else
    LCh := 'simple';
  if ACanonBody = cmRelaxed then
    LCb := 'relaxed'
  else
    LCb := 'simple';
  LValue := 'v=1; a=' + LAlgoStr + '; c=' + LCh + '/' + LCb +
    '; d=' + ADomain + '; s=' + ASelector + '; h=' + LHdrs +
    '; bh=' + Base64Encode(LBh) + '; b=';
  LHdrLine := 'DKIM-Signature: ' + LValue;
  { 物理第一个头插入; 原邮件逐字节不动 }
  LMailNoB := LHdrLine + #13#10 + ARawMail;

  { 两段哈希出签(b= 置空语义由 DkimBuildHeaderHashInput 处理) }
  LSigRec.Algo := AAlgo;
  LSigRec.Domain := ADomain;
  LSigRec.Selector := ASelector;
  LSigRec.SignedHeaders := LHNames;
  LSigRec.CanonHeader := ACanonHeader;
  LSigRec.CanonBody := ACanonBody;
  LSigRec.Signature := nil;
  LSigRec.BodyHash := LBh;
  if not DkimBuildHeaderHashInput(LMailNoB, LSigRec, LHashInput, AError) then
    Exit;
  if not DkimSign(LHashInput, AAlgo, ARsaModulus, ARsaPrivateExponent,
    AEd25519PrivateKey, LSigBytes, AError) then
    Exit;

  { b= 追加签名得到最终邮件 }
  LSigB64 := Base64Encode(LSigBytes);
  ASignedMail := LHdrLine + LSigB64 +
    Copy(LMailNoB, Length(LHdrLine) + 1, MaxInt);
  Result := True;
end;

{ ── 验签 ─────────────────────────────────────────────────────── }

function DkimVerify(const ADns: IDeliverabilityDns; const ARawMail: string;
  const ATimeoutMs: Int32; out AError: string): TDkimResult;
var
  LValue: string;
  LSig: TDkimSignature;
  LBody: string;
  LErr: string;
  LCanonBody: string;
  LHashBody: TBytes;
  LTexts: TDeliverabilityStringArray;
  LKeyB64: string;
  LPKey: TBytes;
  LHeaderInput: TBytes;
  LDecrypted, LSDigest, LEM: TBytes;
  LModulus, LExponent: TBytes;
  LEMLen, LOffset, LI: Integer;
  LKeyName: string;
  LFound: Boolean;
  LHasBody: Boolean;
  LOk: Boolean;
  LHasFrom: Boolean;
  LFirstIsV, LVersionMismatch: Boolean;
begin
  Result := dkNeutral;
  AError := '';
  { 无签名 → neutral(INV-8) }
  if not DkimExtractSignatureValue(ARawMail, LValue) then
    Exit;
  if not DkimParseSignature(LValue, LSig, LErr) then
  begin
    AError := LErr;
    Result := dkPermError;
    Exit;
  end;

  { h= 必须含 From(RFC 6376 §6.1.1: 先于公钥查询) }
  LHasFrom := False;
  for LI := 0 to High(LSig.SignedHeaders) do
    if LSig.SignedHeaders[LI] = 'from' then
    begin
      LHasFrom := True;
      Break;
    end;
  if not LHasFrom then
  begin
    AError := 'from field not signed';
    Result := dkPermError;
    Exit;
  end;

  { 1. body hash(INV-5): 先于密钥查询 }
  ExtractHeadersSection(ARawMail, LBody, LHasBody);
  LCanonBody := DkimCanonicalizeBody(LBody, LSig.CanonBody);
  LHashBody := Sha256Of(StrToBytes(LCanonBody));
  if Length(LHashBody) <> Length(LSig.BodyHash) then
  begin
    AError := 'body hash length mismatch';
    Result := dkFail;
    Exit;
  end;
  for LI := 0 to High(LHashBody) do
    if LHashBody[LI] <> LSig.BodyHash[LI] then
    begin
      AError := 'body hash mismatch';
      Result := dkFail;
      Exit;
    end;

  { 2. 密钥查询: <s>._domainkey.<d> }
  LKeyName := LSig.Selector + '._domainkey.' + LSig.Domain;
  LOk := ADns.QueryTXT(LKeyName, ATimeoutMs, LTexts, LErr);
  if not LOk then
  begin
    if (Pos('nxdomain', LErr) > 0) or (Pos('no record', LErr) > 0) then
    begin
      AError := 'key not found: ' + LKeyName;
      Result := dkPermError;
    end
    else
    begin
      AError := LErr;
      Result := dkTempError;
    end;
    Exit;
  end;
  { 找含 p= 的键记录(RFC 6376 §3.6.1: v= 非 DKIM1 的记录丢弃) }
  LKeyB64 := '';
  LFound := False;
  for LI := 0 to High(LTexts) do
  begin
    LKeyB64 := '';
    if FindKeyTagValue(LTexts[LI], 'p', LKeyB64, LFirstIsV,
      LVersionMismatch) then
    begin
      LFound := True;
      Break;
    end;
  end;
  if not LFound then
  begin
    AError := 'no key for signature';
    Result := dkPermError;
    Exit;
  end;
  { 去空白 + base64 }
  if not DecodeBase64Loose(LKeyB64, LPKey) then
  begin
    AError := 'invalid p= base64';
    Result := dkPermError;
    Exit;
  end;
  if Length(LPKey) = 0 then
  begin
    AError := 'revoked key (empty p=)';
    Result := dkPermError;
    Exit;
  end;

  { 4. header 哈希输入 }
  if not DkimBuildHeaderHashInput(ARawMail, LSig, LHeaderInput, LErr) then
  begin
    AError := LErr;
    Result := dkPermError;
    Exit;
  end;

  { 5. 算法分支(INV-7) }
  case LSig.Algo of
    daRsaSha256:
      begin
        if not TryParseRsaSpki(LPKey, LModulus, LExponent) then
        begin
          AError := 'invalid RSA public key (SPKI)';
          Result := dkPermError;
          Exit;
        end;
        { s^e mod n }
        LDecrypted := nil;
        if not TryBigIntModExpFromUnsignedBytes(LSig.Signature, LExponent,
          LModulus, LDecrypted, LErr) then
        begin
          AError := 'rsa exponentiation failed: ' + LErr;
          Result := dkPermError;
          Exit;
        end;
        { 左补零到模长 }
        LEMLen := Length(LModulus);
        if Length(LDecrypted) > LEMLen then
        begin
          AError := 'signature too large';
          Result := dkFail;
          Exit;
        end;
        SetLength(LEM, LEMLen);
        LOffset := LEMLen - Length(LDecrypted);
        for LI := 0 to High(LDecrypted) do
          LEM[LOffset + LI] := LDecrypted[LI];

        { 期望块: 00 01 FF* 00 DigestInfo || sha256 }
        LSDigest := Sha256Of(LHeaderInput);
        if LEMLen < 11 + Length(DIGEST_INFO_SHA256) + 32 then
        begin
          AError := 'modulus too short';
          Result := dkPermError;
          Exit;
        end;
        SetLength(LDecrypted, LEMLen);
        LDecrypted[0] := 0;
        LDecrypted[1] := 1;
        for LI := 2 to LEMLen - Length(DIGEST_INFO_SHA256) - 32 - 2 do
          LDecrypted[LI] := $FF;
        LOffset := LEMLen - Length(DIGEST_INFO_SHA256) - 32 - 1;
        LDecrypted[LOffset] := 0;                             { 分隔 00 }
        for LI := 0 to High(DIGEST_INFO_SHA256) do
          LDecrypted[LOffset + 1 + LI] := DIGEST_INFO_SHA256[LI];
        for LI := 0 to 31 do
          LDecrypted[LOffset + 1 + Length(DIGEST_INFO_SHA256) + LI] :=
            LSDigest[LI];

        { TConstantTime.CompareBytes: 1 = 相同, 0 = 不同 }
        if TConstantTime.CompareBytes(LDecrypted, LEM) = 0 then
        begin
          AError := 'signature verification failed';
          Result := dkFail;
          Exit;
        end;
        Result := dkPass;
      end;
    daEd25519Sha256:
      begin
        if Length(LPKey) <> 32 then
        begin
          AError := 'invalid Ed25519 public key length';
          Result := dkPermError;
          Exit;
        end;
        if Length(LSig.Signature) <> 64 then
        begin
          AError := 'invalid Ed25519 signature length';
          Result := dkPermError;
          Exit;
        end;
        if Ed25519Verify(LPKey, LHeaderInput, LSig.Signature) then
          Result := dkPass
        else
        begin
          AError := 'ed25519 verification failed';
          Result := dkFail;
        end;
      end;
  end;
end;

{ ── 签名 ─────────────────────────────────────────────────────── }

function DkimSign(const AHdrHashInput: TBytes; const AAlgo: TDkimAlgo;
  const ARsaModulus, ARsaPrivateExponent: TBytes;
  const AEd25519PrivateKey: TBytes; out ASignature: TBytes;
  out AError: string): Boolean;
var
  LHash: TBytes;
  LEM: TBytes;
  LEMLen, LI: Integer;
begin
  Result := False;
  AError := '';
  ASignature := nil;
  case AAlgo of
    daRsaSha256:
      begin
        if (Length(ARsaModulus) = 0) or (Length(ARsaPrivateExponent) = 0) then
        begin
          AError := 'rsa key required';
          Exit;
        end;
        LHash := Sha256Of(AHdrHashInput);
        LEMLen := Length(ARsaModulus);
        if LEMLen < 11 + Length(DIGEST_INFO_SHA256) + 32 then
        begin
          AError := 'modulus too short';
          Exit;
        end;
        { EMSA-PKCS1-v1_5: 00 01 FF* 00 DigestInfo || hash(RFC 8017 §9.2);
          FF 区 = LEMLen - tLen - 3, 00 分隔后接 DigestInfo }
        SetLength(LEM, LEMLen);
        LEM[0] := 0;
        LEM[1] := 1;
        for LI := 2 to LEMLen - Length(DIGEST_INFO_SHA256) - 32 - 2 do
          LEM[LI] := $FF;
        LEM[LEMLen - Length(DIGEST_INFO_SHA256) - 32 - 1] := 0;  { 分隔 00 }
        for LI := 0 to High(DIGEST_INFO_SHA256) do
          LEM[LI + LEMLen - Length(DIGEST_INFO_SHA256) - 32] :=
            DIGEST_INFO_SHA256[LI];
        for LI := 0 to 31 do
          LEM[LI + LEMLen - 32] := LHash[LI];
        { EM^d mod n }
        if not TryRSAModExpSignPurePascal(LEM, ARsaModulus,
          ARsaPrivateExponent, ASignature, AError) then
          Exit;
        Result := True;
      end;
    daEd25519Sha256:
      begin
        if Length(AEd25519PrivateKey) <> 32 then
        begin
          AError := 'ed25519 private key must be 32 bytes';
          Exit;
        end;
        if not Ed25519Sign(AEd25519PrivateKey, AHdrHashInput, ASignature) then
        begin
          AError := 'ed25519 sign failed';
          Exit;
        end;
        Result := True;
      end;
  end;
end;

end.