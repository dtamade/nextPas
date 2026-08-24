unit nextpas.core.net.resolve;
{**
 * @desc DNS/地址解析：主机名→IP 列表、IP 字面量判定。
 *       NetResolveAll 走 platform multi-A / dual-stack；NetResolve 返回首条。
 *       HostIsIpLiteral 供 UDP/QUIC 等「字面量直发 / 域名走 DNS」分路复用，
 *       避免各协议自写一套（proxy888 hy2 反哺）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.base;

function NetResolve(const AHost: string): TNetAddress;
function NetResolveAll(const AHost: string): specialize TArray<TNetAddress>;
function NetResolveIPv4(const AIP: string): UInt32;

{ 剥 IPv6 方括号：'[::1]' → '::1'；其余原样。 }
function StripHostBrackets(const AHost: string): string;
{ 点分四段 0..255；拒绝前导零（'01'）；不剥括号。 }
function TryParseIPv4(const AIP: string; out ANet: UInt32): Boolean; overload;
{ 同上，产出 4 字节网络序（首 octet = 高位地址段）。 }
function TryParseIPv4(const AIP: string; out AOctets: TBytes): Boolean; overload;
{ RFC 4291 §2.2：:: 至多一次、内嵌 IPv4 尾、剥括号；拒 %zone / 空组 / 超 4 位。 }
function TryParseIPv6(const AIP: string; out AOctets: TBytes): Boolean; overload;
{ 写入调用方 16 字节缓冲（AAddr 不可空）；失败不保证缓冲内容。 }
function TryParseIPv6(const AIP: string; AAddr: PByte): Boolean; overload;
{ 剥括号后可 TryParseIPv4。 }
function IsIPv4Literal(const AHost: string): Boolean;
{ 剥括号后 RFC 4291 解析成功。 }
function IsIPv6Literal(const AHost: string): Boolean;
function HostIsIpLiteral(const AHost: string): Boolean;

{ 网络序 IPv4 / 16 字节 IPv6 → 文本。 }
function FormatIPv4(ANet: UInt32): string;
function FormatIPv6(AAddr: PByte): string;

{ host:port / [ipv6]:port。无显式端口 → APort=ADefaultPort（0 可作「缺端口」探测）。
  显式端口必须 1..65535；空 host / 裸 IPv6（无括号）拒绝。 }
function SplitHostPort(const AText: string; ADefaultPort: UInt16;
  out AHost: string; out APort: UInt16): Boolean;
{ 必须带端口（1..65535）。 }
function SplitHostPort(const AText: string; out AHost: string;
  out APort: UInt16): Boolean;
{ IPv6 自动加括号。 }
function JoinHostPort(const AHost: string; APort: UInt16): string;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.platform.socket;

function FormatIPv6(AAddr: PByte): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
  LGroup: UInt16;
  LBuf: array[0..39] of Char;
  LPos: Integer;
begin
  LPos := 0;
  for I := 0 to 7 do
  begin
    LGroup := (UInt16(AAddr[I * 2]) shl 8) or UInt16(AAddr[I * 2 + 1]);
    if I > 0 then
    begin
      LBuf[LPos] := ':';
      Inc(LPos);
    end;
    LBuf[LPos] := HexChars[(LGroup shr 12) and $F]; Inc(LPos);
    LBuf[LPos] := HexChars[(LGroup shr 8) and $F]; Inc(LPos);
    LBuf[LPos] := HexChars[(LGroup shr 4) and $F]; Inc(LPos);
    LBuf[LPos] := HexChars[LGroup and $F]; Inc(LPos);
  end;
  SetString(Result, @LBuf[0], LPos);
end;

function FormatIPv4(ANet: UInt32): string;
begin
  Result := IntToStr(ANet and $FF) + '.' +
    IntToStr((ANet shr 8) and $FF) + '.' +
    IntToStr((ANet shr 16) and $FF) + '.' +
    IntToStr((ANet shr 24) and $FF);
end;

function TryParseIPv4(const AIP: string; out ANet: UInt32): Boolean;
var
  LParts: array[0..3] of Byte;
  LI, LStart, LPart: Integer;
  LVal: Int64;
  LS: string;
begin
  Result := False;
  ANet := 0;
  if AIP = '' then
    Exit;
  FillChar(LParts, SizeOf(LParts), 0);
  LStart := 1;
  LPart := 0;
  for LI := 1 to Length(AIP) + 1 do
  begin
    if (LI > Length(AIP)) or (AIP[LI] = '.') then
    begin
      if LPart > 3 then
        Exit;
      LS := Copy(AIP, LStart, LI - LStart);
      if (LS = '') or (Length(LS) > 3) then
        Exit;
      if (Length(LS) > 1) and (LS[1] = '0') then
        Exit;
      if (not TryStrToInt(LS, LVal)) or (LVal < 0) or (LVal > 255) then
        Exit;
      LParts[LPart] := Byte(LVal);
      Inc(LPart);
      LStart := LI + 1;
    end
    else if (AIP[LI] < '0') or (AIP[LI] > '9') then
      Exit;
  end;
  if LPart <> 4 then
    Exit;
  ANet := UInt32(LParts[0]) or (UInt32(LParts[1]) shl 8)
    or (UInt32(LParts[2]) shl 16) or (UInt32(LParts[3]) shl 24);
  Result := True;
end;

function TryParseIPv4(const AIP: string; out AOctets: TBytes): Boolean;
var
  LNet: UInt32;
begin
  Result := TryParseIPv4(AIP, LNet);
  if not Result then
  begin
    AOctets := nil;
    Exit;
  end;
  SetLength(AOctets, 4);
  AOctets[0] := Byte(LNet);
  AOctets[1] := Byte(LNet shr 8);
  AOctets[2] := Byte(LNet shr 16);
  AOctets[3] := Byte(LNet shr 24);
end;

function TryParseIPv6(const AIP: string; out AOctets: TBytes): Boolean;
var
  LFront, LBack, LGroups: array[0..7] of Word;
  LFCount, LBCount, LI, LGV, LDigits, LTot, LBackBase: Integer;
  LText: string;
  LV4: TBytes;
  LHaveV4, LHaveZip, LJustGroup: Boolean;
begin
  { RFC 4291 §2.2（对齐 Go net.ParseIP）：:: 至多一次、内嵌 IPv4 尾占末两组；
    拒绝 %zone、单组 >4 位、空组（除 ::）、总组数不符。前/后段分收，中段填零。 }
  Result := False;
  AOctets := nil;
  LText := StripHostBrackets(AIP);
  if LText = '' then
    Exit;
  LHaveV4 := False;
  LI := Length(LText);
  while (LI >= 1) and (LText[LI] <> ':') do
    Dec(LI);
  if Pos('.', Copy(LText, LI + 1, MaxInt)) > 0 then
  begin
    if LI < 2 then
      Exit;
    if not TryParseIPv4(Copy(LText, LI + 1, MaxInt), LV4) then
      Exit;
    LText := Copy(LText, 1, LI);
    LHaveV4 := True;
  end;
  LFCount := 0;
  LBCount := 0;
  LHaveZip := False;
  LJustGroup := False;
  LI := 1;
  while LI <= Length(LText) do
  begin
    if LText[LI] = ':' then
    begin
      if (LI < Length(LText)) and (LText[LI + 1] = ':') then
      begin
        if LHaveZip then
          Exit;
        LHaveZip := True;
        LJustGroup := False;
        Inc(LI, 2);
      end
      else if LJustGroup then
      begin
        LJustGroup := False;
        Inc(LI);
      end
      else
        Exit;
    end
    else
    begin
      LGV := 0;
      LDigits := 0;
      while (LI <= Length(LText)) and (LText[LI] <> ':') do
      begin
        case LText[LI] of
          '0'..'9': LGV := LGV * 16 + (Ord(LText[LI]) - Ord('0'));
          'a'..'f': LGV := LGV * 16 + (Ord(LText[LI]) - Ord('a') + 10);
          'A'..'F': LGV := LGV * 16 + (Ord(LText[LI]) - Ord('A') + 10);
        else
          Exit;
        end;
        Inc(LDigits);
        if LDigits > 4 then
          Exit;
        Inc(LI);
      end;
      if LHaveZip then
      begin
        if LBCount > 7 then
          Exit;
        LBack[LBCount] := Word(LGV);
        Inc(LBCount);
      end
      else
      begin
        if LFCount > 7 then
          Exit;
        LFront[LFCount] := Word(LGV);
        Inc(LFCount);
      end;
      LJustGroup := True;
    end;
  end;
  if (not LHaveV4) and (Length(LText) > 0) and (LText[Length(LText)] = ':') and
     ((Length(LText) < 2) or (LText[Length(LText) - 1] <> ':')) then
    Exit;
  LTot := LFCount + LBCount;
  if LHaveV4 then
    Inc(LTot, 2);
  if LHaveZip then
  begin
    if LTot >= 8 then
      Exit;
  end
  else if LTot <> 8 then
    Exit;
  FillChar(LGroups, SizeOf(LGroups), 0);
  for LI := 0 to LFCount - 1 do
    LGroups[LI] := LFront[LI];
  LBackBase := 8 - LBCount;
  if LHaveV4 then
    Dec(LBackBase, 2);
  for LI := 0 to LBCount - 1 do
    LGroups[LBackBase + LI] := LBack[LI];
  if LHaveV4 then
  begin
    LGroups[6] := (Word(LV4[0]) shl 8) or Word(LV4[1]);
    LGroups[7] := (Word(LV4[2]) shl 8) or Word(LV4[3]);
  end;
  SetLength(AOctets, 16);
  for LI := 0 to 7 do
  begin
    AOctets[LI * 2] := Byte(LGroups[LI] shr 8);
    AOctets[LI * 2 + 1] := Byte(LGroups[LI]);
  end;
  Result := True;
end;

function TryParseIPv6(const AIP: string; AAddr: PByte): Boolean;
var
  LOctets: TBytes;
begin
  Result := False;
  if AAddr = nil then
    Exit;
  if not TryParseIPv6(AIP, LOctets) then
    Exit;
  Move(LOctets[0], AAddr^, 16);
  Result := True;
end;

function NetResolveIPv4(const AIP: string): UInt32;
begin
  if not TryParseIPv4(AIP, Result) then
    raise EArgumentError.Create('invalid IPv4: ' + AIP);
end;

function StripHostBrackets(const AHost: string): string;
begin
  Result := AHost;
  if (Length(Result) >= 2) and (Result[1] = '[') and
    (Result[Length(Result)] = ']') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function IsIPv4Literal(const AHost: string): Boolean;
var
  Dummy: UInt32;
begin
  Result := TryParseIPv4(StripHostBrackets(AHost), Dummy);
end;

function IsIPv6Literal(const AHost: string): Boolean;
var
  Dummy: TBytes;
begin
  Result := TryParseIPv6(AHost, Dummy);
end;

function HostIsIpLiteral(const AHost: string): Boolean;
begin
  Result := IsIPv4Literal(AHost) or IsIPv6Literal(AHost);
end;

function NetResolveAll(const AHost: string): specialize TArray<TNetAddress>;
var
  LRaw: array[0..PLATFORM_RESOLVE_MAX - 1] of TPlatformResolvedAddr;
  LCount: Int32;
  LRes: Int32;
  LI, LJ: Integer;
  LHost: AnsiString;
  LBare: string;
begin
  Result := nil;
  SetLength(Result, 0);
  LBare := StripHostBrackets(AHost);
  if (LBare = '') or (LBare = 'localhost') then
  begin
    SetLength(Result, 1);
    Result[0] := TNetAddress.IPv4('127.0.0.1', 0);
    Exit;
  end;

  if IsIPv4Literal(LBare) then
  begin
    SetLength(Result, 1);
    Result[0] := TNetAddress.IPv4(LBare, 0);
    Exit;
  end;

  if IsIPv6Literal(LBare) then
  begin
    SetLength(Result, 1);
    Result[0] := TNetAddress.IPv6(LBare, 0);
    Exit;
  end;

  LHost := LBare;
  LRes := platform_socket_resolve_stream(PAnsiChar(LHost), @LRaw[0],
    PLATFORM_RESOLVE_MAX, LCount);
  if (LRes <> 0) or (LCount <= 0) then
    raise ENetworkError.Create('DNS resolve failed for: ' + AHost);

  SetLength(Result, LCount);
  LI := 0;
  for LJ := 0 to LCount - 1 do
    if not LRaw[LJ].IsIPv6 then
    begin
      Result[LI].IP := FormatIPv4(LRaw[LJ].IPv4);
      Result[LI].Port := 0;
      Result[LI].IsIPv6 := False;
      Inc(LI);
    end;
  for LJ := 0 to LCount - 1 do
    if LRaw[LJ].IsIPv6 then
    begin
      Result[LI].IP := FormatIPv6(@LRaw[LJ].IPv6[0]);
      Result[LI].Port := 0;
      Result[LI].IsIPv6 := True;
      Inc(LI);
    end;
end;

function NetResolve(const AHost: string): TNetAddress;
var
  LAll: specialize TArray<TNetAddress>;
begin
  LAll := NetResolveAll(AHost);
  if Length(LAll) = 0 then
    raise ENetworkError.Create('DNS resolve failed for: ' + AHost);
  Result := LAll[0];
end;

function SplitHostPort(const AText: string; ADefaultPort: UInt16;
  out AHost: string; out APort: UInt16): Boolean;
var
  LColon, LEnd, LI: Integer;
  LPortText: string;
  LVal: Int64;
begin
  Result := False;
  AHost := '';
  APort := ADefaultPort;
  LPortText := '';
  if AText = '' then
    Exit;
  if AText[1] = '[' then
  begin
    LEnd := Pos(']', AText);
    if LEnd = 0 then
      Exit;
    AHost := Copy(AText, 2, LEnd - 2);
    if AHost = '' then
      Exit;
    if LEnd + 1 > Length(AText) then
    begin
      Result := True;
      Exit;
    end;
    if AText[LEnd + 1] <> ':' then
      Exit;
    LPortText := Copy(AText, LEnd + 2, Length(AText) - LEnd - 1);
  end
  else
  begin
    LColon := 0;
    for LI := Length(AText) downto 1 do
      if AText[LI] = ':' then
      begin
        LColon := LI;
        Break;
      end;
    if LColon = 0 then
    begin
      AHost := AText;
      if AHost <> '' then
        Result := True;
      Exit;
    end;
    AHost := Copy(AText, 1, LColon - 1);
    LPortText := Copy(AText, LColon + 1, Length(AText) - LColon);
    if Pos(':', AHost) <> 0 then
      Exit;
  end;
  if (AHost = '') or (LPortText = '') then
    Exit;
  if not TryStrToInt(LPortText, LVal) then
    Exit;
  if (LVal < 1) or (LVal > 65535) then
    Exit;
  APort := UInt16(LVal);
  Result := True;
end;

function SplitHostPort(const AText: string; out AHost: string;
  out APort: UInt16): Boolean;
begin
  Result := SplitHostPort(AText, 0, AHost, APort) and (APort <> 0);
end;

function JoinHostPort(const AHost: string; APort: UInt16): string;
var
  H: string;
begin
  H := StripHostBrackets(AHost);
  if IsIPv6Literal(H) then
    Result := '[' + H + ']:' + IntToStr(APort)
  else
    Result := H + ':' + IntToStr(APort);
end;

end.
