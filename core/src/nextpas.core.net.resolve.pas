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
  nextpas.core.net.base;

function NetResolve(const AHost: string): TNetAddress;
function NetResolveAll(const AHost: string): specialize TArray<TNetAddress>;
function NetResolveIPv4(const AIP: string): UInt32;

{ 剥 IPv6 方括号：'[::1]' → '::1'；其余原样。 }
function StripHostBrackets(const AHost: string): string;
{ 点分四段 0..255；不剥括号（括号交给 StripHostBrackets）。 }
function TryParseIPv4(const AIP: string; out ANet: UInt32): Boolean;
{ 剥括号后可 TryParseIPv4。 }
function IsIPv4Literal(const AHost: string): Boolean;
{ 剥括号后含冒号即视为 v6 字面量。 }
function IsIPv6Literal(const AHost: string): Boolean;
function HostIsIpLiteral(const AHost: string): Boolean;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.platform.socket;

{ 格式化 IPv6 地址字节为字符串 }
function FormatIPv6Addr(AAddr: PByte): string;
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

function IPv4NetToString(ANet: UInt32): string;
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
      if (LS = '') or (not TryStrToInt(LS, LVal)) then
        Exit;
      if (LVal < 0) or (LVal > 255) then
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
  H: string;
begin
  H := StripHostBrackets(AHost);
  Result := (H <> '') and (Pos(':', H) > 0);
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
      Result[LI].IP := IPv4NetToString(LRaw[LJ].IPv4);
      Result[LI].Port := 0;
      Result[LI].IsIPv6 := False;
      Inc(LI);
    end;
  for LJ := 0 to LCount - 1 do
    if LRaw[LJ].IsIPv6 then
    begin
      Result[LI].IP := FormatIPv6Addr(@LRaw[LJ].IPv6[0]);
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

end.
