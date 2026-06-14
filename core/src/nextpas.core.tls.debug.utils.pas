unit nextpas.core.tls.debug.utils;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{**
 * Unit: nextpas.core.tls.debug.utils
 * Purpose: SSL/TLS 调试和诊断工具
 *
 * Phase 2.3.2: Utils模块重组
 * Phase 2.4: 错误处理标准化（2025-01-18）
 *
 * 本模块从 nextpas.core.tls.utils 中提取调试相关功能，
 * 包括数据转储、辅助类（TSSLMemoryStream、TSSLStringBuilder、TSSLBitSet）。
 *
 * Features:
 * - 字节数组/配置/证书/连接信息的可读格式转储
 * - TSSLMemoryStream: 带调试功能的内存流
 * - TSSLStringBuilder: 带缩进的字符串构建器
 * - TSSLBitSet: 位集合操作
 *
 * Error Handling (Phase 2.4):
 * - Stream I/O errors: ESSLResourceException with context
 * - Invalid arguments: ESSLInvalidArgument with range details
 *
 * Thread Safety: TSSLUtils 类方法线程安全，辅助类非线程安全
 *
 * @author fafafa.ssl team
 * @version 1.1.0
 * @since 2025-12-16
 *}

interface

uses
  SysUtils, Math,
  nextpas.core.text.base,
  nextpas.core.text.strings,
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions;

type
  { TSSLDebugUtils - 调试工具类 }
  TSSLDebugUtils = class
  public
    {**
     * 将字节数组转储为十六进制+ASCII格式
     *
     * @param ABytes 要转储的字节数组
     * @param ABytesPerLine 每行显示的字节数（默认16）
     * @return 格式化的十六进制转储字符串
     *
     * @example
     * <code>
     *   WriteLn(TSSLDebugUtils.DumpBytes(LData));
     *   // 输出:
     *   // 00000000  48 65 6C 6C 6F 20 57 6F 72 6C 64 21 00 00 00 00  Hello World!....
     * </code>
     *}
    class function DumpBytes(const ABytes: TBytes; ABytesPerLine: Integer = 16): string;

    {**
     * 转储 SSL 配置信息
     *}
    class function DumpSSLConfig(const AConfig: TSSLConfig): string;

    {**
     * 转储证书信息
     *}
    class function DumpCertificateInfo(const AInfo: TSSLCertificateInfo): string;

    {**
     * 转储连接信息
     *}
    class function DumpConnectionInfo(const AInfo: TSSLConnectionInfo): string;
  end;

  {**
   * TSSLMemoryStream - 带位置跟踪和调试功能的内存流
   *
   * 使用内部字节缓冲，提供便捷的二进制读写方法和十六进制转储。
   * 用于 SSL/TLS 消息的调试和解析。
   *}
  TSSLMemoryStream = class
  private
    FName: string;
    FDebug: Boolean;
    FData: TBytes;
    FSize: Integer;
    FPosition: Integer;
    procedure EnsureReadable(ACount: Integer; const AContext: string);
    procedure EnsureWritableCapacity(ACount: Integer);
    function GetSize: Integer;
    procedure SetSize(AValue: Integer);
    function GetPosition: Integer;
    procedure SetPosition(AValue: Integer);
  public
    constructor Create(const AName: string = ''; ADebug: Boolean = False);
    function Read(var ABuffer; ACount: Integer): Integer;
    function Write(const ABuffer; ACount: Integer): Integer;
    procedure Clear;

    { 二进制读取 }
    function ReadByte: Byte;
    function ReadWord: Word;
    function ReadDWord: DWord;
    function ReadBytes(ACount: Integer): TBytes;
    function ReadString(ALength: Integer): string;

    { 二进制写入 }
    procedure WriteByte(AValue: Byte);
    procedure WriteWord(AValue: Word);
    procedure WriteDWord(AValue: DWord);
    procedure WriteBytes(const ABytes: TBytes);
    procedure WriteString(const AStr: string);

    { 调试工具 }
    function PeekByte: Byte;
    function RemainingBytes: Integer;
    function GetHexDump: string;

    property Name: string read FName write FName;
    property Debug: Boolean read FDebug write FDebug;
    property Size: Integer read GetSize write SetSize;
    property Position: Integer read GetPosition write SetPosition;
  end;

  {**
   * TSSLStringBuilder - 带缩进支持的字符串构建器
   *
   * 用于生成格式化的调试输出和日志信息。
   *}
  TSSLStringBuilder = class
  private
    FBuffer: TStringArray;
    FIndentLevel: Integer;
    FIndentStr: string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Append(const AStr: string);
    procedure AppendLine(const AStr: string = '');
    procedure AppendFormat(const AFormat: string; const AArgs: array of const);

    procedure Indent;
    procedure Unindent;
    procedure SetIndentStr(const AStr: string);

    procedure Clear;
    function ToString: string; override;

    property IndentLevel: Integer read FIndentLevel;
  end;

  {**
   * TSSLBitSet - 位集合操作
   *
   * 用于 SSL/TLS 特性标志位、密码套件掩码等场景。
   *}
  TSSLBitSet = class
  private
    FBits: array of Byte;
    FSize: Integer;
    function GetBit(AIndex: Integer): Boolean;
    procedure SetBit(AIndex: Integer; AValue: Boolean);
  public
    constructor Create(ASize: Integer);
    destructor Destroy; override;

    procedure Clear;
    procedure SetAll;
    procedure Toggle(AIndex: Integer);

    function Count: Integer;  // 返回设置为1的位数
    function IsEmpty: Boolean;
    function IsFull: Boolean;

    function ToBytes: TBytes;
    procedure FromBytes(const ABytes: TBytes);

    property Bits[AIndex: Integer]: Boolean read GetBit write SetBit; default;
    property Size: Integer read FSize;
  end;

  {**
   * TSSLResourceInfo - 资源分配信息记录
   *
   * 用于调试模式下跟踪资源分配。
   *}
  TSSLResourceInfo = record
    ResourceType: string;     // 资源类型名称
    ResourcePtr: Pointer;     // 资源指针
    AllocTime: TDateTime;     // 分配时间
    AllocLocation: string;    // 分配位置（调用者信息）
  end;

  (**
   * TSSLResourceTracker - 资源泄漏检测器
   *
   * 在调试模式下跟踪 SSL 资源的分配和释放，
   * 帮助检测资源泄漏问题。
   *
   * 使用方法:
   * - 在资源创建时调用 RegisterResource
   * - 在资源释放时调用 UnregisterResource
   * - 在程序结束时调用 ReportLeaks 检查泄漏
   *
   * @example
   * <code>
   *   // 创建资源时
   *   {$IFDEF DEBUG}
   *   TSSLResourceTracker.Instance.RegisterResource('TOpenSSLContext', Self, 'CreateContext');
   *   {$ENDIF}
   *
   *   // 释放资源时
   *   {$IFDEF DEBUG}
   *   TSSLResourceTracker.Instance.UnregisterResource(Self);
   *   {$ENDIF}
   *
   *   // 程序结束时检查
   *   {$IFDEF DEBUG}
   *   TSSLResourceTracker.Instance.ReportLeaks;
   *   {$ENDIF}
   * </code>
   *)
  TSSLResourceTracker = class
  private
    class var FInstance: TSSLResourceTracker;
    class var FLock: TRTLCriticalSection;
    class var FInitialized: Boolean;
  private
    FResources: array of TSSLResourceInfo;
    FEnabled: Boolean;
    FReportOnDestroy: Boolean;
    function FindResource(APtr: Pointer): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    {** 注册资源分配 *}
    procedure RegisterResource(const AType: string; APtr: Pointer; const ALocation: string = '');

    {** 注销资源释放 *}
    procedure UnregisterResource(APtr: Pointer);

    {** 获取当前跟踪的资源数量 *}
    function GetResourceCount: Integer;

    {** 获取资源列表的快照 *}
    function GetResourceSnapshot: string;

    {** 报告泄漏（如果有） *}
    function ReportLeaks: string;

    {** 检查是否有泄漏 *}
    function HasLeaks: Boolean;

    {** 清除所有跟踪记录 *}
    procedure Clear;

    {** 启用/禁用跟踪 *}
    property Enabled: Boolean read FEnabled write FEnabled;

    {** 析构时自动报告泄漏 *}
    property ReportOnDestroy: Boolean read FReportOnDestroy write FReportOnDestroy;

    {** 获取单例实例 *}
    class function Instance: TSSLResourceTracker;

    {** 释放单例 *}
    class procedure FreeInstance; reintroduce;
  end;

implementation

{ TSSLDebugUtils }

class function TSSLDebugUtils.DumpBytes(const ABytes: TBytes; ABytesPerLine: Integer): string;
var
  I, J: Integer;
  LHex, LAscii: string;
  LSB: TSSLStringBuilder;
begin
  LSB := TSSLStringBuilder.Create;
  try
    for I := 0 to (Length(ABytes) - 1) div ABytesPerLine do
    begin
      LHex := '';
      LAscii := '';

      for J := 0 to ABytesPerLine - 1 do
      begin
        if I * ABytesPerLine + J < Length(ABytes) then
        begin
          LHex := LHex + IntToHex(ABytes[I * ABytesPerLine + J], 2) + ' ';
          if ABytes[I * ABytesPerLine + J] in [32..126] then
            LAscii := LAscii + Chr(ABytes[I * ABytesPerLine + J])
          else
            LAscii := LAscii + '.';
        end
        else
        begin
          LHex := LHex + '   ';
          LAscii := LAscii + ' ';
        end;
      end;

      LSB.AppendFormat('%8.8x  %-*s  %s', [
        I * ABytesPerLine,
        ABytesPerLine * 3,
        LHex,
        LAscii
      ]);
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

class function TSSLDebugUtils.DumpSSLConfig(const AConfig: TSSLConfig): string;
var
  LSB: TSSLStringBuilder;
begin
  LSB := TSSLStringBuilder.Create;
  try
    LSB.AppendLine('SSL 配置:');
    LSB.Indent;
    LSB.AppendFormat('库类型: %s', [SSL_LIBRARY_NAMES[AConfig.LibraryType]]);
    LSB.AppendFormat('上下文类型: %d', [Ord(AConfig.ContextType)]);
    LSB.AppendFormat('证书文件: %s', [AConfig.CertificateFile]);
    LSB.AppendFormat('私钥文件: %s', [AConfig.PrivateKeyFile]);
    LSB.AppendFormat('私钥口令: %s', [
      BoolToStr(AConfig.PrivateKeyPassword <> '', '已设置', '未设置')
    ]);
    LSB.AppendFormat('CA文件: %s', [AConfig.CAFile]);
    LSB.AppendFormat(
      '系统根证书: %s (context-scoped trust-store opt-in；factory/direct-library path 会在创建时加载)',
      [BoolToStr(AConfig.UseSystemRoots, '启用', '禁用')]
    );
    LSB.AppendFormat(
      '缓冲区大小: %d (transport/IO 层配置；factory context 创建不消费)',
      [AConfig.BufferSize]
    );
    LSB.AppendFormat(
      '握手超时: %d ms (连接层配置；使用 TSSLConnector/TSSLAcceptor/ISSLConnectionControl)',
      [AConfig.HandshakeTimeout]
    );
    LSB.AppendFormat(
      '服务器名称: %s (客户端上下文默认 SNI；更推荐连接级设置，server factory context 不接受)',
      [AConfig.ServerName]
    );
    LSB.AppendFormat(
      '客户端 Early Data: %s (仅创建 client/both context 时应用)',
      [BoolToStr(AConfig.ClientEarlyDataEnabled, '启用', '禁用')]
    );
    LSB.AppendFormat(
      '服务端 Early Data 策略: %d (仅创建 server/both context 时应用)',
      [Ord(AConfig.ServerEarlyDataPolicy)]
    );
    LSB.AppendFormat(
      '服务端 Early Data 上限: %d (仅创建 server/both context 时应用)',
      [AConfig.ServerMaxEarlyDataSize]
    );
    LSB.AppendFormat(
      '服务端 Early Data Replay Store File: %s (server-scoped；client builder/factory context 不接受)',
      [AConfig.ServerEarlyDataReplayStoreFile]
    );
    LSB.AppendFormat(
      '服务端 Early Data Replay Store Directory: %s (server-scoped；client builder/factory context 不接受)',
      [AConfig.ServerEarlyDataReplayStoreDirectory]
    );

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

class function TSSLDebugUtils.DumpCertificateInfo(
  const AInfo: TSSLCertificateInfo): string;
var
  LSB: TSSLStringBuilder;
  SAN: string;
begin
  LSB := TSSLStringBuilder.Create;
  try
    LSB.AppendLine('证书信息:');
    LSB.Indent;
    LSB.AppendFormat('主题: %s', [AInfo.Subject]);
    LSB.AppendFormat('颁发者: %s', [AInfo.Issuer]);
    LSB.AppendFormat('序列号: %s', [AInfo.SerialNumber]);
    LSB.AppendFormat('有效期开始: %s', [DateTimeToStr(AInfo.NotBefore)]);
    LSB.AppendFormat('有效期结束: %s', [DateTimeToStr(AInfo.NotAfter)]);
    LSB.AppendFormat('公钥算法: %s', [AInfo.PublicKeyAlgorithm]);
    LSB.AppendFormat('公钥长度: %d 位', [AInfo.PublicKeySize]);
    LSB.AppendFormat('签名算法: %s', [AInfo.SignatureAlgorithm]);
    LSB.AppendFormat('SHA256指纹: %s', [AInfo.FingerprintSHA256]);
    LSB.AppendFormat('是否CA证书: %s', [BoolToStr(AInfo.IsCA, '是', '否')]);

    if Length(AInfo.SubjectAltNames) > 0 then
    begin
      LSB.AppendLine('主题备用名称:');
      LSB.Indent;
      for SAN in AInfo.SubjectAltNames do
        LSB.AppendFormat('- %s', [SAN]);
      LSB.Unindent;
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

class function TSSLDebugUtils.DumpConnectionInfo(const AInfo: TSSLConnectionInfo): string;
var
  LSB: TSSLStringBuilder;
begin
  LSB := TSSLStringBuilder.Create;
  try
    LSB.AppendLine('连接信息:');
    LSB.Indent;
    LSB.AppendFormat('协议版本: %s', [SSL_PROTOCOL_NAMES[AInfo.ProtocolVersion]]);
    LSB.AppendFormat('密码套件: %s', [AInfo.CipherSuite]);
    LSB.AppendFormat('密钥长度: %d 位', [AInfo.KeySize]);
    LSB.AppendFormat('会话ID: %s', [AInfo.SessionId]);
    LSB.AppendFormat('会话复用: %s', [BoolToStr(AInfo.IsResumed, '是', '否')]);
    LSB.AppendFormat('服务器名称: %s', [AInfo.ServerName]);
    LSB.AppendFormat('ALPN协议: %s', [AInfo.ALPNProtocol]);

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

{ TSSLMemoryStream }

constructor TSSLMemoryStream.Create(const AName: string; ADebug: Boolean);
begin
  FName := AName;
  FDebug := ADebug;
  FData := nil;
  FSize := 0;
  FPosition := 0;
end;

procedure TSSLMemoryStream.EnsureReadable(ACount: Integer; const AContext: string);
begin
  if (ACount < 0) or (FPosition < 0) or (FPosition + ACount > FSize) then
    raise ESSLResourceException.CreateWithContext(
      Format('Failed to read %d bytes from stream', [ACount]),
      sslErrInvalidData,
      AContext
    );
end;

procedure TSSLMemoryStream.EnsureWritableCapacity(ACount: Integer);
var
  LRequired: Integer;
  LCapacity: Integer;
begin
  if ACount < 0 then
    raise ESSLInvalidArgument.CreateWithContext(
      Format('Write count %d must be >= 0', [ACount]),
      sslErrInvalidParam,
      'TSSLMemoryStream.EnsureWritableCapacity'
    );

  LRequired := FPosition + ACount;
  if LRequired <= Length(FData) then
    Exit;

  LCapacity := Length(FData);
  if LCapacity = 0 then
    LCapacity := 16;
  while LCapacity < LRequired do
    LCapacity := LCapacity * 2;
  SetLength(FData, LCapacity);
end;

function TSSLMemoryStream.GetSize: Integer;
begin
  Result := FSize;
end;

procedure TSSLMemoryStream.SetSize(AValue: Integer);
begin
  if AValue < 0 then
    raise ESSLInvalidArgument.CreateWithContext(
      Format('Size %d must be >= 0', [AValue]),
      sslErrInvalidParam,
      'TSSLMemoryStream.SetSize'
    );

  if AValue > Length(FData) then
    SetLength(FData, AValue);
  FSize := AValue;
  if FPosition > FSize then
    FPosition := FSize;
end;

function TSSLMemoryStream.GetPosition: Integer;
begin
  Result := FPosition;
end;

procedure TSSLMemoryStream.SetPosition(AValue: Integer);
begin
  if (AValue < 0) or (AValue > FSize) then
    raise ESSLInvalidArgument.CreateWithContext(
      Format('Position %d out of range [0..%d]', [AValue, FSize]),
      sslErrInvalidParam,
      'TSSLMemoryStream.SetPosition'
    );
  FPosition := AValue;
end;

function TSSLMemoryStream.Read(var ABuffer; ACount: Integer): Integer;
begin
  if ACount <= 0 then
    Exit(0);
  if FPosition >= FSize then
    Exit(0);
  Result := FSize - FPosition;
  if Result > ACount then
    Result := ACount;
  Move(FData[FPosition], ABuffer, Result);
  Inc(FPosition, Result);
end;

function TSSLMemoryStream.Write(const ABuffer; ACount: Integer): Integer;
begin
  if ACount <= 0 then
    Exit(0);
  EnsureWritableCapacity(ACount);
  Move(ABuffer, FData[FPosition], ACount);
  Inc(FPosition, ACount);
  if FPosition > FSize then
    FSize := FPosition;
  Result := ACount;
end;

procedure TSSLMemoryStream.Clear;
begin
  FData := nil;
  FSize := 0;
  FPosition := 0;
end;

function TSSLMemoryStream.ReadByte: Byte;
begin
  EnsureReadable(1, 'TSSLMemoryStream.ReadByte');
  Result := FData[FPosition];
  Inc(FPosition);
end;

function TSSLMemoryStream.ReadWord: Word;
begin
  EnsureReadable(2, 'TSSLMemoryStream.ReadWord');
  Move(FData[FPosition], Result, SizeOf(Result));
  Inc(FPosition, SizeOf(Result));
end;

function TSSLMemoryStream.ReadDWord: DWord;
begin
  EnsureReadable(4, 'TSSLMemoryStream.ReadDWord');
  Move(FData[FPosition], Result, SizeOf(Result));
  Inc(FPosition, SizeOf(Result));
end;

function TSSLMemoryStream.ReadBytes(ACount: Integer): TBytes;
begin
  Result := nil;
  if ACount < 0 then
    raise ESSLInvalidArgument.CreateWithContext(
      Format('Read count %d must be >= 0', [ACount]),
      sslErrInvalidParam,
      'TSSLMemoryStream.ReadBytes'
    );
  SetLength(Result, ACount);
  if ACount > 0 then
  begin
    EnsureReadable(ACount, 'TSSLMemoryStream.ReadBytes');
    Move(FData[FPosition], Result[0], ACount);
    Inc(FPosition, ACount);
  end;
end;

function TSSLMemoryStream.ReadString(ALength: Integer): string;
var
  LBytes: TBytes;
begin
  LBytes := ReadBytes(ALength);
  Result := UTF8BytesToString(LBytes);
end;

procedure TSSLMemoryStream.WriteByte(AValue: Byte);
begin
  Write(AValue, SizeOf(AValue));
end;

procedure TSSLMemoryStream.WriteWord(AValue: Word);
begin
  Write(AValue, SizeOf(AValue));
end;

procedure TSSLMemoryStream.WriteDWord(AValue: DWord);
begin
  Write(AValue, SizeOf(AValue));
end;

procedure TSSLMemoryStream.WriteBytes(const ABytes: TBytes);
begin
  if Length(ABytes) > 0 then
    Write(ABytes[0], Length(ABytes));
end;

procedure TSSLMemoryStream.WriteString(const AStr: string);
var
  LBytes: TBytes;
begin
  LBytes := StringToUTF8Bytes(AStr);
  WriteBytes(LBytes);
end;

function TSSLMemoryStream.PeekByte: Byte;
var
  LOldPos: Integer;
begin
  LOldPos := Position;
  try
    Result := ReadByte;
  finally
    Position := LOldPos;
  end;
end;

function TSSLMemoryStream.RemainingBytes: Integer;
begin
  Result := Size - Position;
end;

function TSSLMemoryStream.GetHexDump: string;
var
  LOldPos: Integer;
  LBytes: TBytes;
begin
  LOldPos := Position;
  try
    Position := 0;
    SetLength(LBytes, Size);
    if Size > 0 then
      Read(LBytes[0], Size);
    Result := TSSLDebugUtils.DumpBytes(LBytes);
  finally
    Position := LOldPos;
  end;
end;

{ TSSLStringBuilder }

constructor TSSLStringBuilder.Create;
begin
  inherited;
  FBuffer := nil;
  FIndentLevel := 0;
  FIndentStr := '  ';
end;

destructor TSSLStringBuilder.Destroy;
begin

  inherited;
end;

procedure TSSLStringBuilder.Append(const AStr: string);
begin
  if Length(FBuffer) = 0 then
    FBuffer.Add('');

  FBuffer[Length(FBuffer) - 1] := FBuffer[Length(FBuffer) - 1] + AStr;
end;

procedure TSSLStringBuilder.AppendLine(const AStr: string);
var
  LIndent: string;
begin
  if FIndentLevel > 0 then
    LIndent := StringOfChar(' ', Length(FIndentStr) * FIndentLevel)
  else
    LIndent := '';

  FBuffer.Add(LIndent + AStr);
end;

procedure TSSLStringBuilder.AppendFormat(const AFormat: string; const AArgs: array of const);
begin
  AppendLine(Format(AFormat, AArgs));
end;

procedure TSSLStringBuilder.Indent;
begin
  Inc(FIndentLevel);
end;

procedure TSSLStringBuilder.Unindent;
begin
  if FIndentLevel > 0 then
    Dec(FIndentLevel);
end;

procedure TSSLStringBuilder.SetIndentStr(const AStr: string);
begin
  FIndentStr := AStr;
end;

procedure TSSLStringBuilder.Clear;
begin
  FBuffer := nil;
  FIndentLevel := 0;
end;

function TSSLStringBuilder.ToString: string;
begin
  Result := StringsJoin(FBuffer, sLineBreak);
end;

{ TSSLBitSet }

constructor TSSLBitSet.Create(ASize: Integer);
begin
  inherited Create;
  FSize := ASize;
  SetLength(FBits, (ASize + 7) div 8);
  Clear;
end;

destructor TSSLBitSet.Destroy;
begin
  SetLength(FBits, 0);
  inherited;
end;

function TSSLBitSet.GetBit(AIndex: Integer): Boolean;
begin
  if (AIndex < 0) or (AIndex >= FSize) then
    raise ESSLInvalidArgument.CreateWithContext(
      Format('Bit index %d out of range [0..%d)', [AIndex, FSize]),
      sslErrInvalidParam,
      'TSSLBitSet.GetBit'
    );

  Result := (FBits[AIndex div 8] and (1 shl (AIndex mod 8))) <> 0;
end;

procedure TSSLBitSet.SetBit(AIndex: Integer; AValue: Boolean);
begin
  if (AIndex < 0) or (AIndex >= FSize) then
    raise ESSLInvalidArgument.CreateWithContext(
      Format('Bit index %d out of range [0..%d)', [AIndex, FSize]),
      sslErrInvalidParam,
      'TSSLBitSet.SetBit'
    );

  if AValue then
    FBits[AIndex div 8] := FBits[AIndex div 8] or (1 shl (AIndex mod 8))
  else
    FBits[AIndex div 8] := FBits[AIndex div 8] and not (1 shl (AIndex mod 8));
end;

procedure TSSLBitSet.Clear;
begin
  FillChar(FBits[0], Length(FBits), 0);
end;

procedure TSSLBitSet.SetAll;
begin
  FillChar(FBits[0], Length(FBits), $FF);

  // 清除最后一个字节中未使用的位
  if FSize mod 8 <> 0 then
    FBits[High(FBits)] := FBits[High(FBits)] and ((1 shl (FSize mod 8)) - 1);
end;

procedure TSSLBitSet.Toggle(AIndex: Integer);
begin
  SetBit(AIndex, not GetBit(AIndex));
end;

function TSSLBitSet.Count: Integer;
var
  I, J: Integer;
begin
  Result := 0;
  for I := 0 to High(FBits) do
  begin
    for J := 0 to 7 do
    begin
      if (FBits[I] and (1 shl J)) <> 0 then
        Inc(Result);
    end;
  end;
end;

function TSSLBitSet.IsEmpty: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to High(FBits) do
  begin
    if FBits[I] <> 0 then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function TSSLBitSet.IsFull: Boolean;
begin
  Result := Count = FSize;
end;

function TSSLBitSet.ToBytes: TBytes;
begin
  Result := nil;
  SetLength(Result, Length(FBits));
  if Length(FBits) > 0 then
    Move(FBits[0], Result[0], Length(FBits));
end;

procedure TSSLBitSet.FromBytes(const ABytes: TBytes);
var
  LLen: Integer;
begin
  LLen := Min(Length(ABytes), Length(FBits));
  if LLen > 0 then
    Move(ABytes[0], FBits[0], LLen);
end;

{ TSSLResourceTracker }

constructor TSSLResourceTracker.Create;
begin
  inherited Create;
  SetLength(FResources, 0);
  FEnabled := True;
  FReportOnDestroy := True;
end;

destructor TSSLResourceTracker.Destroy;
var
  LReport: string;
begin
  if FReportOnDestroy and HasLeaks then
  begin
    LReport := ReportLeaks;
    // 输出到标准错误
    WriteLn(StdErr, LReport);
  end;
  SetLength(FResources, 0);
  inherited;
end;

function TSSLResourceTracker.FindResource(APtr: Pointer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FResources) do
  begin
    if FResources[I].ResourcePtr = APtr then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TSSLResourceTracker.RegisterResource(const AType: string; APtr: Pointer; const ALocation: string);
var
  LInfo: TSSLResourceInfo;
  LLen: Integer;
begin
  if not FEnabled then Exit;
  if APtr = nil then Exit;

  EnterCriticalSection(FLock);
  try
    // 检查是否已存在
    if FindResource(APtr) >= 0 then Exit;

    LInfo.ResourceType := AType;
    LInfo.ResourcePtr := APtr;
    LInfo.AllocTime := Now;
    LInfo.AllocLocation := ALocation;

    LLen := Length(FResources);
    SetLength(FResources, LLen + 1);
    FResources[LLen] := LInfo;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TSSLResourceTracker.UnregisterResource(APtr: Pointer);
var
  LIdx, LLen: Integer;
begin
  if not FEnabled then Exit;
  if APtr = nil then Exit;

  EnterCriticalSection(FLock);
  try
    LIdx := FindResource(APtr);
    if LIdx >= 0 then
    begin
      LLen := Length(FResources);
      // 移动最后一个元素到删除位置
      if LIdx < LLen - 1 then
        FResources[LIdx] := FResources[LLen - 1];
      SetLength(FResources, LLen - 1);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TSSLResourceTracker.GetResourceCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := Length(FResources);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TSSLResourceTracker.GetResourceSnapshot: string;
var
  LSB: TSSLStringBuilder;
  I: Integer;
begin
  EnterCriticalSection(FLock);
  try
    LSB := TSSLStringBuilder.Create;
    try
      LSB.AppendFormat('SSL 资源跟踪快照 (共 %d 个资源):', [Length(FResources)]);
      LSB.Indent;
      for I := 0 to High(FResources) do
      begin
        LSB.AppendFormat('[%d] %s @ %p', [I, FResources[I].ResourceType, FResources[I].ResourcePtr]);
        LSB.Indent;
        LSB.AppendFormat('分配时间: %s', [DateTimeToStr(FResources[I].AllocTime)]);
        if FResources[I].AllocLocation <> '' then
          LSB.AppendFormat('分配位置: %s', [FResources[I].AllocLocation]);
        LSB.Unindent;
      end;
      Result := LSB.ToString;
    finally
      LSB.Free;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TSSLResourceTracker.ReportLeaks: string;
var
  LSB: TSSLStringBuilder;
  I: Integer;
begin
  EnterCriticalSection(FLock);
  try
    if Length(FResources) = 0 then
    begin
      Result := '';
      Exit;
    end;

    LSB := TSSLStringBuilder.Create;
    try
      LSB.AppendLine('');
      LSB.AppendLine('========================================');
      LSB.AppendFormat('SSL 资源泄漏检测: 发现 %d 个未释放资源!', [Length(FResources)]);
      LSB.AppendLine('========================================');
      LSB.Indent;
      for I := 0 to High(FResources) do
      begin
        LSB.AppendFormat('[泄漏 %d] %s @ %p', [I + 1, FResources[I].ResourceType, FResources[I].ResourcePtr]);
        LSB.Indent;
        LSB.AppendFormat('分配时间: %s', [DateTimeToStr(FResources[I].AllocTime)]);
        if FResources[I].AllocLocation <> '' then
          LSB.AppendFormat('分配位置: %s', [FResources[I].AllocLocation]);
        LSB.Unindent;
      end;
      LSB.Unindent;
      LSB.AppendLine('========================================');
      Result := LSB.ToString;
    finally
      LSB.Free;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TSSLResourceTracker.HasLeaks: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := Length(FResources) > 0;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TSSLResourceTracker.Clear;
begin
  EnterCriticalSection(FLock);
  try
    SetLength(FResources, 0);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

class function TSSLResourceTracker.Instance: TSSLResourceTracker;
begin
  if not FInitialized then
  begin
    InitCriticalSection(FLock);
    FInitialized := True;
  end;

  EnterCriticalSection(FLock);
  try
    if FInstance = nil then
      FInstance := TSSLResourceTracker.Create;
    Result := FInstance;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

class procedure TSSLResourceTracker.FreeInstance;
begin
  if FInitialized then
  begin
    EnterCriticalSection(FLock);
    try
      FreeAndNil(FInstance);
    finally
      LeaveCriticalSection(FLock);
    end;
    DoneCriticalSection(FLock);
    FInitialized := False;
  end;
end;

end.
