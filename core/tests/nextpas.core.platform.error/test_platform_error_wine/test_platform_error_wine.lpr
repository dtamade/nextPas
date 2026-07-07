program test_platform_error_wine;

{ Wine runtime evidence for platform.error on Windows. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.platform.error;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

{ 1. Error message for success code (0) returns non-negative length }
procedure TestErrorMessageZero;
var
  LBuf: array[0..255] of AnsiChar;
  LRet: Int32;
begin
  LRet := platform_error_message(0, @LBuf[0], 256);
  Check(LRet >= 0, 'error_message(0) returns >= 0');
end;

{ 2. Error message for ENOENT returns non-negative length }
procedure TestErrorMessageENOENT;
var
  LBuf: array[0..255] of AnsiChar;
  LRet: Int32;
begin
  LRet := platform_error_message(PLATFORM_ERR_ENOENT, @LBuf[0], 256);
  Check(LRet >= 0, 'error_message(ENOENT) returns >= 0');
  Check(LBuf[0] <> #0, 'message not empty');
end;

{ 3. Error category classification }
procedure TestErrorCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_ENOENT) = TErrorCategory.ecNotFound,
    'ENOENT is not-found category');
  Check(platform_error_category(PLATFORM_ERR_INVALID) = TErrorCategory.ecInvalidArgument,
    'INVALID is invalid-argument category');
end;

{ 4. Error message with small buffer is null-terminated }
procedure TestErrorMessageSmallBuf;
var
  LBuf: array[0..3] of AnsiChar;
  LRet: Int32;
begin
  LRet := platform_error_message(PLATFORM_ERR_ENOENT, @LBuf[0], 4);
  Check(LRet >= 0, 'small buffer does not crash');
  Check(LBuf[3] = #0, 'null terminated');
end;

{ 5. All PLATFORM_ERR_* constants are non-zero }
procedure TestErrConstantsNonZero;
begin
  Check(PLATFORM_ERR_EEXIST <> 0, 'EEXIST != 0');
  Check(PLATFORM_ERR_ENOENT <> 0, 'ENOENT != 0');
  Check(PLATFORM_ERR_ENOTDIR <> 0, 'ENOTDIR != 0');
  Check(PLATFORM_ERR_AGAIN <> 0, 'AGAIN != 0');
  Check(PLATFORM_ERR_BUSY <> 0, 'BUSY != 0');
  Check(PLATFORM_ERR_BADF <> 0, 'BADF != 0');
  Check(PLATFORM_ERR_INVALID <> 0, 'INVALID != 0');
  Check(PLATFORM_ERR_UNSUPPORTED <> 0, 'UNSUPPORTED != 0');
  Check(PLATFORM_ERR_TIMEOUT <> 0, 'TIMEOUT != 0');
end;

{ 6. Error message for invalid argument }
procedure TestErrorMessageInvalid;
var
  LBuf: array[0..255] of AnsiChar;
  LRet: Int32;
begin
  LRet := platform_error_message(PLATFORM_ERR_INVALID, @LBuf[0], 256);
  Check(LRet >= 0, 'error_message(INVALID) returns >= 0');
  Check(LBuf[0] <> #0, 'message not empty');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.error.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('error message for zero code', @TestErrorMessageZero);
  T.Test('error message for ENOENT', @TestErrorMessageENOENT);
  T.Test('error category classification', @TestErrorCategory);
  T.Test('error message small buffer', @TestErrorMessageSmallBuf);
  T.Test('PLATFORM_ERR constants non-zero', @TestErrConstantsNonZero);
  T.Test('error message for INVALID', @TestErrorMessageInvalid);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.
