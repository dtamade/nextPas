program test_platform_which;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.platform.which,
  nextpas.core.platform.fs,
  nextpas.core.platform.env,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestFindSh;
var
  Buf: array[0..511] of AnsiChar;
  R: Int32;
begin
  R := platform_which('sh', @Buf[0], 512);
  Check(R > 0, 'which sh returns path');
  Check(platform_fs_is_file(@Buf[0]), 'path exists');
end;

procedure TestFindLs;
var
  Buf: array[0..511] of AnsiChar;
  R: Int32;
begin
  R := platform_which('ls', @Buf[0], 512);
  Check(R > 0, 'which ls returns path');
  Check(platform_fs_is_file(@Buf[0]), 'path exists');
end;

procedure TestNotFound;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_which('nonexistent_tool_xyz_999', @Buf[0], 256);
  Check(R = -1, 'not found returns -1');
end;

procedure TestAbsolutePath;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_which('/bin/sh', @Buf[0], 256);
  Check(R > 0, 'absolute path found');
  Check(Buf[0] = '/', 'starts with /');
end;

procedure TestAbsoluteNotExist;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_which('/nonexistent_xyz', @Buf[0], 256);
  Check(R = -1, 'absolute non-existent returns -1');
end;

{$IFDEF NEXTPAS_LINUX}
function RepeatPathPrefix(const ADir: string; const ACount: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ACount do
  begin
    if Result <> '' then
      Result := Result + ':';
    Result := Result + ADir + IntToStr(I);
  end;
end;

procedure TestLongPathFindsTailEntry;
var
  Buf: array[0..1023] of AnsiChar;
  LOldPath, LLongPath, LDir, LTool: string;
  LOldBuf: array of AnsiChar;
  LOldLen, R: Int32;
  LHadOldPath: Boolean;
  LHandle: TPlatformFileHandle;
  LWritten: PtrUInt;
const
  TOOL_BODY = '#!/bin/sh' + #10 + 'exit 0' + #10;
begin
  LDir := '/tmp/nextpas-platform-which-long-path-' + IntToStr(GetProcessID);
  LTool := LDir + '/npwhich_tail_tool';
  LHadOldPath := platform_env_get('PATH', nil, 0, LOldLen) = 0;
  if LHadOldPath then
  begin
    SetLength(LOldBuf, LOldLen + 1);
    Check(platform_env_get('PATH', @LOldBuf[0], Length(LOldBuf), LOldLen) = 0,
      'save old PATH');
    SetString(LOldPath, @LOldBuf[0], LOldLen);
  end
  else
    LOldPath := '';

  platform_file_unlink(PAnsiChar(LTool));
  platform_file_rmdir(PAnsiChar(LDir));

  try
    Check(platform_file_mkdir(PAnsiChar(LDir), 493) = 0,
      'long PATH test dir mkdir');
    Check(platform_file_open(PAnsiChar(LTool), fomWriteOnly, fcmCreateAlways,
      LHandle) = 0, 'long PATH test tool create');
    try
      Check(platform_file_write(LHandle, PAnsiChar(TOOL_BODY), Length(TOOL_BODY),
        LWritten) = 0, 'long PATH test tool write');
      Check(LWritten = Length(TOOL_BODY), 'long PATH test tool write complete');
    finally
      Check(platform_file_close(LHandle) = 0, 'long PATH test tool close');
    end;
    Check(platform_file_chmod(PAnsiChar(LTool), 493) = 0,
      'long PATH test tool chmod executable');

    LLongPath := RepeatPathPrefix(LDir + '-padding-', 80) + ':' + LDir;
    Check(Length(LLongPath) > 4096, 'test PATH exceeds fixed 4096 buffer');
    Check(platform_env_set('PATH', PAnsiChar(LLongPath)) = 0,
      'long PATH installed');

    R := platform_which('npwhich_tail_tool', @Buf[0], Length(Buf));
    Check(R > 0, 'which finds executable after long PATH prefix');
    Check(string(PAnsiChar(@Buf[0])) = LTool, 'which returns tail executable path');
  finally
    if LHadOldPath then
      platform_env_set('PATH', PAnsiChar(LOldPath))
    else
      platform_env_unset('PATH');
    platform_file_unlink(PAnsiChar(LTool));
    platform_file_rmdir(PAnsiChar(LDir));
  end;
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.which');
  T.Run('find sh', @TestFindSh);
  T.Run('find ls', @TestFindLs);
  T.Run('not found', @TestNotFound);
  T.Run('absolute path', @TestAbsolutePath);
  T.Run('absolute not exist', @TestAbsoluteNotExist);
{$IFDEF NEXTPAS_LINUX}
  T.Run('long PATH finds tail entry', @TestLongPathFindsTailEntry);
{$ENDIF}
  T.Summary;
end.
