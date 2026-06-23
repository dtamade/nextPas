program test_mem_secure;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.testing,
  nextpas.core.mem.secure;

const
  PLATFORM_SECURE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.secure.pas';
  PLATFORM_SECURE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.secure.pas';
  MEM_SECURE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.secure.pas';
  MEM_SECURE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.secure.pas';
  MEM_SECURE_WINDOWS_COMPILE_GATE_FROM_TEST =
    '../test_mem_secure_windows_compile_gate/test_mem_secure_windows_compile_gate.lpr';
  MEM_SECURE_WINDOWS_COMPILE_GATE_FROM_ROOT =
    'core/tests/nextpas.core.mem/test_mem_secure_windows_compile_gate/test_mem_secure_windows_compile_gate.lpr';

var
  T: TTestRunner;

function ReadSourceText(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if Exists(APathFromTest) then
    Exit(APathFromTest);
  if Exists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckNotContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestSecureZeroMemoryNilAndZeroSize;
var
  LByte: Byte;
begin
  SecureZeroMemory(nil, 16);

  LByte := $A5;
  SecureZeroMemory(@LByte, 0);
  CheckEqual(Int64($A5), Int64(LByte), 'zero-size secure zero leaves buffer unchanged');
end;

procedure TestSecureZeroMemorySmallBuffers;
var
  LOne: Byte;
  LThree: array[0..2] of Byte;
  LGuarded: array[0..4] of Byte;
  LIndex: Integer;
begin
  LOne := $7F;
  SecureZeroMemory(@LOne, SizeOf(LOne));
  CheckEqual(Int64(0), Int64(LOne), 'single-byte secure zero');

  LThree[0] := $11;
  LThree[1] := $22;
  LThree[2] := $33;
  SecureZeroMemory(@LThree[0], SizeOf(LThree));
  for LIndex := Low(LThree) to High(LThree) do
    CheckEqual(Int64(0), Int64(LThree[LIndex]), 'three-byte secure zero');

  LGuarded[0] := $AA;
  LGuarded[1] := $11;
  LGuarded[2] := $22;
  LGuarded[3] := $33;
  LGuarded[4] := $BB;
  SecureZeroMemory(@LGuarded[1], 3);
  CheckEqual(Int64($AA), Int64(LGuarded[0]), 'leading guard unchanged');
  CheckEqual(Int64(0), Int64(LGuarded[1]), 'guarded byte 1 cleared');
  CheckEqual(Int64(0), Int64(LGuarded[2]), 'guarded byte 2 cleared');
  CheckEqual(Int64(0), Int64(LGuarded[3]), 'guarded byte 3 cleared');
  CheckEqual(Int64($BB), Int64(LGuarded[4]), 'trailing guard unchanged');
end;

procedure TestSecureZeroBytesClearsAndShrinks;
var
  LData: TBytes;
begin
  SetLength(LData, 3);
  LData[0] := $41;
  LData[1] := $42;
  LData[2] := $43;

  SecureZeroBytes(LData);
  CheckEqual(Int64(0), Int64(Length(LData)), 'secure zero bytes shrinks array');
end;

procedure TestSecureZeroStringClears;
var
  LText: AnsiString;
begin
  LText := 'secret';
  SecureZeroString(LText);
  CheckEqual('', LText, 'secure zero string clears value');
end;

procedure TestPlatformSecureIsDeprecatedWrapper;
var
  LSource: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    PLATFORM_SECURE_SOURCE_PATH_FROM_TEST,
    PLATFORM_SECURE_SOURCE_PATH_FROM_ROOT));
  CheckContains(LSource, 'nextpas.core.platform.memory',
    'platform.secure depends on platform.memory');
  CheckContains(LSource,
    'deprecated ''use platform_secure_zero_memory from nextpas.core.platform.memory''',
    'platform.secure marks legacy API deprecated');
  CheckContains(LSource, 'platform_secure_zero_memory(buffer, size);',
    'platform.secure forwards to platform.memory secure zero');
  CheckNotContains(LSource, 'fillchar(buffer^, size, 0);',
    'platform.secure no longer owns fallback implementation');
end;

procedure TestMemSecureDelegatesToPlatformMemory;
var
  LSource: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    MEM_SECURE_SOURCE_PATH_FROM_TEST,
    MEM_SECURE_SOURCE_PATH_FROM_ROOT));
  CheckContains(LSource, 'nextpas.core.platform.memory',
    'mem.secure uses platform.memory');
  CheckContains(LSource, 'platform_secure_zero_memory(buffer, size);',
    'mem.secure delegates to platform.memory secure zero');
  CheckNotContains(LSource, 'nextpas.core.platform.secure',
    'mem.secure no longer uses legacy platform.secure seam');
end;

procedure TestWindowsCompileGateUsesPlatformSecureWrapper;
var
  LSource: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    MEM_SECURE_WINDOWS_COMPILE_GATE_FROM_TEST,
    MEM_SECURE_WINDOWS_COMPILE_GATE_FROM_ROOT));
  CheckContains(LSource, 'nextpas.core.platform.secure',
    'windows compile gate imports platform.secure wrapper');
  CheckContains(LSource, 'platform_secure_zero(@lbyte, sizeof(lbyte));',
    'windows compile gate exercises deprecated platform.secure surface');
  CheckContains(LSource, 'securezeromemory(@lbyte, sizeof(lbyte));',
    'windows compile gate still compiles mem.secure surface');
  CheckNotContains(LSource, 'nextpas.core.platform.memory',
    'windows compile gate does not bypass wrapper owner surface');
  CheckNotContains(LSource, 'platform_secure_zero_memory(@lbyte, sizeof(lbyte));',
    'windows compile gate no longer calls owner seam directly');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.secure');
  T.Run('nil and zero-size memory', @TestSecureZeroMemoryNilAndZeroSize);
  T.Run('small buffers', @TestSecureZeroMemorySmallBuffers);
  T.Run('byte arrays', @TestSecureZeroBytesClearsAndShrinks);
  T.Run('strings', @TestSecureZeroStringClears);
  T.Run('platform.secure is deprecated wrapper', @TestPlatformSecureIsDeprecatedWrapper);
  T.Run('mem.secure delegates to platform.memory', @TestMemSecureDelegatesToPlatformMemory);
  T.Run('windows compile gate uses platform.secure wrapper',
    @TestWindowsCompileGateUsesPlatformSecureWrapper);
  T.Summary;
end.
