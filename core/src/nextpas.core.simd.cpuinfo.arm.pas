unit nextpas.core.simd.cpuinfo.arm;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

{$IFDEF SIMD_ARM_AVAILABLE}

uses
  nextpas.core.simd.cpuinfo.base;

type
  // ARM processor information structure
  TARMProcessorInfo = record
    Architecture: string;
    InstructionSet: string;
    CoreType: string;
  end;

// === ARM CPU Detection Interface ===

// Detect all ARM features
function DetectARMFeatures: TARMFeatures;

// Detect ARM vendor and model information
procedure DetectARMVendorAndModel(var cpuInfo: TCPUInfo);

// Check specific ARM feature availability
function IsNEONAvailable: Boolean;
function IsAdvSIMDAvailable: Boolean;
function IsSVEAvailable: Boolean;
function IsSVE2Available: Boolean;

// Get ARM processor information
function GetARMProcessorInfo: TARMProcessorInfo;

{$IFDEF UNIX}
// Linux-specific functions
function ReadProcCpuInfoSafe: string;
function ParseARMFeaturesFromCpuInfo(const cpuInfo: string): TARMFeatures;
function ParseARMVendorFromCpuInfo(const cpuInfo: string; var vendor, model: string): Boolean;
function ParseARMProcessorInfoFromCpuInfo(const aCpuInfo: string;
  out aInstructionSet, aCoreType: string): Boolean;
// Merge Linux HWCAP/HWCAP2 evidence into feature flags (no-op on non-Linux UNIX).
procedure MergeARMFeaturesFromLinuxHWCAP(var aFeatures: TARMFeatures;
  const aHWCAP, aHWCAP2: QWord);
{$ENDIF}

implementation

{$IFDEF UNIX}
uses
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;
{$ENDIF}

{$I nextpas.core.simd.cpuinfo.helpers.inc}

{$IFDEF UNIX}
function PlatformFileExists(const APath: string): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_stat(PAnsiChar(APath), LStat) = 0;
end;
{$ENDIF}

// === Linux /proc/cpuinfo Parsing ===

{$IFDEF UNIX}
function ReadProcCpuInfoSafe: string;
var
  f: TextFile;
  line: string;
  cpuText: string;
  fileOpened: Boolean;
begin
  cpuText := '';
  fileOpened := False;
  
  try
    if PlatformFileExists('/proc/cpuinfo') then
    begin
      AssignFile(f, '/proc/cpuinfo');
      Reset(f);
      fileOpened := True;
      
      while not EOF(f) do
      begin
        ReadLn(f, line);
        cpuText := cpuText + line + LineEnding;
      end;
    end;
  except
    // Ignore errors, return empty string
    cpuText := '';
  end;
  
  // Ensure file is closed even if exception occurs
  if fileOpened then
  begin
    try
      CloseFile(f);
    except
      // Ignore close errors
    end;
  end;
  
  Result := cpuText;
end;

{$IFDEF LINUX}
const
  LINUX_AUXV_AT_NULL   = 0;
  LINUX_AUXV_AT_HWCAP  = 16;
  LINUX_AUXV_AT_HWCAP2 = 26;

type
  TLinuxAuxvEntry = packed record
    Tag: NativeUInt;
    Value: NativeUInt;
  end;

function TryReadLinuxAuxvHWCAP(out aHWCAP, aHWCAP2: QWord): Boolean;
var
  LHandle: TPlatformFileHandle;
  LEntry: TLinuxAuxvEntry;
  LReadBytes: QWord;
begin
  Result := False;
  aHWCAP := 0;
  aHWCAP2 := 0;

  if platform_file_open('/proc/self/auxv', fomReadOnly, fcmOpenExisting, LHandle) <> 0 then
    Exit;
  try
    while True do
    begin
      if platform_file_read(LHandle, @LEntry, SizeOf(LEntry), LReadBytes) <> 0 then
        Break;
      if LReadBytes <> SizeOf(LEntry) then
        Break;
      if LEntry.Tag = LINUX_AUXV_AT_NULL then
        Break;

      if LEntry.Tag = LINUX_AUXV_AT_HWCAP then
      begin
        aHWCAP := QWord(LEntry.Value);
        Result := True;
      end
      else if LEntry.Tag = LINUX_AUXV_AT_HWCAP2 then
      begin
        aHWCAP2 := QWord(LEntry.Value);
        Result := True;
      end;
    end;
  finally
    platform_file_close(LHandle);
  end;
end;
{$ENDIF}

procedure MergeARMFeaturesFromLinuxHWCAP(var aFeatures: TARMFeatures;
  const aHWCAP, aHWCAP2: QWord);
{$IFDEF LINUX}
const
  {$IFDEF CPUAARCH64}
  // AArch64 HWCAP bits (linux uapi asm/hwcap.h).
  ARM64_HWCAP_FP    = QWord(1) shl 0;
  ARM64_HWCAP_ASIMD = QWord(1) shl 1;
  ARM64_HWCAP_AES   = QWord(1) shl 3;
  ARM64_HWCAP_PMULL = QWord(1) shl 4;
  ARM64_HWCAP_SHA1  = QWord(1) shl 5;
  ARM64_HWCAP_SHA2  = QWord(1) shl 6;
  ARM64_HWCAP_SVE   = QWord(1) shl 22;
  ARM64_HWCAP2_SVE2 = QWord(1) shl 1;
  {$ELSE}
  // ARM32 HWCAP/HWCAP2 bits (linux uapi asm/hwcap.h).
  ARM_HWCAP_VFP    = QWord(1) shl 6;
  ARM_HWCAP_NEON   = QWord(1) shl 12;
  ARM_HWCAP_VFPV3  = QWord(1) shl 13;
  ARM_HWCAP_VFPV4  = QWord(1) shl 16;
  ARM_HWCAP2_AES   = QWord(1) shl 0;
  ARM_HWCAP2_PMULL = QWord(1) shl 1;
  ARM_HWCAP2_SHA1  = QWord(1) shl 2;
  ARM_HWCAP2_SHA2  = QWord(1) shl 3;
  {$ENDIF}
{$ENDIF}
begin
  {$IFDEF LINUX}
  {$IFDEF CPUAARCH64}
  if (aHWCAP and ARM64_HWCAP_FP) <> 0 then
    aFeatures.HasFP := True;
  if (aHWCAP and ARM64_HWCAP_ASIMD) <> 0 then
  begin
    aFeatures.HasNEON := True;
    aFeatures.HasAdvSIMD := True;
  end;
  if (aHWCAP and ARM64_HWCAP_SVE) <> 0 then
    aFeatures.HasSVE := True;
  if (aHWCAP2 and ARM64_HWCAP2_SVE2) <> 0 then
  begin
    aFeatures.HasSVE := True;
    aFeatures.HasSVE2 := True;
  end;
  if (aHWCAP and (ARM64_HWCAP_AES or ARM64_HWCAP_PMULL or ARM64_HWCAP_SHA1 or ARM64_HWCAP_SHA2)) <> 0 then
    aFeatures.HasCrypto := True;
  {$ELSE}
  if (aHWCAP and (ARM_HWCAP_VFP or ARM_HWCAP_VFPV3 or ARM_HWCAP_VFPV4)) <> 0 then
    aFeatures.HasFP := True;
  if (aHWCAP and ARM_HWCAP_NEON) <> 0 then
  begin
    aFeatures.HasNEON := True;
    aFeatures.HasAdvSIMD := True;
  end;
  if (aHWCAP2 and (ARM_HWCAP2_AES or ARM_HWCAP2_PMULL or ARM_HWCAP2_SHA1 or ARM_HWCAP2_SHA2)) <> 0 then
    aFeatures.HasCrypto := True;
  {$ENDIF}
  {$ELSE}
  // Non-Linux UNIX does not expose a stable HWCAP source in this module.
  if (aHWCAP <> 0) or (aHWCAP2 <> 0) then
    ;
  {$ENDIF}
end;

function NormalizeARMToken(const aToken: string): string;
begin
  Result := LowerCase(Trim(aToken));
  while (Result <> '') and not (Result[1] in ['a'..'z', '0'..'9']) do
    Delete(Result, 1, 1);
  while (Result <> '') and not (Result[Length(Result)] in ['a'..'z', '0'..'9']) do
    Delete(Result, Length(Result), 1);
end;

function TryParseARMKeyValueLine(const aLine: string; out aKey, aValue: string): Boolean;
var
  LLine: string;
  LColonPos: Integer;
  LEqualPos: Integer;
  LSepPos: Integer;
begin
  Result := False;
  aKey := '';
  aValue := '';

  LLine := Trim(aLine);
  if LLine = '' then
    Exit;

  LColonPos := Pos(':', LLine);
  LEqualPos := Pos('=', LLine);
  if (LColonPos > 0) and ((LEqualPos = 0) or (LColonPos < LEqualPos)) then
    LSepPos := LColonPos
  else
    LSepPos := LEqualPos;

  if LSepPos <= 0 then
    Exit;

  aKey := LowerCase(Trim(Copy(LLine, 1, LSepPos - 1)));
  aValue := Trim(Copy(LLine, LSepPos + 1, MaxInt));
  Result := (aKey <> '') and (aValue <> '');
end;

function IsARMFeatureKey(const aKey: string): Boolean;
var
  LKey: string;
begin
  LKey := LowerCase(Trim(aKey));
  Result := (LKey = 'feature') or
            (LKey = 'features') or
            (LKey = 'feature(s)') or
            (LKey = 'flags') or
            (LKey = 'cpu feature') or
            (LKey = 'cpu features') or
            (LKey = 'cpu feature(s)') or
            (LKey = 'extension') or
            (LKey = 'extensions') or
            (LKey = 'extension(s)') or
            (LKey = 'cpu extension') or
            (LKey = 'cpu extensions') or
            (LKey = 'cpu extension(s)') or
            (LKey = 'isa') or
            (LKey = 'isa feature') or
            (LKey = 'isa features') or
            (LKey = 'isa feature(s)') or
            (LKey = 'isa extension') or
            (LKey = 'isa extensions') or
            (LKey = 'isa extension(s)') or
            (LKey = 'isa_ext') or
            (LKey = 'isaext');
end;

function IsARMFallbackFeatureLikeKey(const aKey: string): Boolean;
var
  LKey: string;
begin
  LKey := LowerCase(Trim(aKey));
  Result := IsARMFeatureKey(LKey) or
            (LKey = 'cap') or
            (LKey = 'caps') or
            (LKey = 'hwcap') or
            (LKey = 'hwcap2') or
            (LKey = 'capability') or
            (LKey = 'capabilities') or
            (LKey = 'cpu capability') or
            (LKey = 'cpu capabilities') or
            (LKey = 'isa capability') or
            (LKey = 'isa capabilities') or
            (Pos('feature', LKey) > 0) or
            (Pos('flag', LKey) > 0) or
            (Pos('extension', LKey) > 0);
end;

procedure MarkARMFeatureByToken(var aFeatures: TARMFeatures; const aToken: string);
var
  LToken: string;

  function IsARMSHAToken(const aValue: string): Boolean; inline;
  begin
    // Deterministic SHA token whitelist: avoid prefix-based false positives
    // like "sha256sum" or "sha3extra".
    Result := (aValue = 'sha') or
              (aValue = 'sha1') or
              (aValue = 'sha2') or
              (aValue = 'sha3') or
              (aValue = 'sha256') or
              (aValue = 'sha512');
  end;

  function HasNumericSuffix(const aValue: string; const aPrefixLength: Integer): Boolean; inline;
  var
    LIndex: Integer;
  begin
    if Length(aValue) = aPrefixLength then
      Exit(True);

    for LIndex := aPrefixLength + 1 to Length(aValue) do
      if not (aValue[LIndex] in ['0'..'9']) then
        Exit(False);
    Result := True;
  end;

  function IsARMAESToken(const aValue: string): Boolean; inline;
  var
    LSuffix: string;
  begin
    Result := False;
    if Copy(aValue, 1, 3) <> 'aes' then
      Exit;

    if Length(aValue) = 3 then
      Exit(True);

    LSuffix := Copy(aValue, 4, MaxInt);
    if (LSuffix = 'ce') or (LSuffix = 'd') or
       (LSuffix = 'mc') or (LSuffix = 'imc') then
      Exit(True);

    Result := HasNumericSuffix(aValue, 3);
  end;

  function IsARMPMULLToken(const aValue: string): Boolean; inline;
  begin
    if Copy(aValue, 1, 5) <> 'pmull' then
      Exit(False);
    Result := HasNumericSuffix(aValue, 5);
  end;
begin
  LToken := NormalizeARMToken(aToken);
  if LToken = '' then
    Exit;

  if (LToken = 'neon') or (Copy(LToken, 1, 5) = 'asimd') then
  begin
    aFeatures.HasNEON := True;
    aFeatures.HasAdvSIMD := True;
  end;

  if (LToken = 'fp') or (LToken = 'fphp') or (LToken = 'fp16') or (LToken = 'asimdhp') or
     (Copy(LToken, 1, 3) = 'vfp') then
    aFeatures.HasFP := True;

  if Copy(LToken, 1, 4) = 'sve2' then
  begin
    aFeatures.HasSVE := True;
    aFeatures.HasSVE2 := True;
  end
  else if Copy(LToken, 1, 3) = 'sve' then
    aFeatures.HasSVE := True;

  if IsARMAESToken(LToken) or
     IsARMPMULLToken(LToken) or
     IsARMSHAToken(LToken) or
     (LToken = 'sm3') or (LToken = 'sm4') then
    aFeatures.HasCrypto := True;
end;

procedure ParseARMFeatureValue(var aFeatures: TARMFeatures; const aValue: string);
var
  LText: string;
  LStart: Integer;
  LPos: Integer;
  LToken: string;
begin
  LText := LowerCase(Trim(aValue));
  if LText = '' then
    Exit;

  LStart := 1;
  while LStart <= Length(LText) do
  begin
    while (LStart <= Length(LText)) and (LText[LStart] in [' ', #9, #10, #13, ',', ';', '|', '+', '/']) do
      Inc(LStart);
    if LStart > Length(LText) then
      Break;

    LPos := LStart;
    while (LPos <= Length(LText)) and not (LText[LPos] in [' ', #9, #10, #13, ',', ';', '|', '+', '/']) do
      Inc(LPos);

    LToken := Copy(LText, LStart, LPos - LStart);
    MarkARMFeatureByToken(aFeatures, LToken);
    LStart := LPos + 1;
  end;
end;

function ParseARMFeaturesFromCpuInfo(const cpuInfo: string): TARMFeatures;
var
  LScanPos: Integer;
  LNextPos: Integer;
  LLine: string;
  LKey: string;
  LValue: string;
  LFoundFeatureLine: Boolean;
begin
  Result := Default(TARMFeatures);
  
  if cpuInfo = '' then
    Exit;

  LFoundFeatureLine := False;
  LScanPos := 1;
  while LScanPos <= Length(cpuInfo) do
  begin
    LNextPos := PosEx(LineEnding, cpuInfo, LScanPos);
    if LNextPos = 0 then
      LNextPos := Length(cpuInfo) + 1;

    LLine := Trim(Copy(cpuInfo, LScanPos, LNextPos - LScanPos));
    LScanPos := LNextPos + 1;

    if not TryParseARMKeyValueLine(LLine, LKey, LValue) then
      Continue;
    if not IsARMFeatureKey(LKey) then
      Continue;

    ParseARMFeatureValue(Result, LValue);
    LFoundFeatureLine := True;
  end;

  // Best-effort fallback for unusual cpuinfo formats without explicit feature keys.
  // Only parse no-key-value lines or feature-like key-value lines to avoid
  // inferring features from identity fields such as model/hardware.
  if not LFoundFeatureLine then
  begin
    LScanPos := 1;
    while LScanPos <= Length(cpuInfo) do
    begin
      LNextPos := PosEx(LineEnding, cpuInfo, LScanPos);
      if LNextPos = 0 then
        LNextPos := Length(cpuInfo) + 1;

      LLine := Trim(Copy(cpuInfo, LScanPos, LNextPos - LScanPos));
      LScanPos := LNextPos + 1;
      if LLine = '' then
        Continue;

      if TryParseARMKeyValueLine(LLine, LKey, LValue) then
      begin
        if not IsARMFallbackFeatureLikeKey(LKey) then
          Continue;
        ParseARMFeatureValue(Result, LValue);
        Continue;
      end;

      ParseARMFeatureValue(Result, LLine);
    end;
  end;
end;

function NormalizeARMFieldValue(const aValue: string): string;
begin
  Result := Trim(aValue);
  if Result = '' then
    Exit;

  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Trim(Copy(Result, 2, Length(Result) - 2));
  if (Length(Result) >= 2) and (Result[1] = '''') and (Result[Length(Result)] = '''') then
    Result := Trim(Copy(Result, 2, Length(Result) - 2));

  Result := CollapseSpaces(Result);
end;

function IsNumericIndexValue(const aValue: string): Boolean;
var
  LText: string;
  LIndex: Integer;
begin
  LText := Trim(aValue);
  if LText = '' then
    Exit(False);

  if (Length(LText) > 2) and (LText[1] = '0') and ((LText[2] = 'x') or (LText[2] = 'X')) then
  begin
    for LIndex := 3 to Length(LText) do
      if not (LText[LIndex] in ['0'..'9', 'a'..'f', 'A'..'F']) then
        Exit(False);
    Exit(True);
  end;

  if LText[1] = '$' then
  begin
    if Length(LText) = 1 then
      Exit(False);
    for LIndex := 2 to Length(LText) do
      if not (LText[LIndex] in ['0'..'9', 'a'..'f', 'A'..'F']) then
        Exit(False);
    Exit(True);
  end;

  for LIndex := 1 to Length(LText) do
    if not (LText[LIndex] in ['0'..'9']) then
      Exit(False);

  Result := True;
end;

procedure PromoteIdentityCandidate(var aTarget: string; var aPriority: Integer;
  const aCandidate: string; const aCandidatePriority: Integer);
begin
  if (aCandidate = '') or (aCandidatePriority < aPriority) then
    Exit;
  if (aCandidatePriority = aPriority) and (aTarget <> '') then
    Exit;

  aTarget := aCandidate;
  aPriority := aCandidatePriority;
end;

{$IFDEF LINUX}
function ReadARMDeviceTreeTextFromPaths(const aPaths: array of string; out aText: string): Boolean;
var
  LPath: string;
  LHandle: TPlatformFileHandle;
  LStat: TPlatformFileStat;
  LRaw: RawByteString;
  LIndex: Integer;
  LRead: QWord;
begin
  Result := False;
  aText := '';

  for LPath in aPaths do
  begin
    if platform_file_stat(PAnsiChar(LPath), LStat) <> 0 then
      Continue;

    if platform_file_open(PAnsiChar(LPath), fomReadOnly, fcmOpenExisting, LHandle) <> 0 then
      Continue;
    try
      SetLength(LRaw, LStat.Size);
      if Length(LRaw) > 0 then
      begin
        if platform_file_read(LHandle, @LRaw[1], Length(LRaw), LRead) <> 0 then
          LRead := 0;
        if LRead < QWord(Length(LRaw)) then
          SetLength(LRaw, Integer(LRead));
      end;
    finally
      platform_file_close(LHandle);
    end;

    if LRaw = '' then
      Continue;

    for LIndex := 1 to Length(LRaw) do
    begin
      if LRaw[LIndex] = #0 then
        LRaw[LIndex] := ' ';
    end;

    aText := NormalizeARMFieldValue(LRaw);
    if aText <> '' then
      Exit(True);
  end;
end;

function ParseARMIdentityFromCompatible(const aCompatible: string; out aVendor, aModel: string): Boolean;
var
  LText: string;
  LTokenEnd: Integer;
  LPrimary: string;
  LCommaPos: Integer;
begin
  aVendor := '';
  aModel := '';
  Result := False;

  LText := NormalizeARMFieldValue(aCompatible);
  if LText = '' then
    Exit;

  LTokenEnd := 1;
  while (LTokenEnd <= Length(LText)) and not (LText[LTokenEnd] in [' ', #9]) do
    Inc(LTokenEnd);

  LPrimary := Trim(Copy(LText, 1, LTokenEnd - 1));
  if LPrimary = '' then
    Exit;

  aModel := LPrimary;
  LCommaPos := Pos(',', LPrimary);
  if LCommaPos > 1 then
    aVendor := Copy(LPrimary, 1, LCommaPos - 1);

  Result := (aVendor <> '') or (aModel <> '');
end;

function ReadARMIdentityFromDeviceTree(out aVendor, aModel: string): Boolean;
const
  MODEL_PATHS: array[0..1] of string = (
    '/sys/firmware/devicetree/base/model',
    '/proc/device-tree/model'
  );
  COMPATIBLE_PATHS: array[0..1] of string = (
    '/sys/firmware/devicetree/base/compatible',
    '/proc/device-tree/compatible'
  );
var
  LModelText: string;
  LCompatibleText: string;
  LVendorFromCompat: string;
  LModelFromCompat: string;
begin
  aVendor := '';
  aModel := '';
  Result := False;
  LVendorFromCompat := '';
  LModelFromCompat := '';

  if ReadARMDeviceTreeTextFromPaths(MODEL_PATHS, LModelText) then
    aModel := NormalizeARMFieldValue(LModelText);

  if ReadARMDeviceTreeTextFromPaths(COMPATIBLE_PATHS, LCompatibleText) then
    ParseARMIdentityFromCompatible(LCompatibleText, LVendorFromCompat, LModelFromCompat);

  if (aVendor = '') and (LVendorFromCompat <> '') then
    aVendor := LVendorFromCompat;
  if (aModel = '') and (LModelFromCompat <> '') then
    aModel := LModelFromCompat;

  Result := (aVendor <> '') or (aModel <> '');
end;
{$ENDIF}

function ParseARMVendorFromCpuInfo(const cpuInfo: string; var vendor, model: string): Boolean;
var
  LScanPos: Integer;
  LNextPos: Integer;
  LLine: string;
  LKey: string;
  LValue: string;
  LVendorCandidate: string;
  LModelCandidate: string;
  LVendorPriority: Integer;
  LModelPriority: Integer;
begin
  Result := False;
  vendor := '';
  model := '';
  LVendorCandidate := '';
  LModelCandidate := '';
  LVendorPriority := 0;
  LModelPriority := 0;
  
  if cpuInfo = '' then
    Exit;
    
  LScanPos := 1;
  while LScanPos <= Length(cpuInfo) do
  begin
    // Find next line (Pos does not support an offset; use PosEx)
    LNextPos := PosEx(LineEnding, cpuInfo, LScanPos);
    if LNextPos = 0 then
      LNextPos := Length(cpuInfo) + 1;
      
    LLine := Trim(Copy(cpuInfo, LScanPos, LNextPos - LScanPos));
    LScanPos := LNextPos + 1;
    
    if not TryParseARMKeyValueLine(LLine, LKey, LValue) then
      Continue;
    LValue := NormalizeARMFieldValue(LValue);
    if LValue = '' then
      Continue;

    if (LKey = 'cpu implementer') or (LKey = 'implementer') or (LKey = 'cpu vendor') or
       (LKey = 'vendor') or (LKey = 'vendor_id') then
    begin
      PromoteIdentityCandidate(LVendorCandidate, LVendorPriority, LValue, 30);
    end
    else if (LKey = 'hardware') or (LKey = 'machine') or (LKey = 'platform') or
            (LKey = 'soc') then
    begin
      PromoteIdentityCandidate(LVendorCandidate, LVendorPriority, LValue, 20);
    end
    else if (LKey = 'model name') or (LKey = 'cpu model') or (LKey = 'uarch') or
            (LKey = 'core name') then
    begin
      PromoteIdentityCandidate(LModelCandidate, LModelPriority, LValue, 30);
    end
    else if (LKey = 'cpu part') or (LKey = 'model') then
    begin
      PromoteIdentityCandidate(LModelCandidate, LModelPriority, LValue, 25);
    end
    else if (LKey = 'processor') and not IsNumericIndexValue(LValue) then
    begin
      // processor: 0/1/... is usually logical core index, not model identity.
      PromoteIdentityCandidate(LModelCandidate, LModelPriority, LValue, 10);
    end;
  end;

  vendor := LVendorCandidate;
  model := LModelCandidate;
  Result := (vendor <> '') or (model <> '');
end;

function CanonicalARMInstructionSetFromVersion(const aVersion: Integer): string;
begin
  Result := '';
  if aVersion <= 0 then
    Exit;

  if aVersion >= 7 then
    Result := 'ARMv' + IntToStr(aVersion) + '-A'
  else
    Result := 'ARMv' + IntToStr(aVersion);
end;

function IsAlphaNumericARMChar(const aChar: Char): Boolean; inline;
begin
  Result := (aChar in ['a'..'z']) or (aChar in ['A'..'Z']) or (aChar in ['0'..'9']);
end;

function TryExtractARMVersionFromText(const aText: string; out aVersion: Integer): Boolean;
var
  LText: string;
  LIndex: Integer;
  LStart: Integer;
  LDigits: string;
  LCode: Integer;
  LValue: Integer;
  LBest: Integer;
begin
  Result := False;
  aVersion := 0;
  LText := LowerCase(Trim(aText));
  if LText = '' then
    Exit;

  LBest := 0;
  LIndex := 1;
  while LIndex <= Length(LText) do
  begin
    LStart := 0;

    if (LIndex + 3 <= Length(LText)) and (Copy(LText, LIndex, 4) = 'armv') then
      LStart := LIndex + 4
    else if (LText[LIndex] = 'v') and
            ((LIndex = 1) or not IsAlphaNumericARMChar(LText[LIndex - 1])) then
      LStart := LIndex + 1;

    if (LStart > 0) and (LStart <= Length(LText)) and (LText[LStart] in ['0'..'9']) then
    begin
      LDigits := '';
      while (LStart <= Length(LText)) and (LText[LStart] in ['0'..'9']) do
      begin
        LDigits := LDigits + LText[LStart];
        Inc(LStart);
      end;

      Val(LDigits, LValue, LCode);
      // Keep ISA detection conservative: filter out small incidental numbers
      // from uarch/model tokens (for example "N2", "v2") that are not ARM ISA levels.
      if (LCode = 0) and (LValue >= 6) and (LValue > LBest) then
        LBest := LValue;
    end;

    Inc(LIndex);
  end;

  if LBest > 0 then
  begin
    aVersion := LBest;
    Result := True;
  end;
end;

function DetectARMInstructionSetFromField(const aKey, aValue: string): string;
var
  LKey: string;
  LValue: string;
  LCode: Integer;
  LNumericVersion: Integer;
  LDetectedVersion: Integer;
begin
  Result := '';
  LKey := LowerCase(Trim(aKey));
  LValue := LowerCase(Trim(aValue));
  if LValue = '' then
    Exit;

  if (LKey = 'cpu architecture') or (LKey = 'architecture') or (LKey = 'arch') then
  begin
    Val(LValue, LNumericVersion, LCode);
    if (LCode = 0) and (LNumericVersion > 0) then
    begin
      Result := CanonicalARMInstructionSetFromVersion(LNumericVersion);
      Exit;
    end;
  end;

  if Pos('aarch64', LValue) > 0 then
  begin
    Result := 'ARMv8-A';
    Exit;
  end;
  if Pos('arm64', LValue) > 0 then
  begin
    Result := 'ARMv8-A';
    Exit;
  end;

  if TryExtractARMVersionFromText(LValue, LDetectedVersion) then
  begin
    Result := CanonicalARMInstructionSetFromVersion(LDetectedVersion);
    Exit;
  end;
end;

function IsARMProcessorISAKey(const aKey: string): Boolean;
var
  LKey: string;
begin
  LKey := LowerCase(Trim(aKey));
  Result := (LKey = 'isa') or
            (LKey = 'isa string') or
            (LKey = 'cpu architecture') or
            (LKey = 'architecture') or
            (LKey = 'arch') or
            (LKey = 'model name') or
            (LKey = 'cpu model');
end;

function IsARMProcessorCoreTypeKey(const aKey: string): Boolean;
var
  LKey: string;
begin
  LKey := LowerCase(Trim(aKey));
  Result := (LKey = 'model name') or
            (LKey = 'cpu model') or
            (LKey = 'uarch') or
            (LKey = 'microarchitecture') or
            (LKey = 'core name') or
            (LKey = 'processor');
end;

function DetectARMCoreTypeFromText(const aValue: string): string;
var
  LValue: string;
begin
  Result := '';
  LValue := LowerCase(Trim(aValue));
  if LValue = '' then
    Exit;

  if Pos('cortex-a', LValue) > 0 then
    Exit('Cortex-A');
  if Pos('cortex-r', LValue) > 0 then
    Exit('Cortex-R');
  if Pos('cortex-m', LValue) > 0 then
    Exit('Cortex-M');
  if Pos('neoverse', LValue) > 0 then
    Exit('Neoverse');
  if Pos('kryo', LValue) > 0 then
    Exit('Kryo');
end;

function ParseARMProcessorInfoFromCpuInfo(const aCpuInfo: string;
  out aInstructionSet, aCoreType: string): Boolean;
var
  LScanPos: Integer;
  LNextPos: Integer;
  LLine: string;
  LKey: string;
  LValue: string;
  LInstructionSetCandidate: string;
  LCoreTypeCandidate: string;
  LInstructionSetPriority: Integer;
  LCoreTypePriority: Integer;
  LInstructionSetDetected: string;
  LCoreTypeDetected: string;
  LKeyPriority: Integer;
begin
  aInstructionSet := '';
  aCoreType := '';
  Result := False;
  if aCpuInfo = '' then
    Exit;

  LInstructionSetCandidate := '';
  LCoreTypeCandidate := '';
  LInstructionSetPriority := 0;
  LCoreTypePriority := 0;

  LScanPos := 1;
  while LScanPos <= Length(aCpuInfo) do
  begin
    LNextPos := PosEx(LineEnding, aCpuInfo, LScanPos);
    if LNextPos = 0 then
      LNextPos := Length(aCpuInfo) + 1;

    LLine := Trim(Copy(aCpuInfo, LScanPos, LNextPos - LScanPos));
    LScanPos := LNextPos + 1;

    if not TryParseARMKeyValueLine(LLine, LKey, LValue) then
      Continue;
    LValue := NormalizeARMFieldValue(LValue);
    if LValue = '' then
      Continue;

    if IsARMProcessorISAKey(LKey) then
    begin
      LInstructionSetDetected := DetectARMInstructionSetFromField(LKey, LValue);
      if LInstructionSetDetected <> '' then
      begin
        if (LKey = 'isa') or (LKey = 'isa string') then
          LKeyPriority := 40
        else if (LKey = 'cpu architecture') or (LKey = 'architecture') or (LKey = 'arch') then
          LKeyPriority := 35
        else
          LKeyPriority := 20;
        PromoteIdentityCandidate(LInstructionSetCandidate, LInstructionSetPriority,
          LInstructionSetDetected, LKeyPriority);
      end;
    end;

    if IsARMProcessorCoreTypeKey(LKey) then
    begin
      if (LKey = 'processor') and IsNumericIndexValue(LValue) then
        Continue;

      LCoreTypeDetected := DetectARMCoreTypeFromText(LValue);
      if LCoreTypeDetected <> '' then
      begin
        if (LKey = 'model name') or (LKey = 'cpu model') or (LKey = 'uarch') then
          LKeyPriority := 30
        else if (LKey = 'microarchitecture') or (LKey = 'core name') then
          LKeyPriority := 25
        else
          LKeyPriority := 10;
        PromoteIdentityCandidate(LCoreTypeCandidate, LCoreTypePriority,
          LCoreTypeDetected, LKeyPriority);
      end;
    end;
  end;

  if LInstructionSetCandidate = '' then
    LInstructionSetCandidate := DetectARMInstructionSetFromField('fallback', aCpuInfo);
  if LCoreTypeCandidate = '' then
    LCoreTypeCandidate := DetectARMCoreTypeFromText(aCpuInfo);

  aInstructionSet := LInstructionSetCandidate;
  aCoreType := LCoreTypeCandidate;
  Result := (aInstructionSet <> '') or (aCoreType <> '');
end;
{$ENDIF} // UNIX

// === ARM Feature Detection ===

function DetectARMFeatures: TARMFeatures;
{$IFDEF UNIX}
var
  cpuInfoText: string;
  {$IFDEF LINUX}
  LAuxHWCAP: QWord;
  LAuxHWCAP2: QWord;
  {$ENDIF}
{$ENDIF}
begin
  Result := Default(TARMFeatures);
  
  try
    {$IFDEF CPUAARCH64}
    // On AArch64, NEON (Advanced SIMD) is mandatory per ARM architecture
    Result.HasNEON := True;
    Result.HasAdvSIMD := True;
    Result.HasFP := True;
    
    {$IFDEF UNIX}
    // Try to detect additional features from /proc/cpuinfo
    cpuInfoText := ReadProcCpuInfoSafe;
    if cpuInfoText <> '' then
    begin
      Result := ParseARMFeaturesFromCpuInfo(cpuInfoText);
      // Ensure mandatory features are still set
      Result.HasNEON := True;
      Result.HasAdvSIMD := True;
      Result.HasFP := True;
    end;
    {$ENDIF}
    
    {$ELSE} // 32-bit ARM
    
    {$IFDEF UNIX}
    // On 32-bit ARM, NEON is optional, check /proc/cpuinfo
    cpuInfoText := ReadProcCpuInfoSafe;
    if cpuInfoText <> '' then
      Result := ParseARMFeaturesFromCpuInfo(cpuInfoText);
    {$ELSE}
    // On other platforms, conservative defaults
    Result.HasNEON := False;
    Result.HasAdvSIMD := False;
    Result.HasFP := False;
    Result.HasSVE := False;
    Result.HasCrypto := False;
    {$ENDIF}
    
    {$ENDIF} // CPUAARCH64

    {$IFDEF LINUX}
    if TryReadLinuxAuxvHWCAP(LAuxHWCAP, LAuxHWCAP2) then
      MergeARMFeaturesFromLinuxHWCAP(Result, LAuxHWCAP, LAuxHWCAP2);
    {$ENDIF}
    
  except
    // If detection fails, use conservative defaults
    FillChar(Result, SizeOf(Result), 0);
    {$IFDEF CPUAARCH64}
    // Even on error, AArch64 guarantees these features
    Result.HasNEON := True;
    Result.HasAdvSIMD := True;
    Result.HasFP := True;
    {$ENDIF}
  end;
end;

procedure DetectARMVendorAndModel(var cpuInfo: TCPUInfo);
var
  vendor, model: string;
  LVendorLower: string;
{$IFDEF UNIX}
  cpuInfoText: string;
{$ENDIF}
{$IFDEF LINUX}
  LDeviceTreeVendor: string;
  LDeviceTreeModel: string;
{$ENDIF}
begin
  // Set default values
  cpuInfo.Vendor := 'ARM';
  cpuInfo.Model := 'Unknown ARM Processor';
  vendor := '';
  model := '';
  
  try
    {$IFDEF UNIX}
    // Try to get detailed info from /proc/cpuinfo
    cpuInfoText := ReadProcCpuInfoSafe;
    if cpuInfoText <> '' then
    begin
      if ParseARMVendorFromCpuInfo(cpuInfoText, vendor, model) then
      begin
        if vendor <> '' then
          cpuInfo.Vendor := vendor;
        if model <> '' then
          cpuInfo.Model := model;
      end;
    end;
    {$ENDIF}

    {$IFDEF LINUX}
    if (vendor = '') or (model = '') then
    begin
      ReadARMIdentityFromDeviceTree(LDeviceTreeVendor, LDeviceTreeModel);
      if (vendor = '') and (LDeviceTreeVendor <> '') then
        vendor := LDeviceTreeVendor;
      if (model = '') and (LDeviceTreeModel <> '') then
        model := LDeviceTreeModel;
    end;
    {$ENDIF}

    if vendor <> '' then
      cpuInfo.Vendor := vendor;
    if model <> '' then
      cpuInfo.Model := model;
    
    // Enhance vendor identification
    LVendorLower := LowerCase(cpuInfo.Vendor);
    if Pos('0x41', LVendorLower) > 0 then
      cpuInfo.Vendor := 'ARM'
    else if Pos('0x51', LVendorLower) > 0 then
      cpuInfo.Vendor := 'Qualcomm'
    else if Pos('0x53', LVendorLower) > 0 then
      cpuInfo.Vendor := 'Samsung'
    else if Pos('0x61', LVendorLower) > 0 then
      cpuInfo.Vendor := 'Apple';
      
  except
    // Keep default values on error
  end;
end;

// === Individual Feature Checks ===

function IsNEONAvailable: Boolean;
var
  features: TARMFeatures;
begin
  features := DetectARMFeatures;
  Result := features.HasNEON;
end;

function IsAdvSIMDAvailable: Boolean;
var
  features: TARMFeatures;
begin
  features := DetectARMFeatures;
  Result := features.HasAdvSIMD;
end;

function IsSVEAvailable: Boolean;
var
  features: TARMFeatures;
begin
  features := DetectARMFeatures;
  Result := features.HasSVE;
end;

function IsSVE2Available: Boolean;
var
  features: TARMFeatures;
begin
  features := DetectARMFeatures;
  Result := features.HasSVE2;
end;

// === ARM Processor Information ===

function GetARMProcessorInfo: TARMProcessorInfo;
{$IFDEF UNIX}
var
  cpuInfoText: string;
  LInstructionSetCandidate: string;
  LCoreTypeCandidate: string;
{$ENDIF}
begin
  Result := Default(TARMProcessorInfo);
  Result.CoreType := 'Unknown';
  
  try
    {$IFDEF CPUAARCH64}
    Result.Architecture := 'AArch64';
    Result.InstructionSet := 'ARMv8-A';
    {$ELSE}
    Result.Architecture := 'AArch32';
    Result.InstructionSet := 'ARMv7-A';
    {$ENDIF}
    
    {$IFDEF UNIX}
    cpuInfoText := ReadProcCpuInfoSafe;
    if cpuInfoText <> '' then
    begin
      LInstructionSetCandidate := '';
      LCoreTypeCandidate := '';
      ParseARMProcessorInfoFromCpuInfo(cpuInfoText, LInstructionSetCandidate, LCoreTypeCandidate);

      if LInstructionSetCandidate <> '' then
        Result.InstructionSet := LInstructionSetCandidate;
      if LCoreTypeCandidate <> '' then
        Result.CoreType := LCoreTypeCandidate;
    end;
    {$ENDIF}
    
  except
    // Use defaults on error
    Result.Architecture := 'Unknown';
    Result.InstructionSet := 'Unknown';
    Result.CoreType := 'Unknown';
  end;
end;

{$ELSE}

// === Stub implementations for non-ARM platforms ===

implementation

function DetectARMFeatures: TARMFeatures;
begin
  FillChar(Result, SizeOf(TARMFeatures), 0);
end;

procedure DetectARMVendorAndModel(var cpuInfo: TCPUInfo);
begin
  cpuInfo.Vendor := 'Non-ARM';
  cpuInfo.Model := 'Non-ARM Processor';
end;

function IsNEONAvailable: Boolean;
begin
  Result := False;
end;

function IsAdvSIMDAvailable: Boolean;
begin
  Result := False;
end;

function IsSVEAvailable: Boolean;
begin
  Result := False;
end;

function IsSVE2Available: Boolean;
begin
  Result := False;
end;

function GetARMProcessorInfo: TARMProcessorInfo;
begin
  Result := Default(TARMProcessorInfo);
  Result.Architecture := 'Non-ARM';
  Result.InstructionSet := 'Non-ARM';
  Result.CoreType := 'Non-ARM';
end;

{$IFDEF UNIX}
function ReadProcCpuInfoSafe: string;
begin
  Result := '';
end;

function ParseARMFeaturesFromCpuInfo(const cpuInfo: string): TARMFeatures;
begin
  FillChar(Result, SizeOf(TARMFeatures), 0);
end;

function ParseARMVendorFromCpuInfo(const cpuInfo: string; var vendor, model: string): Boolean;
begin
  vendor := '';
  model := '';
  Result := False;
end;

function ParseARMProcessorInfoFromCpuInfo(const aCpuInfo: string;
  out aInstructionSet, aCoreType: string): Boolean;
begin
  aInstructionSet := '';
  aCoreType := '';
  Result := False;
end;
{$ENDIF}

{$ENDIF} // SIMD_ARM_AVAILABLE

end.
