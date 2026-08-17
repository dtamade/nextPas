{**
 * Unit: nextpas.core.crypto.random
 * Purpose: Cryptographically secure random for crypto primitives.
 *
 * Owner: nextpas.core.crypto (must not depend on tls).
 * Uses platform CSPRNG via nextpas.core.platform.random.
 *}

unit nextpas.core.crypto.random;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

type
  ECryptoRandomError = class(Exception);

{**
 * @desc 用 CSPRNG 填充缓冲区。
 *
 * @params
 *   ABuffer 目标缓冲区；nil 视为非法调用
 *   ACount  请求字节数；0 = 无操作成功，负值 = 非法调用
 *
 * @return 成功返回 True；ABuffer=nil 或 ACount<0 返回 False
 *}
function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;

{**
 * @desc 分配并填充 ACount 个 CSPRNG 随机字节。
 *
 * @params
 *   ACount 请求字节数；0 = 返回空数组（合法），负值抛 EArgumentError
 *
 * @return ACount 个随机字节的 TBytes
 *
 * @note 底层 CSPRNG 失败抛 ECryptoRandomError（环境故障，与参数无关）；
 *       ACount 负值属编程错误，抛 EArgumentError 以便调用方区分。
 *}
function GenerateSecureRandomBytes(ACount: Integer): TBytes;

function IsSecureRandomAvailable: Boolean;

implementation

uses
  nextpas.core.platform.random;

function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;
begin
  Result := False;
  if ABuffer = nil then
    Exit;
  if ACount = 0 then
    Exit(True);          { 0 长度 = 无操作成功（与高层语义一致：0 合法） }
  if ACount < 0 then
    Exit;
  Result := platform_random_bytes(ABuffer, PtrUInt(ACount)) = 0;
end;

function IsSecureRandomAvailable: Boolean;
var
  LByte: Byte;
begin
  Result := SecureRandomBytes(@LByte, 1);
end;

function GenerateSecureRandomBytes(ACount: Integer): TBytes;
begin
  Result := nil;
  if ACount < 0 then
    raise EArgumentError.CreateFmt('Invalid byte count: %d', [ACount]);
  if ACount = 0 then
    Exit;                { 0 长度合法：空数组表达"0 字节"语义（此前抛错使
                           调用方无法区分"0 字节合法"与参数错误） }

  SetLength(Result, ACount);
  if not SecureRandomBytes(@Result[0], ACount) then
  begin
    FillChar(Result[0], ACount, 0);
    SetLength(Result, 0);
    raise ECryptoRandomError.Create('Failed to generate secure random bytes');
  end;
end;

end.
