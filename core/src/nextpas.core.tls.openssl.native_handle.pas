unit nextpas.core.tls.openssl.native_handle;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions;

{**
 * OpenSSL 原生句柄辅助函数
 * 用于从接口对象安全地提取 C 库句柄
 *}

{** 从接口对象获取原生句柄（安全版本）
    @param AObject 实现 ISSLNativeHandleAccess 的接口对象
    @param AContextMsg 错误上下文消息
    @returns 原生句柄指针
    @raises ESSLException 如果对象不支持原生句柄或句柄无效 *}
function GetNativeHandleSafe(const AObject: IInterface; const AContextMsg: string): Pointer;

{** 尝试从接口对象获取原生句柄
    @param AObject 可能实现 ISSLNativeHandleAccess 的接口对象
    @param AHandle 输出参数，返回句柄
    @returns True 如果成功获取句柄 *}
function TryGetNativeHandle(const AObject: IInterface; out AHandle: Pointer): Boolean;

implementation

function GetNativeHandleSafe(const AObject: IInterface; const AContextMsg: string): Pointer;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  if AObject = nil then
    raise ESSLException.CreateWithContext(
      'Object parameter is nil',
      sslErrInvalidParam,
      AContextMsg
    );

  if not Supports(AObject, ISSLNativeHandleAccess, NativeAccess) then
    raise ESSLException.CreateWithContext(
      'Object does not support native handle access (not a C library backend)',
      sslErrUnsupported,
      AContextMsg
    );

  Result := NativeAccess.GetNativeHandle;
  if Result = nil then
    raise ESSLException.CreateWithContext(
      'Native handle is nil',
      sslErrGeneral,
      AContextMsg
    );
end;

function TryGetNativeHandle(const AObject: IInterface; out AHandle: Pointer): Boolean;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  Result := False;
  AHandle := nil;

  if AObject = nil then
    Exit;

  if not Supports(AObject, ISSLNativeHandleAccess, NativeAccess) then
    Exit;

  AHandle := NativeAccess.GetNativeHandle;
  Result := (AHandle <> nil);
end;

end.
