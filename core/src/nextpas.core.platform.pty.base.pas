unit nextpas.core.platform.pty.base;
{**
 * @desc PTY 基础类型定义。
 *}

{$I nextpas.core.settings.inc}

interface

type
  {** @desc PTY 窗口大小 *}
  TPlatformPtySize = record
    Cols: UInt16;
    Rows: UInt16;
    XPixel: UInt16;
    YPixel: UInt16;
    {** @desc 检查窗口大小是否有效（行列均大于 0）
        @return True 如果窗口大小有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查窗口大小是否无效（任一维度为 0）
        @return True 如果窗口大小无效 *}
    function IsInvalid: Boolean; inline;
    {** @desc 检查窗口大小是否为空（行列均为 0）
        @return True 如果窗口大小为空 *}
    function IsEmpty: Boolean; inline;
  end;

  {** @desc PTY 句柄（平台无关封装） *}
  TPlatformPty = record
  {$IFDEF NEXTPAS_UNIX}
    MasterFd: Int32;
    SlaveFd: Int32;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
    ConPty: Pointer;
    PipeIn: PtrUInt;
    PipeOut: PtrUInt;
  {$ENDIF}
    {** @desc 检查 PTY 是否有效（主从句柄均有效）
        @return True 如果 PTY 有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查 PTY 是否无效（任一句柄无效）
        @return True 如果 PTY 无效 *}
    function IsInvalid: Boolean; inline;
    {** @desc 检查主句柄是否有效
        @return True 如果主句柄有效 *}
    function IsMasterValid: Boolean; inline;
    {** @desc 检查从句柄是否有效
        @return True 如果从句柄有效 *}
    function IsSlaveValid: Boolean; inline;
  end;

  {** @desc PTY 启动失败阶段枚举 *}
  TPlatformPtySpawnStage = (
    ptssNone,
    ptssPipe,
    ptssFork,
    ptssSetsid,
    ptssOpenSlave,
    ptssTiocsctty,
    ptssChdir,
    ptssDup,
    ptssExec
  );

implementation

function TPlatformPtySize.IsValid: Boolean;
begin
  Result := (Cols > 0) and (Rows > 0);
end;

function TPlatformPtySize.IsInvalid: Boolean;
begin
  Result := (Cols = 0) or (Rows = 0);
end;

function TPlatformPtySize.IsEmpty: Boolean;
begin
  Result := (Cols = 0) or (Rows = 0);
end;

function TPlatformPty.IsValid: Boolean;
begin
{$IFDEF NEXTPAS_UNIX}
  Result := (MasterFd >= 0) and (SlaveFd >= 0);
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  Result := (ConPty <> nil) and (PipeIn <> 0) and (PipeOut <> 0);
{$ENDIF}
end;

function TPlatformPty.IsInvalid: Boolean;
begin
  Result := not IsValid;
end;

function TPlatformPty.IsMasterValid: Boolean;
begin
{$IFDEF NEXTPAS_UNIX}
  Result := MasterFd >= 0;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  Result := ConPty <> nil;
{$ENDIF}
end;

function TPlatformPty.IsSlaveValid: Boolean;
begin
{$IFDEF NEXTPAS_UNIX}
  Result := SlaveFd >= 0;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  Result := (PipeIn <> 0) and (PipeOut <> 0);
{$ENDIF}
end;

end.
