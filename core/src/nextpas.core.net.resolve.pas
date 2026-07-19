unit nextpas.core.net.resolve;
{**
 * @desc DNS/地址解析：主机名→IP、IPv4 字面量解析。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base;

function NetResolve(const AHost: string): TNetAddress;
function NetResolveIPv4(const AIP: string): UInt32;

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

function NetResolveIPv4(const AIP: string): UInt32;
var
  LParts: array[0..3] of Byte;
  LI, LStart, LPart, LVal: Integer;
  LS: string;
begin
  LStart := 1;
  LPart := 0;
  for LI := 1 to Length(AIP) + 1 do
  begin
    if (LI > Length(AIP)) or (AIP[LI] = '.') then
    begin
      if LPart > 3 then
        raise EArgumentError.Create('invalid IPv4: ' + AIP);
      LS := Copy(AIP, LStart, LI - LStart);
      LVal := StrToInt(LS);
      if (LVal < 0) or (LVal > 255) then
        raise EArgumentError.Create('invalid IPv4 octet: ' + AIP);
      LParts[LPart] := Byte(LVal);
      Inc(LPart);
      LStart := LI + 1;
    end;
  end;
  if LPart <> 4 then
    raise EArgumentError.Create('invalid IPv4: ' + AIP);
  Result := UInt32(LParts[0]) or (UInt32(LParts[1]) shl 8)
    or (UInt32(LParts[2]) shl 16) or (UInt32(LParts[3]) shl 24);
end;

function IsIPv4Literal(const AHost: string): Boolean;
var
  LI: Integer;
begin
  if Length(AHost) = 0 then Exit(False);
  for LI := 1 to Length(AHost) do
    if not (AHost[LI] in ['0'..'9', '.']) then
      Exit(False);
  Result := True;
end;

function NetResolve(const AHost: string): TNetAddress;
var
  LAddr: UInt32;
  LAddr6: array[0..15] of Byte;
  LResult: Int32;
begin
  if (AHost = '') or (AHost = 'localhost') then
    Exit(TNetAddress.IPv4('127.0.0.1', 0));

  if IsIPv4Literal(AHost) then
    Exit(TNetAddress.IPv4(AHost, 0));

  { 尝试 IPv4 解析 }
  LResult := platform_socket_resolve_ipv4(PAnsiChar(AHost), LAddr);
  if LResult = 0 then
  begin
    Result.IP := IntToStr(LAddr and $FF) + '.' + IntToStr((LAddr shr 8) and $FF) + '.' +
      IntToStr((LAddr shr 16) and $FF) + '.' + IntToStr((LAddr shr 24) and $FF);
    Result.Port := 0;
    Result.IsIPv6 := False;
    Exit;
  end;

  { IPv4 失败，尝试 IPv6 解析 }
  FillChar(LAddr6, SizeOf(LAddr6), 0);
  LResult := platform_socket_resolve_ipv6(PAnsiChar(AHost), @LAddr6[0]);
  if LResult = 0 then
  begin
    Result.IP := FormatIPv6Addr(@LAddr6[0]);
    Result.Port := 0;
    Result.IsIPv6 := True;
    Exit;
  end;

  raise ENetworkError.Create('DNS resolve failed for: ' + AHost);
end;

end.
