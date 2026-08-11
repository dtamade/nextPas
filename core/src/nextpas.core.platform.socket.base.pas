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
    {** @desc 检查地址是否有效（Len > 0）
        @return True 如果地址有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查地址是否为 IPv4
        @return True 如果是 IPv4 地址 *}
    function IsIPv4: Boolean; inline;
    {** @desc 检查地址是否为 IPv6
        @return True 如果是 IPv6 地址 *}
    function IsIPv6: Boolean; inline;
    {** @desc 清空地址结构 *}
    procedure Clear; inline;
  end;

const
  PLATFORM_INVALID_SOCKET: TPlatformSocket = (
  {$IFDEF NEXTPAS_WINDOWS}
    Value: PtrUInt(-1)
  {$ELSE}
    Value: -1
  {$ENDIF}
  );

{** @desc 主机字节序转网络字节序（16 位）
    @param AHost 主机字节序值
    @return 网络字节序值 *}
function platform_htons(AHost: UInt16): UInt16; inline;

{** @desc 主机字节序转网络字节序（32 位）
    @param AHost 主机字节序值
    @return 网络字节序值 *}
function platform_htonl(AHost: UInt32): UInt32; inline;

{** @desc 网络字节序转主机字节序（16 位）
    @param ANet 网络字节序值
    @return 主机字节序值 *}
function platform_ntohs(ANet: UInt16): UInt16; inline;

{** @desc 网络字节序转主机字节序（32 位）
    @param ANet 网络字节序值
    @return 主机字节序值 *}
function platform_ntohl(ANet: UInt32): UInt32; inline;

{** @desc 解析 IPv4 点分十进制字符串
    @param AAddr 点分十进制格式的 IP 地址字符串（如 "192.168.1.1"）
    @return 网络字节序的 32 位 IPv4 地址，0 表示解析失败 *}
function platform_ipv4_parse(const AAddr: string): UInt32;

{** @desc 将网络字节序 IPv4 地址格式化为点分十进制字符串
    @param AIP 网络字节序的 32 位 IPv4 地址
    @return 点分十进制格式的字符串（如 "192.168.1.1"） *}
function platform_ipv4_to_string(AIP: UInt32): string;

{** @desc 创建 IPv4 套接字地址结构
    @param AAddr IPv4 地址（网络字节序）
    @param APort 端口号（主机字节序）
    @param ASockAddr 输出套接字地址结构 *}
procedure platform_sockaddr_ipv4(out ASockAddr: TPlatformSockAddr;
  AAddr: UInt32; APort: UInt16);

{** @desc 从套接字地址结构获取 IPv4 地址和端口
    @param ASockAddr 套接字地址结构
    @param AAddr 输出 IPv4 地址（网络字节序）
    @param APort 输出端口号（主机字节序） *}
procedure platform_sockaddr_ipv4_extract(const ASockAddr: TPlatformSockAddr;
  out AAddr: UInt32; out APort: UInt16);

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

{ TPlatformSockAddr helper methods }

function TPlatformSockAddr.IsValid: Boolean;
begin
  Result := Len > 0;
end;

function TPlatformSockAddr.IsIPv4: Boolean;
begin
  { AF_INET = 2。BSD 系(macOS/FreeBSD)sockaddr_in 带 1 字节 sa_len 头,
    family 位于 offset 1;Linux/Windows 标准布局 family 位于 offset 0。
    getsockname 由内核写 BSD 布局,应用读 offset0-1 会得到 0x0210≠2。 }
  Result := (Len > 0) and
    ((PWord(@Storage[0])^ = 2) or
     ((Len > 1) and (Storage[1] = 2)));
end;

function TPlatformSockAddr.IsIPv6: Boolean;
begin
  Result := (Len > 0) and
    ((PWord(@Storage[0])^ = 10) or
     ((Len > 1) and (Storage[1] = 10)));
end;

procedure TPlatformSockAddr.Clear;
begin
  FillChar(Self, SizeOf(Self), 0);
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

procedure platform_sockaddr_ipv4(out ASockAddr: TPlatformSockAddr;
  AAddr: UInt32; APort: UInt16);
type
  TSockAddrIn = packed record
    Family: UInt16;
    Port: UInt16;
    Addr: UInt32;
    Zero: array[0..7] of Byte;
  end;
var
  LAddr: TSockAddrIn;
begin
  FillChar(ASockAddr, SizeOf(ASockAddr), 0);
  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.Family := 2; { AF_INET }
  LAddr.Port := platform_htons(APort);
  LAddr.Addr := AAddr;
  Move(LAddr, ASockAddr.Storage, SizeOf(LAddr));
  ASockAddr.Len := SizeOf(LAddr);
end;

procedure platform_sockaddr_ipv4_extract(const ASockAddr: TPlatformSockAddr;
  out AAddr: UInt32; out APort: UInt16);
type
  TSockAddrIn = packed record
    Family: UInt16;
    Port: UInt16;
    Addr: UInt32;
    Zero: array[0..7] of Byte;
  end;
  { BSD 系布局:1 字节 sa_len + 1 字节 family(getsockname 内核写) }
  TBsdSockAddrIn = packed record
    Len: Byte;
    Family: Byte;
    Port: UInt16;
    Addr: UInt32;
    Zero: array[0..7] of Byte;
  end;
var
  LAddr: TSockAddrIn;
  LBsd: TBsdSockAddrIn;
begin
  AAddr := 0;
  APort := 0;
  if ASockAddr.Len < SizeOf(LAddr) then
    Exit;
  Move(ASockAddr.Storage, LAddr, SizeOf(LAddr));
  if LAddr.Family = 2 then { AF_INET }
  begin
    AAddr := LAddr.Addr;
    APort := platform_ntohs(LAddr.Port);
  end
  else
  begin
    { BSD sa_len 布局:offset 0 = sa_len,offset 1 = family }
    Move(ASockAddr.Storage, LBsd, SizeOf(LBsd));
    if LBsd.Family = 2 then
    begin
      AAddr := LBsd.Addr;
      APort := platform_ntohs(LBsd.Port);
    end;
  end;
end;

end.
