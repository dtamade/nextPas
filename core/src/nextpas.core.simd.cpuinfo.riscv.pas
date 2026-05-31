unit nextpas.core.simd.cpuinfo.riscv;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

{$IFDEF SIMD_RISCV_AVAILABLE}

uses
  nextpas.core.simd.cpuinfo.base;

type
  // RISC-V processor information structure
  TRISCVProcessorInfo = record
    Architecture: string;
    ISA: string;
    XLEN: Integer;
  end;

// === RISC-V Platform-specific CPU Detection ===

// Detect RISC-V features
function DetectRISCVFeatures: TRISCVFeatures;

// Detect RISC-V vendor and model
procedure DetectRISCVVendorAndModel(var cpuInfo: TCPUInfo);

// Get RISC-V processor info
function GetRISCVProcessorInfo: TRISCVProcessorInfo;

// Parse RISC-V features from /proc/cpuinfo (Linux)
function ParseRISCVFeaturesFromCpuInfo(const cpuInfo: string): TRISCVFeatures;
// Extract best ISA candidate from cpuinfo key-values and merge optional misa evidence.
// Returns True when ISA evidence is found (direct ISA string or synthesizable misa bitmask).
function ExtractBestRISCVISAFromCpuInfo(const aCpuInfo: string; out aISA: string;
  out aFeatures: TRISCVFeatures): Boolean;

// Parse RISC-V vendor/model identity candidates from /proc/cpuinfo.
// Returns True when at least one identity field is found.
function ParseRISCVVendorModelFromCpuInfo(const aCpuInfo: string; out aVendor, aModel: string): Boolean;
// Merge Linux HWCAP/HWCAP2 evidence into feature flags (no-op on non-Linux).
procedure MergeRISCVFeaturesFromLinuxHWCAP(var aFeatures: TRISCVFeatures;
  const aHWCAP, aHWCAP2: QWord);

{$ENDIF}

implementation

{$IFDEF SIMD_RISCV_AVAILABLE}

uses
  SysUtils,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

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
  LReadBytes: Int64;
begin
  Result := False;
  aHWCAP := 0;
  aHWCAP2 := 0;

  if platform_file_open('/proc/self/auxv', fomReadOnly, fcmOpenExisting, LHandle) <> 0 then
    Exit;
  try
    while True do
    begin
      LReadBytes := platform_file_read(LHandle, @LEntry, SizeOf(LEntry));
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

procedure MergeRISCVFeaturesFromLinuxHWCAP(var aFeatures: TRISCVFeatures;
  const aHWCAP, aHWCAP2: QWord);
{$IFDEF LINUX}
const
  RISCV_HWCAP_I = QWord(1) shl (Ord('I') - Ord('A'));
  RISCV_HWCAP_M = QWord(1) shl (Ord('M') - Ord('A'));
  RISCV_HWCAP_A = QWord(1) shl (Ord('A') - Ord('A'));
  RISCV_HWCAP_F = QWord(1) shl (Ord('F') - Ord('A'));
  RISCV_HWCAP_D = QWord(1) shl (Ord('D') - Ord('A'));
  RISCV_HWCAP_C = QWord(1) shl (Ord('C') - Ord('A'));
  RISCV_HWCAP_V = QWord(1) shl (Ord('V') - Ord('A'));
{$ENDIF}
begin
  {$IFDEF LINUX}
  // Keep raw auxv evidence for diagnostics and future deterministic HWCAP2 mapping.
  aFeatures.LinuxHWCAP := aFeatures.LinuxHWCAP or aHWCAP;
  aFeatures.LinuxHWCAP2 := aFeatures.LinuxHWCAP2 or aHWCAP2;

  if (aHWCAP and RISCV_HWCAP_I) <> 0 then
  begin
    {$IFDEF CPURISCV64}
    aFeatures.HasRV64I := True;
    {$ELSE}
    aFeatures.HasRV32I := True;
    {$ENDIF}
  end;

  if (aHWCAP and RISCV_HWCAP_M) <> 0 then
    aFeatures.HasM := True;
  if (aHWCAP and RISCV_HWCAP_A) <> 0 then
    aFeatures.HasA := True;
  if (aHWCAP and RISCV_HWCAP_F) <> 0 then
    aFeatures.HasF := True;
  if (aHWCAP and RISCV_HWCAP_D) <> 0 then
    aFeatures.HasD := True;
  if (aHWCAP and RISCV_HWCAP_C) <> 0 then
    aFeatures.HasC := True;
  if (aHWCAP and RISCV_HWCAP_V) <> 0 then
    aFeatures.HasV := True;

  if aHWCAP2 <> 0 then
  begin
    // HWCAP2 extension bits are currently not mapped into TRISCVFeatures.
  end;
  {$ELSE}
  if (aHWCAP <> 0) or (aHWCAP2 <> 0) then
    ;
  {$ENDIF}
end;

function NormalizeFieldValue(const aValue: string): string;
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

function NormalizeISAValue(const aValue: string): string;
begin
  Result := LowerCase(NormalizeFieldValue(aValue));
end;

{$IFDEF LINUX}
function ReadDeviceTreeTextFromPaths(const aPaths: array of string; out aText: string): Boolean;
var
  LPath: string;
  LHandle: TPlatformFileHandle;
  LStat: TPlatformFileStat;
  LRaw: RawByteString;
  LIndex: Integer;
  LRead: Int64;
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
        LRead := platform_file_read(LHandle, @LRaw[1], Length(LRaw));
        if LRead < Length(LRaw) then
          SetLength(LRaw, LRead);
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

    aText := NormalizeFieldValue(LRaw);
    if aText <> '' then
      Exit(True);
  end;
end;
{$ENDIF}

{$IFDEF LINUX}
function ReadRISCVISAFromCpuNodeDirectory(const aDirectory: string; out aISA: string): Boolean;
var
  LNodeRec: TSearchRec;
  LNodePath: string;
  LCandidatePaths: array[0..0] of string;
begin
  Result := False;
  aISA := '';

  if not DirectoryExists(aDirectory) then
    Exit;

  if FindFirst(aDirectory + '/cpu*', faDirectory, LNodeRec) <> 0 then
    Exit;
  try
    repeat
      if (LNodeRec.Name = '.') or (LNodeRec.Name = '..') then
        Continue;
      if (LNodeRec.Attr and faDirectory) = 0 then
        Continue;

      LNodePath := aDirectory + '/' + LNodeRec.Name + '/riscv,isa';
      LCandidatePaths[0] := LNodePath;
      if ReadDeviceTreeTextFromPaths(LCandidatePaths, aISA) then
      begin
        aISA := NormalizeISAValue(aISA);
        if aISA <> '' then
          Exit(True);
      end;
    until FindNext(LNodeRec) <> 0;
  finally
    FindClose(LNodeRec);
  end;
end;

function ReadRISCVISAFromDeviceTree(out aISA: string): Boolean;
const
  CANDIDATE_PATHS: array[0..3] of string = (
    '/sys/firmware/devicetree/base/cpus/cpu@0/riscv,isa',
    '/sys/firmware/devicetree/base/cpu@0/riscv,isa',
    '/sys/firmware/devicetree/base/riscv,isa',
    '/proc/device-tree/cpus/cpu@0/riscv,isa'
  );
begin
  if ReadRISCVISAFromCpuNodeDirectory('/sys/firmware/devicetree/base/cpus', aISA) then
    Exit(True);
  if ReadRISCVISAFromCpuNodeDirectory('/proc/device-tree/cpus', aISA) then
    Exit(True);
  if ReadRISCVISAFromCpuNodeDirectory('/sys/firmware/devicetree/base', aISA) then
    Exit(True);
  if ReadRISCVISAFromCpuNodeDirectory('/proc/device-tree', aISA) then
    Exit(True);

  Result := ReadDeviceTreeTextFromPaths(CANDIDATE_PATHS, aISA);
  if Result then
    aISA := NormalizeISAValue(aISA);
end;

function ParseRISCVIdentityFromCompatible(const aCompatible: string; out aVendor, aModel: string): Boolean;
var
  LText: string;
  LTokenEnd: Integer;
  LPrimary: string;
  LCommaPos: Integer;
begin
  aVendor := '';
  aModel := '';
  Result := False;

  LText := NormalizeFieldValue(aCompatible);
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

function ReadRISCVIdentityFromDeviceTree(out aVendor, aModel: string): Boolean;
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
  LVendorFromCompat := '';
  LModelFromCompat := '';
  Result := False;

  if ReadDeviceTreeTextFromPaths(MODEL_PATHS, LModelText) then
    aModel := NormalizeFieldValue(LModelText);

  if ReadDeviceTreeTextFromPaths(COMPATIBLE_PATHS, LCompatibleText) then
    ParseRISCVIdentityFromCompatible(LCompatibleText, LVendorFromCompat, LModelFromCompat);

  if (aVendor = '') and (LVendorFromCompat <> '') then
    aVendor := LVendorFromCompat;
  if (aModel = '') and (LModelFromCompat <> '') then
    aModel := LModelFromCompat;

  Result := (aVendor <> '') or (aModel <> '');
end;
{$ENDIF}

{$IFDEF UNIX}
function ReadProcCpuInfoContent(out aContent: string): Boolean;
var
  LFile: TextFile;
  LLine: string;
  LOpened: Boolean;
begin
  Result := False;
  aContent := '';

  if not FileExists('/proc/cpuinfo') then
    Exit;

  LOpened := False;
  AssignFile(LFile, '/proc/cpuinfo');
  try
    Reset(LFile);
    LOpened := True;

    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      aContent := aContent + LLine + LineEnding;
    end;

    Result := True;
  finally
    if LOpened then
      CloseFile(LFile);
  end;
end;
{$ENDIF}

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
  begin
    if not (LText[LIndex] in ['0'..'9']) then
      Exit(False);
  end;

  Result := True;
end;

function NormalizeToken(const aToken: string): string;
begin
  Result := LowerCase(Trim(aToken));

  while (Result <> '') and not (Result[1] in ['a'..'z', '0'..'9']) do
    Delete(Result, 1, 1);
  while (Result <> '') and not (Result[Length(Result)] in ['a'..'z', '0'..'9']) do
    Delete(Result, Length(Result), 1);
end;

function TryParseKeyValueLine(const aLine: string; out aKey, aValue: string): Boolean;
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

function ParseRISCVVendorModelFromCpuInfo(const aCpuInfo: string; out aVendor, aModel: string): Boolean;
var
  LLines: TStringList;
  LLine: string;
  LKey: string;
  LValue: string;
  LLineIndex: Integer;
  LVendorPriority: Integer;
  LModelPriority: Integer;
begin
  aVendor := '';
  aModel := '';
  LVendorPriority := 0;
  LModelPriority := 0;

  LLines := TStringList.Create;
  try
    LLines.Text := ReplaceChar(aCpuInfo, #13, #10);
    for LLineIndex := 0 to LLines.Count - 1 do
    begin
      LLine := Trim(LLines[LLineIndex]);
      if not TryParseKeyValueLine(LLine, LKey, LValue) then
        Continue;

      LValue := NormalizeFieldValue(LValue);
      if LValue = '' then
        Continue;

      if (LKey = 'vendor_id') or (LKey = 'vendor') or (LKey = 'riscv vendor') then
      begin
        PromoteIdentityCandidate(aVendor, LVendorPriority, LValue, 30);
        Continue;
      end;

      if (LKey = 'soc') or (LKey = 'machine') or (LKey = 'hardware') or (LKey = 'platform') then
      begin
        PromoteIdentityCandidate(aVendor, LVendorPriority, LValue, 20);
        Continue;
      end;

      if (LKey = 'model name') or (LKey = 'cpu model') or (LKey = 'uarch') or
         (LKey = 'core') or (LKey = 'core name') then
      begin
        PromoteIdentityCandidate(aModel, LModelPriority, LValue, 30);
        Continue;
      end;

      if (LKey = 'model') or (LKey = 'cpu') then
      begin
        PromoteIdentityCandidate(aModel, LModelPriority, LValue, 25);
        Continue;
      end;

      if (LKey = 'processor') and not IsNumericIndexValue(LValue) then
      begin
        // "processor : 0/1/..." is usually hart index, not a model string.
        PromoteIdentityCandidate(aModel, LModelPriority, LValue, 10);
        Continue;
      end;
    end;
  finally
    LLines.Free;
  end;

  Result := (aVendor <> '') or (aModel <> '');
end;

procedure SetFeatureByLetter(var aFeatures: TRISCVFeatures; const aLetter: Char);
begin
  case aLetter of
    'm': aFeatures.HasM := True;
    'a': aFeatures.HasA := True;
    'f': aFeatures.HasF := True;
    'd': aFeatures.HasD := True;
    'c': aFeatures.HasC := True;
    'v': aFeatures.HasV := True;
    'g':
      begin
        // g = imafd (base i is implied by rv32/rv64 and tracked separately).
        aFeatures.HasM := True;
        aFeatures.HasA := True;
        aFeatures.HasF := True;
        aFeatures.HasD := True;
      end;
  end;
end;

function IsVersionedSingleLetterToken(const aToken: string; const aLetter: Char): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if (aToken = '') or (aToken[1] <> aLetter) then
    Exit;

  if Length(aToken) = 1 then
    Exit(True);

  for LIndex := 2 to Length(aToken) do
    if not (aToken[LIndex] in ['0'..'9', 'p', '.']) then
      Exit(False);

  Result := True;
end;

procedure ParseRVToken(const aToken: string; var aFeatures: TRISCVFeatures);
var
  LIndex: Integer;
  LChar: Char;
begin
  if Copy(aToken, 1, 4) = 'rv64' then
  begin
    aFeatures.HasRV64I := True;
    LIndex := 5;
  end
  else if Copy(aToken, 1, 4) = 'rv32' then
  begin
    aFeatures.HasRV32I := True;
    LIndex := 5;
  end
  else
    // Deterministic rule:
    // - Only parse compact ISA tokens with explicit rv32/rv64 base.
    // - Ignore other rv* forms (for example profile IDs like rva23u64)
    //   to avoid inferring one-letter extensions from non-ISA profile text.
    Exit;

  while LIndex <= Length(aToken) do
  begin
    LChar := aToken[LIndex];
    if not (LChar in ['a'..'z']) then
      Break;

    SetFeatureByLetter(aFeatures, LChar);
    Inc(LIndex);

    // Skip optional version suffix (e.g. i2p1 / v1p0).
    while (LIndex <= Length(aToken)) and (aToken[LIndex] in ['0'..'9', 'p', '.']) do
      Inc(LIndex);

    // Multi-letter extension namespaces are not part of compact one-letter block.
    if (LIndex <= Length(aToken)) and (aToken[LIndex] in ['z', 'x', 's', 'h', '_']) then
      Break;
  end;
end;

procedure ParseISAToken(const aToken: string; var aFeatures: TRISCVFeatures);
var
  LToken: string;

  function HasAlphaNumericAt(const aValue: string; const aIndex: Integer): Boolean; inline;
  begin
    Result := (aIndex >= 1) and (aIndex <= Length(aValue)) and
      (aValue[aIndex] in ['a'..'z', '0'..'9']);
  end;
begin
  LToken := NormalizeToken(aToken);
  if LToken = '' then
    Exit;

  if Copy(LToken, 1, 2) = 'rv' then
  begin
    ParseRVToken(LToken, aFeatures);
    Exit;
  end;

  if IsVersionedSingleLetterToken(LToken, 'g') then
  begin
    SetFeatureByLetter(aFeatures, 'g');
    Exit;
  end;
  if IsVersionedSingleLetterToken(LToken, 'm') then
  begin
    aFeatures.HasM := True;
    Exit;
  end;
  if IsVersionedSingleLetterToken(LToken, 'a') then
  begin
    aFeatures.HasA := True;
    Exit;
  end;
  if IsVersionedSingleLetterToken(LToken, 'f') then
  begin
    aFeatures.HasF := True;
    Exit;
  end;
  if IsVersionedSingleLetterToken(LToken, 'd') then
  begin
    aFeatures.HasD := True;
    Exit;
  end;
  if IsVersionedSingleLetterToken(LToken, 'c') then
  begin
    aFeatures.HasC := True;
    Exit;
  end;
  if IsVersionedSingleLetterToken(LToken, 'v') then
  begin
    aFeatures.HasV := True;
    Exit;
  end;

  // Vector extension families.
  // - zve*/zvl* are explicit vector subsets/limits.
  // - zv* covers vector-crypto and other vector-prefixed extensions.
  // NOTE:
  // - Do not infer V from generic vendor-prefixed x* tokens (for example xventana...).
  //   Those tokens are vendor-defined and can be unrelated to vector ISA semantics.
  //   Keep detection conservative and rely on explicit V evidence:
  //   rv* compact block with "v", zv*/zve*/zvl* tokens, or misa/hwcap bits.
  // - z* vector namespace must look like a real extension token:
  //   zve<digits> / zvl<digits> / zv<alnum...>.
  if ((Copy(LToken, 1, 3) = 'zve') and (Length(LToken) > 3) and (LToken[4] in ['0'..'9'])) or
     ((Copy(LToken, 1, 3) = 'zvl') and (Length(LToken) > 3) and (LToken[4] in ['0'..'9'])) or
     ((Copy(LToken, 1, 2) = 'zv') and (Length(LToken) > 2) and
      (Copy(LToken, 1, 3) <> 'zve') and (Copy(LToken, 1, 3) <> 'zvl') and
      HasAlphaNumericAt(LToken, 3)) then
    aFeatures.HasV := True;
end;

procedure ParseISAString(const aISA: string; var aFeatures: TRISCVFeatures);
var
  LText: string;
  LStart: Integer;
  LPos: Integer;
  LToken: string;
begin
  LText := LowerCase(Trim(aISA));
  if LText = '' then
    Exit;

  LStart := 1;
  while LStart <= Length(LText) do
  begin
    while (LStart <= Length(LText)) and (LText[LStart] in [' ', #9, '_', ',', ';', '|', '+', '/']) do
      Inc(LStart);
    if LStart > Length(LText) then
      Break;

    LPos := LStart;
    while (LPos <= Length(LText)) and not (LText[LPos] in [' ', #9, '_', ',', ';', '|', '+', '/']) do
      Inc(LPos);

    LToken := Copy(LText, LStart, LPos - LStart);
    ParseISAToken(LToken, aFeatures);
    LStart := LPos + 1;
  end;
end;

function IsISAKey(const aKey: string): Boolean;
var
  LKey: string;
begin
  LKey := LowerCase(Trim(aKey));
  Result := (LKey = 'isa') or
            (LKey = 'isa string') or
            (LKey = 'isa extension') or
            (LKey = 'isa extensions') or
            (LKey = 'isa-extensions') or
            (LKey = 'isa ext') or
            (LKey = 'isa_ext') or
            (LKey = 'isa_extensions') or
            (LKey = 'isaext') or
            (LKey = 'march') or
            (LKey = 'riscv march') or
            (LKey = 'riscv,march') or
            (LKey = 'riscv,isa') or
            (LKey = 'riscv,isa extension') or
            (LKey = 'riscv,isa extensions') or
            (LKey = 'riscv isa') or
            (LKey = 'riscv_isa') or
            (LKey = 'riscv isa ext') or
            (LKey = 'riscv isa extension') or
            (LKey = 'riscv isa extensions') or
            (LKey = 'riscv_isa_ext') or
            (LKey = 'riscv_isa_extensions') or
            (LKey = 'riscv extensions') or
            (LKey = 'riscv extension') or
            (LKey = 'extensions') or
            (LKey = 'hart isa') or
            (LKey = 'uarch isa');
end;

function IsMISAKey(const aKey: string): Boolean;
var
  LKey: string;
begin
  LKey := LowerCase(Trim(aKey));
  Result := (LKey = 'misa') or
            (LKey = 'riscv,misa') or
            (LKey = 'riscv misa') or
            (LKey = 'csr misa') or
            (LKey = 'misa csr') or
            (LKey = 'misa register');
end;

function IsWeakRISCVISAKey(const aKey: string): Boolean;
var
  LKey: string;
begin
  LKey := LowerCase(Trim(aKey));
  Result := (LKey = 'extensions');
end;

function IsLikelyWeakKeyVersionedSingleLetterToken(const aToken: string;
  const aLetter: Char): Boolean;
var
  LToken: string;
  LVersionPart: string;
begin
  LToken := NormalizeToken(aToken);
  if (LToken = '') or (LToken[1] <> aLetter) then
    Exit(False);

  if Length(LToken) = 1 then
    Exit(True);

  // For weak keys (for example "extensions"), require explicit version markers
  // to avoid metadata-like tokens such as "a55" being treated as ISA extension A.
  LVersionPart := Copy(LToken, 2, MaxInt);
  if (Pos('p', LVersionPart) <= 0) and (Pos('.', LVersionPart) <= 0) then
    Exit(False);

  Result := IsVersionedSingleLetterToken(LToken, aLetter);
end;

function IsLikelyRISCVISAToken(const aToken: string): Boolean;
var
  LToken: string;
begin
  LToken := NormalizeToken(aToken);
  if LToken = '' then
    Exit(False);

  if (Copy(LToken, 1, 4) = 'rv64') or (Copy(LToken, 1, 4) = 'rv32') then
    Exit(True);

  if IsLikelyWeakKeyVersionedSingleLetterToken(LToken, 'i') or
     IsLikelyWeakKeyVersionedSingleLetterToken(LToken, 'g') or
     IsLikelyWeakKeyVersionedSingleLetterToken(LToken, 'm') or
     IsLikelyWeakKeyVersionedSingleLetterToken(LToken, 'a') or
     IsLikelyWeakKeyVersionedSingleLetterToken(LToken, 'f') or
     IsLikelyWeakKeyVersionedSingleLetterToken(LToken, 'd') or
     IsLikelyWeakKeyVersionedSingleLetterToken(LToken, 'c') or
     IsLikelyWeakKeyVersionedSingleLetterToken(LToken, 'v') then
    Exit(True);

  if (Length(LToken) > 1) and
     (LToken[1] in ['z', 'x', 's', 'h']) and
     (LToken[2] in ['a'..'z', '0'..'9']) then
    Exit(True);

  Result := False;
end;

function IsLikelyRISCVISAValue(const aValue: string): Boolean;
var
  LText: string;
  LStart: Integer;
  LPos: Integer;
  LToken: string;
  LSignalTokenCount: Integer;
  LUnknownTokenCount: Integer;
begin
  Result := False;
  LText := LowerCase(Trim(aValue));
  if LText = '' then
    Exit;

  LSignalTokenCount := 0;
  LUnknownTokenCount := 0;
  LStart := 1;
  while LStart <= Length(LText) do
  begin
    while (LStart <= Length(LText)) and (LText[LStart] in [' ', #9, '_', ',', ';', '|', '+', '/']) do
      Inc(LStart);
    if LStart > Length(LText) then
      Break;

    LPos := LStart;
    while (LPos <= Length(LText)) and not (LText[LPos] in [' ', #9, '_', ',', ';', '|', '+', '/']) do
      Inc(LPos);

    LToken := Copy(LText, LStart, LPos - LStart);
    if IsLikelyRISCVISAToken(LToken) then
      Inc(LSignalTokenCount)
    else
      Inc(LUnknownTokenCount);
    LStart := LPos + 1;
  end;

  Result := (LSignalTokenCount > 0) and (LUnknownTokenCount = 0);
end;

function TryParseRISCVMISAValue(const aValue: string; out aMISA: QWord): Boolean;
var
  LText: string;
  LCode: Integer;
begin
  Result := False;
  aMISA := 0;

  LText := LowerCase(Trim(aValue));
  if LText = '' then
    Exit;

  LText := RemoveChars(LText, ' ');
  LText := RemoveChars(LText, #9);
  LText := RemoveChars(LText, '_');
  if LText = '' then
    Exit;

  if (Length(LText) >= 1) and ((LText[1] = '+') or (LText[1] = '-')) then
  begin
    // misa should be an unsigned bitmask.
    if LText[1] = '-' then
      Exit;
    Delete(LText, 1, 1);
  end;

  if (Length(LText) >= 2) and (Copy(LText, 1, 2) = '0x') then
    LText := '$' + Copy(LText, 3, MaxInt);

  if LText = '' then
    Exit;

  Val(LText, aMISA, LCode);
  Result := (LCode = 0);
end;

function DecodeMISAXLEN(const aMISA: QWord): Integer;
var
  LXLENEncoded: QWord;
begin
  Result := 0;

  // Prefer RV64/RV128-style MXL location (bits 63:62).
  LXLENEncoded := (aMISA shr 62) and QWord(3);
  case LXLENEncoded of
    1: Exit(32);
    2: Exit(64);
    3: Exit(128);
  end;

  // Fallback for RV32-style encoding (bits 31:30).
  LXLENEncoded := (aMISA shr 30) and QWord(3);
  case LXLENEncoded of
    1: Exit(32);
    2: Exit(64);
    3: Exit(128);
  end;
end;

procedure MergeRISCVFeaturesFromMISA(var aFeatures: TRISCVFeatures; const aMISA: QWord);
const
  RISCV_MISA_A = QWord(1) shl (Ord('A') - Ord('A'));
  RISCV_MISA_C = QWord(1) shl (Ord('C') - Ord('A'));
  RISCV_MISA_D = QWord(1) shl (Ord('D') - Ord('A'));
  RISCV_MISA_F = QWord(1) shl (Ord('F') - Ord('A'));
  RISCV_MISA_I = QWord(1) shl (Ord('I') - Ord('A'));
  RISCV_MISA_M = QWord(1) shl (Ord('M') - Ord('A'));
  RISCV_MISA_V = QWord(1) shl (Ord('V') - Ord('A'));
var
  LXLEN: Integer;
begin
  if (aMISA and RISCV_MISA_I) <> 0 then
  begin
    LXLEN := DecodeMISAXLEN(aMISA);
    if LXLEN = 64 then
      aFeatures.HasRV64I := True
    else if LXLEN = 32 then
      aFeatures.HasRV32I := True
    else
    begin
      {$IFDEF CPURISCV64}
      aFeatures.HasRV64I := True;
      {$ELSE}
      {$IFDEF CPURISCV32}
      aFeatures.HasRV32I := True;
      {$ENDIF}
      {$ENDIF}
    end;
  end;

  if (aMISA and RISCV_MISA_M) <> 0 then
    aFeatures.HasM := True;
  if (aMISA and RISCV_MISA_A) <> 0 then
    aFeatures.HasA := True;
  if (aMISA and RISCV_MISA_F) <> 0 then
    aFeatures.HasF := True;
  if (aMISA and RISCV_MISA_D) <> 0 then
    aFeatures.HasD := True;
  if (aMISA and RISCV_MISA_C) <> 0 then
    aFeatures.HasC := True;
  if (aMISA and RISCV_MISA_V) <> 0 then
    aFeatures.HasV := True;
end;

procedure MergeRISCVFeatureSets(var aTarget: TRISCVFeatures; const aSource: TRISCVFeatures);
begin
  aTarget.HasRV32I := aTarget.HasRV32I or aSource.HasRV32I;
  aTarget.HasRV64I := aTarget.HasRV64I or aSource.HasRV64I;
  aTarget.HasM := aTarget.HasM or aSource.HasM;
  aTarget.HasA := aTarget.HasA or aSource.HasA;
  aTarget.HasF := aTarget.HasF or aSource.HasF;
  aTarget.HasD := aTarget.HasD or aSource.HasD;
  aTarget.HasC := aTarget.HasC or aSource.HasC;
  aTarget.HasV := aTarget.HasV or aSource.HasV;
  aTarget.LinuxHWCAP := aTarget.LinuxHWCAP or aSource.LinuxHWCAP;
  aTarget.LinuxHWCAP2 := aTarget.LinuxHWCAP2 or aSource.LinuxHWCAP2;
end;

function HasRISCVISABase(const aFeatures: TRISCVFeatures): Boolean;
begin
  Result := aFeatures.HasRV64I or aFeatures.HasRV32I;
end;

function CountRISCVFeatureFlags(const aFeatures: TRISCVFeatures): Integer;
begin
  Result := 0;
  if aFeatures.HasRV32I then
    Inc(Result);
  if aFeatures.HasRV64I then
    Inc(Result);
  if aFeatures.HasM then
    Inc(Result);
  if aFeatures.HasA then
    Inc(Result);
  if aFeatures.HasF then
    Inc(Result);
  if aFeatures.HasD then
    Inc(Result);
  if aFeatures.HasC then
    Inc(Result);
  if aFeatures.HasV then
    Inc(Result);
end;

function GetRISCVISAKeyPriority(const aKey: string): Integer;
var
  LKey: string;
begin
  LKey := LowerCase(Trim(aKey));

  if (LKey = 'isa') or
     (LKey = 'isa string') or
     (LKey = 'march') or
     (LKey = 'riscv march') or
     (LKey = 'riscv,march') or
     (LKey = 'riscv,isa') or
     (LKey = 'riscv isa') or
     (LKey = 'riscv_isa') or
     (LKey = 'hart isa') or
     (LKey = 'uarch isa') then
    Exit(60);

  if (LKey = 'isa extension') or
     (LKey = 'isa extensions') or
     (LKey = 'isa-extensions') or
     (LKey = 'isa ext') or
     (LKey = 'isa_ext') or
     (LKey = 'isa_extensions') or
     (LKey = 'isaext') or
     (LKey = 'riscv,isa extension') or
     (LKey = 'riscv,isa extensions') or
     (LKey = 'riscv isa ext') or
     (LKey = 'riscv isa extension') or
     (LKey = 'riscv isa extensions') or
     (LKey = 'riscv_isa_ext') or
     (LKey = 'riscv_isa_extensions') then
    Exit(40);

  if (LKey = 'riscv extension') or
     (LKey = 'riscv extensions') or
     (LKey = 'extensions') then
    Exit(30);

  Result := 10;
end;

function BuildRISCVISAFromFeatures(const aFeatures: TRISCVFeatures): string;
begin
  Result := '';

  if aFeatures.HasRV64I and not aFeatures.HasRV32I then
    Result := 'rv64i'
  else if aFeatures.HasRV32I and not aFeatures.HasRV64I then
    Result := 'rv32i'
  else if aFeatures.HasRV64I and aFeatures.HasRV32I then
  begin
    {$IFDEF CPURISCV32}
    Result := 'rv32i';
    {$ELSE}
    Result := 'rv64i';
    {$ENDIF}
  end;

  if Result = '' then
    Exit;

  if aFeatures.HasM then
    Result := Result + 'm';
  if aFeatures.HasA then
    Result := Result + 'a';
  if aFeatures.HasF then
    Result := Result + 'f';
  if aFeatures.HasD then
    Result := Result + 'd';
  if aFeatures.HasC then
    Result := Result + 'c';
  if aFeatures.HasV then
    Result := Result + 'v';
end;

procedure NormalizeRISCVBaseFeature(var aFeatures: TRISCVFeatures);
begin
  if aFeatures.HasRV64I and aFeatures.HasRV32I then
  begin
    {$IFDEF CPURISCV32}
    aFeatures.HasRV64I := False;
    {$ELSE}
    aFeatures.HasRV32I := False;
    {$ENDIF}
    Exit;
  end;

  if HasRISCVISABase(aFeatures) then
    Exit;

  {$IFDEF CPURISCV32}
  aFeatures.HasRV32I := True;
  {$ELSE}
  aFeatures.HasRV64I := True;
  {$ENDIF}
end;

function ISAStringBaseMatchesFeatures(const aISA: string; const aFeatures: TRISCVFeatures): Boolean;
var
  LISA: string;
begin
  Result := False;
  LISA := LowerCase(Trim(aISA));
  if Length(LISA) < 4 then
    Exit;

  if aFeatures.HasRV64I then
    Exit(Copy(LISA, 1, 4) = 'rv64');
  if aFeatures.HasRV32I then
    Exit(Copy(LISA, 1, 4) = 'rv32');
end;

function ShouldPromoteRISCVISACandidate(
  const aCurrentFound, aCurrentHasBase, aCandidateHasBase: Boolean;
  const aCurrentKeyPriority, aCandidateKeyPriority: Integer;
  const aCurrentFeatureScore, aCandidateFeatureScore: Integer;
  const aCurrentTextLength, aCandidateTextLength: Integer): Boolean;
begin
  if not aCurrentFound then
    Exit(True);

  if aCandidateHasBase <> aCurrentHasBase then
    Exit(aCandidateHasBase);

  if aCandidateKeyPriority <> aCurrentKeyPriority then
    Exit(aCandidateKeyPriority > aCurrentKeyPriority);

  if aCandidateFeatureScore <> aCurrentFeatureScore then
    Exit(aCandidateFeatureScore > aCurrentFeatureScore);

  if aCandidateTextLength <> aCurrentTextLength then
    Exit(aCandidateTextLength > aCurrentTextLength);

  Result := False;
end;

function ExtractBestRISCVISAFromCpuInfo(const aCpuInfo: string; out aISA: string;
  out aFeatures: TRISCVFeatures): Boolean;
var
  LLines: TStringList;
  LLine: string;
  LKey: string;
  LValue: string;
  LLineIndex: Integer;
  LCandidateFeatures: TRISCVFeatures;
  LMISAFeatures: TRISCVFeatures;
  LMISA: QWord;
  LBestKeyPriority: Integer;
  LBestFeatureScore: Integer;
  LBestTextLength: Integer;
  LCandidateKeyPriority: Integer;
  LCandidateFeatureScore: Integer;
  LCandidateTextLength: Integer;
  LBestHasBase: Boolean;
  LCandidateHasBase: Boolean;
  LFoundCandidate: Boolean;
  LFoundMISA: Boolean;
begin
  Result := False;
  aISA := '';
  FillChar(aFeatures, SizeOf(aFeatures), 0);
  FillChar(LMISAFeatures, SizeOf(LMISAFeatures), 0);
  LBestKeyPriority := 0;
  LBestFeatureScore := 0;
  LBestTextLength := 0;
  LBestHasBase := False;
  LFoundCandidate := False;
  LFoundMISA := False;

  LLines := TStringList.Create;
  try
    LLines.Text := ReplaceChar(aCpuInfo, #13, #10);
    for LLineIndex := 0 to LLines.Count - 1 do
    begin
      LLine := Trim(LLines[LLineIndex]);
      if not TryParseKeyValueLine(LLine, LKey, LValue) then
        Continue;

      if IsMISAKey(LKey) then
      begin
        LValue := NormalizeFieldValue(LValue);
        if TryParseRISCVMISAValue(LValue, LMISA) then
        begin
          MergeRISCVFeaturesFromMISA(LMISAFeatures, LMISA);
          LFoundMISA := True;
        end;
        Continue;
      end;

      if not IsISAKey(LKey) then
        Continue;

      LValue := NormalizeISAValue(LValue);
      if LValue = '' then
        Continue;
      if IsWeakRISCVISAKey(LKey) and not IsLikelyRISCVISAValue(LValue) then
        Continue;

      FillChar(LCandidateFeatures, SizeOf(LCandidateFeatures), 0);
      ParseISAString(LValue, LCandidateFeatures);
      LCandidateFeatureScore := CountRISCVFeatureFlags(LCandidateFeatures);
      if LCandidateFeatureScore <= 0 then
        Continue;

      LCandidateHasBase := HasRISCVISABase(LCandidateFeatures);
      LCandidateKeyPriority := GetRISCVISAKeyPriority(LKey);
      LCandidateTextLength := Length(LValue);

      if ShouldPromoteRISCVISACandidate(
        LFoundCandidate, LBestHasBase, LCandidateHasBase,
        LBestKeyPriority, LCandidateKeyPriority,
        LBestFeatureScore, LCandidateFeatureScore,
        LBestTextLength, LCandidateTextLength) then
      begin
        aISA := LValue;
        aFeatures := LCandidateFeatures;
        LBestHasBase := LCandidateHasBase;
        LBestKeyPriority := LCandidateKeyPriority;
        LBestFeatureScore := LCandidateFeatureScore;
        LBestTextLength := LCandidateTextLength;
        LFoundCandidate := True;
      end;
    end;
  finally
    LLines.Free;
  end;

  if LFoundCandidate then
  begin
    if LFoundMISA then
      MergeRISCVFeatureSets(aFeatures, LMISAFeatures);

    if not HasRISCVISABase(aFeatures) then
    begin
      aISA := '';
      Result := False;
      Exit;
    end;

    NormalizeRISCVBaseFeature(aFeatures);
    if (not LBestHasBase) or not ISAStringBaseMatchesFeatures(aISA, aFeatures) then
      aISA := BuildRISCVISAFromFeatures(aFeatures);

    Result := aISA <> '';
    Exit;
  end;

  if LFoundMISA then
  begin
    aFeatures := LMISAFeatures;
    if not HasRISCVISABase(aFeatures) then
    begin
      aISA := '';
      Result := False;
      Exit;
    end;
    NormalizeRISCVBaseFeature(aFeatures);
    aISA := BuildRISCVISAFromFeatures(aFeatures);
    Result := aISA <> '';
    Exit;
  end;
end;

function DetectRISCVFeatures: TRISCVFeatures;
var
{$IFDEF UNIX}
  LCpuInfoContent: string;
{$ENDIF}
{$IFDEF LINUX}
  LDeviceTreeISA: string;
  LAuxHWCAP: QWord;
  LAuxHWCAP2: QWord;
{$ENDIF}
begin
  FillChar(Result, SizeOf(TRISCVFeatures), 0);
  
  {$IFDEF UNIX}
  // Read and parse ISA extensions from /proc/cpuinfo on Linux.
  try
    if ReadProcCpuInfoContent(LCpuInfoContent) then
      Result := ParseRISCVFeaturesFromCpuInfo(LCpuInfoContent);
  except
    // Ignore read failures, use defaults
  end;
  {$ENDIF}

  {$IFDEF LINUX}
  // Merge optional device-tree ISA string as secondary evidence source.
  try
    if ReadRISCVISAFromDeviceTree(LDeviceTreeISA) then
      ParseISAString(LDeviceTreeISA, Result);
  except
    // Ignore read failures, keep parsed state from /proc/cpuinfo.
  end;

  // Merge Linux auxv HWCAP bits as additional evidence/fallback.
  try
    if TryReadLinuxAuxvHWCAP(LAuxHWCAP, LAuxHWCAP2) then
      MergeRISCVFeaturesFromLinuxHWCAP(Result, LAuxHWCAP, LAuxHWCAP2);
  except
    // Ignore read failures, keep current parsed state.
  end;
  {$ENDIF}

  // Keep baseline deterministic even in minimal environments where ISA evidence is truncated.
  NormalizeRISCVBaseFeature(Result);
end;

procedure DetectRISCVVendorAndModel(var cpuInfo: TCPUInfo);
var
  LVendorCandidate: string;
  LModelCandidate: string;
{$IFDEF UNIX}
  LCpuInfoContent: string;
{$ENDIF}
{$IFDEF LINUX}
  LDeviceTreeVendor: string;
  LDeviceTreeModel: string;
{$ENDIF}
begin
  cpuInfo.Vendor := 'RISC-V';
  cpuInfo.Model := 'RISC-V Processor';
  LVendorCandidate := '';
  LModelCandidate := '';
  
  {$IFDEF UNIX}
  // Read processor identity from /proc/cpuinfo.
  try
    if ReadProcCpuInfoContent(LCpuInfoContent) then
      ParseRISCVVendorModelFromCpuInfo(LCpuInfoContent, LVendorCandidate, LModelCandidate);
  except
    // Ignore read failures, use defaults
  end;
  {$ENDIF}

  {$IFDEF LINUX}
  if (LVendorCandidate = '') or (LModelCandidate = '') then
  begin
    try
      ReadRISCVIdentityFromDeviceTree(LDeviceTreeVendor, LDeviceTreeModel);
      if (LVendorCandidate = '') and (LDeviceTreeVendor <> '') then
        LVendorCandidate := LDeviceTreeVendor;
      if (LModelCandidate = '') and (LDeviceTreeModel <> '') then
        LModelCandidate := LDeviceTreeModel;
    except
      // Ignore device-tree read failures, keep current candidates.
    end;
  end;
  {$ENDIF}

  if LVendorCandidate <> '' then
    cpuInfo.Vendor := LVendorCandidate;
  if LModelCandidate <> '' then
    cpuInfo.Model := LModelCandidate;
end;

function GetRISCVProcessorInfo: TRISCVProcessorInfo;
var
  {$IFDEF UNIX}
  LCpuInfoContent: string;
  LISA: string;
  LFeatures: TRISCVFeatures;
  {$ENDIF}
  {$IFDEF LINUX}
  LAuxHWCAP: QWord;
  LAuxHWCAP2: QWord;
  {$ENDIF}
begin
  Result := Default(TRISCVProcessorInfo);
  
  {$IFDEF CPURISCV64}
  Result.Architecture := 'RV64';
  Result.XLEN := 64;
  {$ELSE}
  Result.Architecture := 'RV32';
  Result.XLEN := 32;
  {$ENDIF}
  
  {$IFDEF CPURISCV64}
  Result.ISA := 'rv64i';
  {$ELSE}
  Result.ISA := 'rv32i';
  {$ENDIF}

  {$IFDEF UNIX}
  LISA := '';
  FillChar(LFeatures, SizeOf(LFeatures), 0);
  try
    if ReadProcCpuInfoContent(LCpuInfoContent) then
      ExtractBestRISCVISAFromCpuInfo(LCpuInfoContent, LISA, LFeatures);
  except
    // Ignore read failures, keep defaults.
  end;

  {$IFDEF LINUX}
  try
    if (LISA = '') and ReadRISCVISAFromDeviceTree(LISA) then
      LISA := NormalizeISAValue(LISA);
  except
    // Ignore read failures, keep previous value.
  end;

  // Merge Linux auxv HWCAP as deterministic fallback/supplementary evidence
  // for processor-info ISA synthesis.
  try
    if TryReadLinuxAuxvHWCAP(LAuxHWCAP, LAuxHWCAP2) then
      MergeRISCVFeaturesFromLinuxHWCAP(LFeatures, LAuxHWCAP, LAuxHWCAP2);
  except
    // Ignore read failures, keep current parsed state.
  end;
  {$ENDIF}

  if (LISA <> '') or HasRISCVISABase(LFeatures) then
  begin
    if not HasRISCVISABase(LFeatures) then
      ParseISAString(LISA, LFeatures);

    if HasRISCVISABase(LFeatures) then
    begin
      // Keep processor info deterministic: ISA output must always carry an RV base.
      NormalizeRISCVBaseFeature(LFeatures);
      LISA := BuildRISCVISAFromFeatures(LFeatures);
      if LISA <> '' then
        Result.ISA := LISA;

      if LFeatures.HasRV64I then
      begin
        Result.Architecture := 'RV64';
        Result.XLEN := 64;
      end
      else if LFeatures.HasRV32I then
      begin
        Result.Architecture := 'RV32';
        Result.XLEN := 32;
      end;
    end;
  end;
  {$ENDIF}
end;

function ParseRISCVFeaturesFromCpuInfo(const cpuInfo: string): TRISCVFeatures;
var
  LLines: TStringList;
  LLine: string;
  LKey: string;
  LValue: string;
  LLineIndex: Integer;
  LMISA: QWord;
begin
  FillChar(Result, SizeOf(TRISCVFeatures), 0);

  LLines := TStringList.Create;
  try
    LLines.Text := ReplaceChar(cpuInfo, #13, #10);
    for LLineIndex := 0 to LLines.Count - 1 do
    begin
      LLine := Trim(LLines[LLineIndex]);
      if not TryParseKeyValueLine(LLine, LKey, LValue) then
        Continue;

      if not IsISAKey(LKey) then
      begin
        if IsMISAKey(LKey) then
        begin
          LValue := NormalizeFieldValue(LValue);
          if TryParseRISCVMISAValue(LValue, LMISA) then
            MergeRISCVFeaturesFromMISA(Result, LMISA);
        end;
        Continue;
      end;

      LValue := NormalizeISAValue(LValue);
      if IsWeakRISCVISAKey(LKey) and not IsLikelyRISCVISAValue(LValue) then
        Continue;
      ParseISAString(LValue, Result);
    end;
  finally
    LLines.Free;
  end;

  // Keep parser deterministic when mixed ISA lines report conflicting RV base.
  // Do not synthesize a base when none was parsed from cpuinfo text.
  if Result.HasRV32I and Result.HasRV64I then
    NormalizeRISCVBaseFeature(Result);
end;

{$ELSE}

// === Non-RISC-V platform stubs ===

function DetectRISCVFeatures: TRISCVFeatures;
begin
  FillChar(Result, SizeOf(TRISCVFeatures), 0);
end;

procedure DetectRISCVVendorAndModel(var cpuInfo: TCPUInfo);
begin
  cpuInfo.Vendor := 'Non-RISC-V';
  cpuInfo.Model := 'Non-RISC-V Processor';
end;

function GetRISCVProcessorInfo: TRISCVProcessorInfo;
begin
  Result := Default(TRISCVProcessorInfo);
  Result.Architecture := 'Non-RISC-V';
  Result.ISA := 'Non-RISC-V';
  Result.XLEN := 0;
end;

function ParseRISCVFeaturesFromCpuInfo(const cpuInfo: string): TRISCVFeatures;
begin
  FillChar(Result, SizeOf(TRISCVFeatures), 0);
end;

function ExtractBestRISCVISAFromCpuInfo(const aCpuInfo: string; out aISA: string;
  out aFeatures: TRISCVFeatures): Boolean;
begin
  aISA := '';
  FillChar(aFeatures, SizeOf(aFeatures), 0);
  Result := False;
end;

function ParseRISCVVendorModelFromCpuInfo(const aCpuInfo: string; out aVendor, aModel: string): Boolean;
begin
  aVendor := '';
  aModel := '';
  Result := False;
end;

{$ENDIF}

end.
