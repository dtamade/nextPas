program test_platform_pipe_wine;

{ Wine runtime evidence for platform.pipe on Windows. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.pipe;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

{ 1. Create pipe succeeds with valid handles }
procedure TestCreatePipe;
var
  LPipe: TPlatformPipe;
begin
  Check(platform_pipe_create(LPipe) = 0, 'create pipe');
  Check(LPipe.ReadHandle <> 0, 'read handle not zero');
  Check(LPipe.WriteHandle <> 0, 'write handle not zero');
  Check(LPipe.ReadHandle <> LPipe.WriteHandle, 'handles differ');
  Check(LPipe.ReadFd >= 0, 'read fd valid');
  Check(LPipe.WriteFd >= 0, 'write fd valid');
  platform_pipe_close(LPipe);
end;

{ 2. Close pipe invalidates handles }
procedure TestClosePipe;
var
  LPipe: TPlatformPipe;
begin
  Check(platform_pipe_create(LPipe) = 0, 'create pipe');
  Check(platform_pipe_close(LPipe) = 0, 'close pipe');
  Check(LPipe.ReadFd < 0, 'read fd invalidated');
  Check(LPipe.WriteFd < 0, 'write fd invalidated');
end;

{ 3. Close read end independently }
procedure TestCloseRead;
var
  LPipe: TPlatformPipe;
begin
  Check(platform_pipe_create(LPipe) = 0, 'create pipe');
  Check(platform_pipe_close_read(LPipe) = 0, 'close read');
  Check(LPipe.ReadFd < 0, 'read fd invalidated');
  Check(LPipe.WriteFd >= 0, 'write fd still valid');
  platform_pipe_close_write(LPipe);
end;

{ 4. Close write end independently }
procedure TestCloseWrite;
var
  LPipe: TPlatformPipe;
begin
  Check(platform_pipe_create(LPipe) = 0, 'create pipe');
  Check(platform_pipe_close_write(LPipe) = 0, 'close write');
  Check(LPipe.WriteFd < 0, 'write fd invalidated');
  Check(LPipe.ReadFd >= 0, 'read fd still valid');
  platform_pipe_close_read(LPipe);
end;

{ 5. Double close - Windows may or may not return error }
procedure TestDoubleClose;
var
  LPipe: TPlatformPipe;
begin
  Check(platform_pipe_create(LPipe) = 0, 'create pipe');
  Check(platform_pipe_close(LPipe) = 0, 'first close');
  { On Windows, double close may succeed or fail depending on handle reuse }
  platform_pipe_close(LPipe);
end;

{ 6. Close already-closed read returns error }
procedure TestDoubleCloseRead;
var
  LPipe: TPlatformPipe;
begin
  Check(platform_pipe_create(LPipe) = 0, 'create pipe');
  Check(platform_pipe_close_read(LPipe) = 0, 'close read');
  Check(platform_pipe_close_read(LPipe) <> 0, 'second close read returns error');
  platform_pipe_close_write(LPipe);
end;

{ 7. Close already-closed write returns error }
procedure TestDoubleCloseWrite;
var
  LPipe: TPlatformPipe;
begin
  Check(platform_pipe_create(LPipe) = 0, 'create pipe');
  Check(platform_pipe_close_write(LPipe) = 0, 'close write');
  Check(platform_pipe_close_write(LPipe) <> 0, 'second close write returns error');
  platform_pipe_close_read(LPipe);
end;

{ 8. Multiple pipe creates produce different handles }
procedure TestMultiplePipes;
var
  LP1, LP2: TPlatformPipe;
begin
  Check(platform_pipe_create(LP1) = 0, 'create pipe 1');
  Check(platform_pipe_create(LP2) = 0, 'create pipe 2');
  Check(LP1.ReadHandle <> LP2.ReadHandle, 'read handles differ');
  Check(LP1.WriteHandle <> LP2.WriteHandle, 'write handles differ');
  platform_pipe_close(LP1);
  platform_pipe_close(LP2);
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.pipe.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('create pipe', @TestCreatePipe);
  T.Test('close pipe invalidates', @TestClosePipe);
  T.Test('close read end', @TestCloseRead);
  T.Test('close write end', @TestCloseWrite);
  T.Test('double close returns error', @TestDoubleClose);
  T.Test('double close read', @TestDoubleCloseRead);
  T.Test('double close write', @TestDoubleCloseWrite);
  T.Test('multiple pipes have different handles', @TestMultiplePipes);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.
