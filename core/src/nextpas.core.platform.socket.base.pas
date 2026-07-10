{**
 * nextpas.core.platform.socket.base - 平台无关的 socket 类型与工具
 *
 * 职责：socket 层的平台无关基础设施
 *   - TPlatformSocket / TPlatformSockAddr 类型定义
 *   - 字节序转换 (htons/htonl/ntohs/ntohl)
 *   - IPv4 地址解析与格式化 (parse/to_string)
 *
 * 设计：
 *   此单元不依赖任何平台 FFI 头文件，可在所有平台编译。
 *   平台相关的 socket 常量 (AF_INET, SOCK_STREAM 等) 留在 socket.pas。
 *}
unit nextpas.core.platform.socket.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 套接字句柄（平台无关封装） *}
  TPlatformSocket = record
  {$IFDEF NEXTPAS_WINDOWS}
    Value: PtrUInt;
  {$ELSE}
    Value: Int32;
  {$ENDIF}
    {** @desc 检查套接字是否有效
        @return True 如果套接字有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查套接字是否无效
        @return True 如果套接字无效 *}
    function IsInvalid: Boolean; inline;
  end;

  {** @desc 通用套接字地址结构（128 字节存储 + 长度） *}
  TPlatformSockAddr = packed record
    Storage: array[0..127] of Byte;
    Len: Int32;
  end;

const
  PLATFORM_INVALID_SOCKET: TPlatformSocket = (
  {$IFDEF NEXTPAS_WINDOWS}
    Value: PtrUInt(-1)
  {$ELSE}
    Value: -1
  {$ENDIF}
  );

{ Byte-order conversion — pure bit manipulation, no platform dependency }
function platform_htons(AHost: UInt16): UInt16; inline;
function platform_htonl(AHost: UInt32): UInt32; inline;
function platform_ntohs(ANet: UInt16): UInt16; inline;
function platform_ntohl(ANet: UInt32): UInt32; inline;

{ IPv4 address parsing — returns network-byte-order address, 0 on error }
function platform_ipv4_parse(const AAddr: string): UInt32;

{ IPv4 address formatting — dotted-decimal string }
function platform_ipv4_to_string(AIP: UInt32): string;

implementation

function TPlatformSocket.IsValid: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := Value <> PtrUInt(-1);
{$ELSE}
  Result := Value >= 0;
{$ENDIF}
end;

function TPlatformSocket.IsInvalid: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := Value = PtrUInt(-1);
{$ELSE}
  Result := Value < 0;
{$ENDIF}
end;

function platform_htons(AHost: UInt16): UInt16;
begin
  Result := ((AHost and $FF) shl 8) or ((AHost shr 8) and $FF);
end;

function platform_htonl(AHost: UInt32): UInt32;
begin
  Result := ((AHost and $FF) shl 24) or
            ((AHost and $FF00) shl 8) or
            ((AHost shr 8) and $FF00) or
            ((AHost shr 24) and $FF);
end;

function platform_ntohs(ANet: UInt16): UInt16;
begin
  Result := platform_htons(ANet);
end;

function platform_ntohl(ANet: UInt32): UInt32;
begin
  Result := platform_htonl(ANet);
end;

function platform_ipv4_parse(const AAddr: string): UInt32;
var
  LPart: UInt32;
  LShift: Integer;
  LIdx, LLen, LStart, LPartIdx, LSegments: Integer;
  LCh: Char;
begin
  Result := 0;
  LLen := Length(AAddr);
  if LLen = 0 then Exit;
  LShift := 24;
  LStart := 1;
  LSegments := 0;
  for LIdx := 1 to LLen + 1 do
  begin
    if (LIdx > LLen) or (AAddr[LIdx] = '.') then
    begin
      if (LIdx = LStart) or (LSegments = 4) then
      begin
        Result := 0;
        Exit;
      end;
      LPart := 0;
      for LPartIdx := LStart to LIdx - 1 do
      begin
        LCh := AAddr[LPartIdx];
        if LPart > 255 then begin Result := 0; Exit; end;
        if (LCh < '0') or (LCh > '9') then begin Result := 0; Exit; end;
        LPart := LPart * 10 + Ord(LCh) - Ord('0');
      end;
      if LPart > 255 then begin Result := 0; Exit; end;
      Result := Result or (LPart shl LShift);
      Inc(LSegments);
      Dec(LShift, 8);
      LStart := LIdx + 1;
    end;
  end;
  if LSegments <> 4 then
    Result := 0;
end;

function platform_ipv4_to_string(AIP: UInt32): string;

  function OctetToStr(AVal: UInt32): string;
  var
    LBuf: array[0..3] of Char;
    LLen, LI: Integer;
    LDigit: UInt32;
  begin
    LLen := 0;
    repeat
      LDigit := AVal mod 10;
      LBuf[LLen] := Chr(Ord('0') + LDigit);
      Inc(LLen);
      AVal := AVal div 10;
    until AVal = 0;
    SetLength(Result, LLen);
    for LI := 0 to LLen - 1 do
      Result[LI + 1] := LBuf[LLen - 1 - LI];
  end;

begin
  Result := OctetToStr((AIP shr 24) and $FF) + '.' +
            OctetToStr((AIP shr 16) and $FF) + '.' +
            OctetToStr((AIP shr 8) and $FF) + '.' +
            OctetToStr(AIP and $FF);
end;

end.
