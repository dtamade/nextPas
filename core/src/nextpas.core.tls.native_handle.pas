{
  nextpas.core.tls.native_handle - 统一的原生句柄访问辅助单元

  版本: 1.1.1
  作者: fafafa.ssl 开发团队
  创建: 2026-02-05

  描述:
    提供统一的原生句柄访问接口，简化高级用户体验。
    此单元是 v1.1.0 接口重构后的易用性改进，提供：
    - 统一的辅助函数（无需记住后端特定单元名）
    - 泛型类型安全版本（避免手动类型转换）
    - 增强的错误消息（包含修复建议）

  使用示例:
    uses nextpas.core.tls.native_handle;

    // 方式1: 简洁
    Handle := GetNativeHandle(Ctx);

    // 方式2: 类型安全（推荐）
    Handle := GetNativeHandleAs<PSSL_CTX>(Ctx);

    // 方式3: 最安全（生产环境推荐）
    Handle := GetNativeHandleAs<PSSL_CTX>(Ctx, 'MyApp.Initialize');
}

unit nextpas.core.tls.native_handle;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions;

{**
 * 获取底层 C 库的原生句柄
 *
 * @param AObject 要查询的 SSL 对象（Context/Connection/Certificate 等）
 * @returns 原生句柄指针，需根据后端类型手动转换
 *
 * @raises ESSLException 如果对象不支持原生句柄访问
 *
 * @note 此功能仅适用于 C 库后端（OpenSSL/WinSSL/MbedTLS/WolfSSL）
 * @note 纯 FreePascal 后端不支持此功能
 *
 * @example
 *   uses nextpas.core.tls.native_handle;
 *
 *   var SSL_CTX: PSSL_CTX;
 *   begin
 *     SSL_CTX := PSSL_CTX(GetNativeHandle(Ctx));
 *   end;
 *
 * @see GetNativeHandleAs 类型安全的泛型版本
 * @see TryGetNativeHandle 不抛出异常的版本
 * @since v1.1.1
 *}
function GetNativeHandle(const AObject: IInterface): Pointer;

{**
 * 安全获取原生句柄，带上下文信息
 *
 * @param AObject 要查询的 SSL 对象
 * @param AContext 调用上下文（用于错误消息，如 'MyApp.Initialize'）
 * @returns 原生句柄指针
 *
 * @raises ESSLException 如果对象不支持或句柄为 nil，包含详细错误信息
 *
 * @example
 *   Handle := GetNativeHandleSafe(Ctx, 'MyApp.DoHandshake');
 *
 * @since v1.1.1
 *}
function GetNativeHandleSafe(const AObject: IInterface;
                              const AContext: string = ''): Pointer;

{**
 * 尝试获取原生句柄（不抛出异常）
 *
 * @param AObject 要查询的 SSL 对象
 * @param AHandle [out] 输出句柄指针
 * @returns True 如果成功获取，False 如果不支持
 *
 * @example
 *   if TryGetNativeHandle(Ctx, Handle) then
 *     // 使用句柄
 *   else
 *     // 这是纯 Pascal 后端
 *
 * @since v1.1.1
 *}
function TryGetNativeHandle(const AObject: IInterface;
                            out AHandle: Pointer): Boolean;

{**
 * 类型安全的泛型版本 - 获取原生句柄并自动转换类型
 *
 * @param AObject 要查询的 SSL 对象
 * @returns 指定类型的句柄
 *
 * @raises ESSLException 如果对象不支持原生句柄访问
 *
 * @example
 *   var SSL_CTX: PSSL_CTX;
 *   begin
 *     SSL_CTX := GetNativeHandleAs<PSSL_CTX>(Ctx);  // 无需手动转换
 *   end;
 *
 * @note 推荐使用此版本，避免类型转换错误
 * @since v1.1.1
 *}
generic function GetNativeHandleAs<T>(const AObject: IInterface): T;

{**
 * 类型安全的泛型版本 - 安全获取原生句柄
 *
 * @param AObject 要查询的 SSL 对象
 * @param AContext 调用上下文
 * @returns 指定类型的句柄
 *
 * @raises ESSLException 如果对象不支持或句柄为 nil
 *
 * @example
 *   SSL_CTX := GetNativeHandleAs<PSSL_CTX>(Ctx, 'MyApp.Initialize');
 *
 * @since v1.1.1
 *}
generic function GetNativeHandleAsSafe<T>(const AObject: IInterface;
                                          const AContext: string = ''): T;

{**
 * 类型安全的泛型版本 - 尝试获取原生句柄
 *
 * @param AObject 要查询的 SSL 对象
 * @param AHandle [out] 输出指定类型的句柄
 * @returns True 如果成功获取
 *
 * @example
 *   var SSL_CTX: PSSL_CTX;
 *   begin
 *     if TryGetNativeHandleAs<PSSL_CTX>(Ctx, SSL_CTX) then
 *       // 使用 SSL_CTX
 *   end;
 *
 * @since v1.1.1
 *}
generic function TryGetNativeHandleAs<T>(const AObject: IInterface;
                                        out AHandle: T): Boolean;

{**
 * 检查对象是否支持原生句柄访问
 *
 * @param AObject 要检查的 SSL 对象
 * @returns True 如果支持且句柄有效
 *
 * @example
 *   if IsNativeHandleAvailable(Ctx) then
 *     WriteLn('This is a C library backend');
 *
 * @since v1.1.1
 *}
function IsNativeHandleAvailable(const AObject: IInterface): Boolean;

{**
 * 获取对象的后端类型
 *
 * @param AObject 要查询的 SSL 对象
 * @returns 后端类型枚举值
 *
 * @example
 *   case GetBackendType(Ctx) of
 *     sslOpenSSL: WriteLn('Using OpenSSL');
 *     sslWinSSL: WriteLn('Using WinSSL');
 *   end;
 *
 * @since v1.1.1
 *}
function GetBackendType(const AObject: IInterface): TSSLLibraryType;

{**
 * 检查原生句柄是否有效（非空且已初始化）
 *
 * @param AObject 要检查的 SSL 对象
 * @returns True 如果句柄有效
 *
 * @since v1.1.1
 *}
function IsNativeHandleValid(const AObject: IInterface): Boolean;

implementation

const
  // 错误消息模板
  ERROR_NOT_AVAILABLE =
    'Native handle not available%s.' + LineEnding +
    LineEnding +
    'Possible reasons:' + LineEnding +
    '  1. This is a pure FreePascal backend without C library bindings' + LineEnding +
    '  2. The object does not support ISSLNativeHandleAccess interface' + LineEnding +
    '  3. The object has not been properly initialized' + LineEnding +
    LineEnding +
    'To fix:' + LineEnding +
    '  - For pure Pascal backends: Do not use native handles' + LineEnding +
    '  - For C library backends: Check backend initialization' + LineEnding +
    '  - Verify the object was created successfully' + LineEnding +
    LineEnding +
    'See documentation:' + LineEnding +
    '  - docs/MIGRATION_GUIDE_V1.1.md' + LineEnding +
    '  - docs/NATIVE_HANDLE_QUICK_REF.md' + LineEnding +
    '  - docs/ARCHITECTURE.md';

  ERROR_HANDLE_NULL =
    'Native handle is null%s.' + LineEnding +
    LineEnding +
    'This usually indicates:' + LineEnding +
    '  1. The object was not properly initialized' + LineEnding +
    '  2. The underlying C library failed to create the handle' + LineEnding +
    '  3. The object has been finalized/freed' + LineEnding +
    LineEnding +
    'To fix:' + LineEnding +
    '  - Check error logs for initialization failures' + LineEnding +
    '  - Verify the object lifecycle' + LineEnding +
    '  - Ensure the C library is properly loaded';

function GetNativeHandle(const AObject: IInterface): Pointer;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  if not Supports(AObject, ISSLNativeHandleAccess, NativeAccess) then
    raise ESSLException.Create(Format(ERROR_NOT_AVAILABLE, ['']));

  Result := NativeAccess.GetNativeHandle;
end;

function GetNativeHandleSafe(const AObject: IInterface;
                              const AContext: string): Pointer;
var
  NativeAccess: ISSLNativeHandleAccess;
  ContextMsg: string;
begin
  // 构建上下文消息
  if AContext <> '' then
    ContextMsg := ' (at ' + AContext + ')'
  else
    ContextMsg := '';

  // 检查接口支持
  if not Supports(AObject, ISSLNativeHandleAccess, NativeAccess) then
    raise ESSLException.Create(Format(ERROR_NOT_AVAILABLE, [ContextMsg]));

  // 获取句柄
  Result := NativeAccess.GetNativeHandle;

  // 检查句柄有效性
  if Result = nil then
    raise ESSLException.Create(Format(ERROR_HANDLE_NULL, [ContextMsg]));
end;

function TryGetNativeHandle(const AObject: IInterface;
                            out AHandle: Pointer): Boolean;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  Result := Supports(AObject, ISSLNativeHandleAccess, NativeAccess);
  if Result then
    AHandle := NativeAccess.GetNativeHandle
  else
    AHandle := nil;
end;

{ 泛型函数实现 }

generic function GetNativeHandleAs<T>(const AObject: IInterface): T;
var
  Handle: Pointer;
begin
  Handle := GetNativeHandle(AObject);
  Result := T(Handle);
end;

generic function GetNativeHandleAsSafe<T>(const AObject: IInterface;
                                          const AContext: string): T;
var
  Handle: Pointer;
begin
  Handle := GetNativeHandleSafe(AObject, AContext);
  Result := T(Handle);
end;

generic function TryGetNativeHandleAs<T>(const AObject: IInterface;
                                        out AHandle: T): Boolean;
var
  Handle: Pointer;
begin
  Result := TryGetNativeHandle(AObject, Handle);
  if Result then
    AHandle := T(Handle)
  else
    AHandle := T(nil);
end;

{ 辅助查询函数 }

function IsNativeHandleAvailable(const AObject: IInterface): Boolean;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  Result := Supports(AObject, ISSLNativeHandleAccess, NativeAccess) and
            (NativeAccess.GetNativeHandle <> nil);
end;

function GetBackendType(const AObject: IInterface): TSSLLibraryType;
var
  NativeAccess: ISSLNativeHandleAccess;
  LibraryRef: ISSLLibrary;
begin
  if Supports(AObject, ISSLNativeHandleAccess, NativeAccess) then
    Result := NativeAccess.GetBackendType
  else if Supports(AObject, ISSLLibrary, LibraryRef) then
    Result := LibraryRef.GetLibraryType
  else
    Result := sslAutoDetect;  // 未知对象
end;

function IsNativeHandleValid(const AObject: IInterface): Boolean;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  Result := Supports(AObject, ISSLNativeHandleAccess, NativeAccess) and
            NativeAccess.IsNativeHandleValid;
end;

end.
