{**
 * nextpas.core.platform.files.text - 文本文件整体读写（高层）
 *
 * 职责：整个文件内容 ↔ AnsiString 的场景（配置、工程、导出文本）。
 * 层次：建立在 files.pas（fd 级）与 fs.pas（文件系统操作）之上，
 *       不直接依赖 FPC RTL（SysUtils/Classes 等）。
 *}

unit nextpas.core.platform.files.text;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.fs;

{** @desc 读整个文件到 AData
    @param APath 文件路径（空路径返回 False）
    @param AData 输出内容（成功时含全部字节；失败保持不变）
    @return True 成功；文件不存在/打开/读取失败返回 False *}
function FileReadAllText(const APath: AnsiString; out AData: AnsiString): Boolean;

{** @desc 写整个文件（创建或截断覆盖）
    @param APath 文件路径（空路径返回 False）
    @param AData 待写入内容（空串 = 创建空文件）
    @return True 成功；路径不可写等失败返回 False *}
function FileWriteAllText(const APath, AData: AnsiString): Boolean;

implementation

function FileReadAllText(const APath: AnsiString; out AData: AnsiString): Boolean;
var
  H: TPlatformFileHandle;
  Size: Int64;
  N: PtrUInt;
  Total: PtrUInt;
  P: PByte;
begin
  Result := False;
  if APath = '' then
    Exit;
  if platform_fs_file_size(PAnsiChar(APath), Size) <> 0 then
    Exit;
  if Size < 0 then
    Exit;
  if platform_file_open(PAnsiChar(APath), fomReadOnly, fcmOpenExisting, H) <> 0 then
    Exit;
  try
    SetLength(AData, Size);
    if Size = 0 then
      Exit(True);                    { 空文件 = 空串 }
    P := PByte(PAnsiChar(AData));
    Total := 0;
    { 循环读满; read 返回错误(EINTR 等)或意外 EOF 一律失败 }
    while Total < PtrUInt(Size) do
    begin
      if platform_file_read(H, P + Total, PtrUInt(Size) - Total, N) <> 0 then
        Exit(False);
      if N = 0 then
        Exit(False);
      Inc(Total, N);
    end;
    Result := True;
  finally
    platform_file_close(H);
  end;
end;

function FileWriteAllText(const APath, AData: AnsiString): Boolean;
var
  H: TPlatformFileHandle;
  N: PtrUInt;
  Total: PtrUInt;
  Len: PtrUInt;
  P: PByte;
begin
  Result := False;
  if APath = '' then
    Exit;
  { fcmCreateAlways = O_CREAT|O_TRUNC: 创建或截断覆盖 }
  if platform_file_open(PAnsiChar(APath), fomWriteOnly, fcmCreateAlways, H) <> 0 then
    Exit;
  try
    Len := PtrUInt(Length(AData));
    if Len = 0 then
      Exit(True);                    { 空内容 = 建空文件 }
    P := PByte(PAnsiChar(AData));
    Total := 0;
    while Total < Len do
    begin
      if platform_file_write(H, P + Total, Len - Total, N) <> 0 then
        Exit(False);
      if N = 0 then
        Exit(False);
      Inc(Total, N);
    end;
    Result := True;
  finally
    platform_file_close(H);
  end;
end;

end.
