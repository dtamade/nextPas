unit nextpas.core.simd.cpuinfo.base;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

type
  TCPUArch = (caUnknown, caX86, caARM, caRISCV, caLoongArch);
  // Generic, cross-arch features for upper layers
  TGenericFeature = (
    gfSimd128,   // 128-bit SIMD available
    gfSimd256,   // 256-bit SIMD available
    gfSimd512,   // 512-bit SIMD available
    gfAES,       // AES instructions
    gfSHA,       // SHA instructions
    gfFMA        // Fused multiply-add
  );
  TGenericFeatureSet = set of TGenericFeature;

  // x86 CPU features
  TX86Features = record
    HasMMX: Boolean;
    HasSSE: Boolean;
    HasSSE2: Boolean;
    HasSSE3: Boolean;
    HasSSSE3: Boolean;
    HasSSE41: Boolean;
    HasSSE42: Boolean;
    HasPOPCNT: Boolean;

    HasAVX: Boolean;
    HasAVX2: Boolean;
    HasAVX512F: Boolean;
    HasAVX512DQ: Boolean;
    HasAVX512BW: Boolean;
    HasAVX512VL: Boolean;
    HasAVX512VBMI: Boolean;

    HasFMA: Boolean;
    HasFMA4: Boolean;

    HasBMI1: Boolean;
    HasBMI2: Boolean;

    HasAES: Boolean;
    HasPCLMULQDQ: Boolean;
    HasSHA: Boolean;

    HasRDRAND: Boolean;
    HasRDSEED: Boolean;
    HasF16C: Boolean;
  end;

  // Arch-specific ISA enums for strong-typed queries
  TX86ISA = (
    xMMX, xSSE, xSSE2, xSSE3, xSSSE3, xSSE41, xSSE42, xPOPCNT,
    xAVX, xAVX2, xAVX512F, xAVX512DQ, xAVX512BW, xAVX512VL, xAVX512VBMI,
    xAES, xSHA, xPCLMULQDQ, xFMA, xFMA4, xBMI1, xBMI2, xF16C, xRDRAND, xRDSEED
  );

  // ARM CPU features
  TARMFeatures = record
    HasNEON: Boolean;
    HasFP: Boolean;
    HasAdvSIMD: Boolean;
    HasSVE: Boolean;
    HasSVE2: Boolean;
    HasCrypto: Boolean;
  end;

  TARMISA = (aNEON, aAdvSIMD, aSVE, aCrypto);

  // RISC-V CPU features
  TRISCVFeatures = record
    HasRV32I: Boolean;
    HasRV64I: Boolean;
    HasM: Boolean;
    HasA: Boolean;
    HasF: Boolean;
    HasD: Boolean;
    HasC: Boolean;
    HasV: Boolean;
    // Raw Linux auxv evidence for diagnostics/future extension mapping.
    LinuxHWCAP: QWord;
    LinuxHWCAP2: QWord;
  end;

  TRISCVISA = (rvV, rvF, rvD, rvA, rvC);

  // LoongArch CPU features
  TLoongArchFeatures = record
    HasLASX: Boolean;
    // Raw Linux auxv evidence for diagnostics/future extension mapping.
    LinuxHWCAP: QWord;
    LinuxHWCAP2: QWord;
  end;

  // x86 Cache information
  TX86CacheInfo = record
    L1DataCache: Integer;        // KB
    L1InstructionCache: Integer; // KB
    L2Cache: Integer;            // KB
    L3Cache: Integer;            // KB
    CacheLineSize: Integer;      // bytes
  end;

  // Generic Cache information
  TCacheInfo = record
    L1DataKB: Integer;
    L1InstrKB: Integer;
    L2KB: Integer;
    L3KB: Integer;
    LineSize: Integer; // bytes
  end;

  // Combined CPU information (cross-arch container)
  TCPUInfo = record
    Arch: TCPUArch;
    Vendor: string;
    Model: string;
    LogicalCores: Integer;
    PhysicalCores: Integer;
    Cache: TCacheInfo;
    OSXSAVE: Boolean;
    XCR0: UInt64;
    GenericRaw: TGenericFeatureSet;
    GenericUsable: TGenericFeatureSet;
    {$IFDEF SIMD_X86_AVAILABLE}
    X86: TX86Features;
    {$ENDIF}
    {$IFDEF SIMD_ARM_AVAILABLE}
    ARM: TARMFeatures;
    {$ENDIF}
    {$IFDEF SIMD_RISCV_AVAILABLE}
    RISCV: TRISCVFeatures;
    {$ENDIF}
    {$IFDEF SIMD_LOONGARCH_AVAILABLE}
    LoongArch: TLoongArchFeatures;
    {$ENDIF}
  end;

// Parse Linux sysfs cache-size text into KB.
// Supports K/KB/KiB, M/MB/MiB, G/GB/GiB and raw bytes.
// Saturates at High(Integer) on overflow.
// Shared x86 backend requirement helpers live here so cpuinfo predicates and
// backend registration reuse one contract without circular dependencies.
function X86HasAVX512BackendRequiredFeatures(const aX86: TX86Features): Boolean; inline;
function X86SupportsAVX512BackendOnCPU(const aX86: TX86Features; const aHasUsableAVX512: Boolean): Boolean; inline;
function ParseCacheSizeTextToKB(const aText: string): Integer;
function RemoveChars(const aStr: string; aChar: Char): string;
function ReplaceChar(const aStr: string; aOld, aNew: Char): string;
function CollapseSpaces(const aStr: string): string;

implementation

uses
  nextpas.core.text.conv;

function RemoveChars(const aStr: string; aChar: Char): string;
var
  i, j: Integer;
begin
  SetLength(Result, Length(aStr));
  j := 0;
  for i := 1 to Length(aStr) do
    if aStr[i] <> aChar then
    begin
      Inc(j);
      Result[j] := aStr[i];
    end;
  SetLength(Result, j);
end;

function ReplaceChar(const aStr: string; aOld, aNew: Char): string;
var i: Integer;
begin
  Result := aStr;
  for i := 1 to Length(Result) do
    if Result[i] = aOld then Result[i] := aNew;
end;

function CollapseSpaces(const aStr: string): string;
var
  i, j: Integer;
  LPrev: Boolean;
begin
  SetLength(Result, Length(aStr));
  j := 0;
  LPrev := False;
  for i := 1 to Length(aStr) do
  begin
    if aStr[i] = ' ' then
    begin
      if not LPrev then begin Inc(j); Result[j] := ' '; end;
      LPrev := True;
    end
    else
    begin
      Inc(j); Result[j] := aStr[i];
      LPrev := False;
    end;
  end;
  SetLength(Result, j);
end;

function X86HasAVX512BackendRequiredFeatures(const aX86: TX86Features): Boolean; inline;
begin
  Result := aX86.HasAVX2 and aX86.HasAVX512F and aX86.HasAVX512BW and
            aX86.HasPOPCNT and aX86.HasFMA;
end;

function X86SupportsAVX512BackendOnCPU(const aX86: TX86Features; const aHasUsableAVX512: Boolean): Boolean; inline;
begin
  Result := aHasUsableAVX512 and X86HasAVX512BackendRequiredFeatures(aX86);
end;

function ParseCacheSizeTextToKB(const aText: string): Integer;
var
  LText: string;
  LNumText: string;
  LCode: Integer;
  LValue: Int64;
  LUnit: Char;

  function ClampKBToInteger(const aValue: Int64): Integer; inline;
  begin
    if aValue <= 0 then
      Exit(0);
    if aValue > High(Integer) then
      Exit(High(Integer));
    Result := Integer(aValue);
  end;

  function BytesToKB(const aBytes: Int64): Integer; inline;
  var
    LKBValue: Int64;
  begin
    if aBytes <= 0 then
      Exit(0);
    // ceil(bytes/1024) without risking (bytes + 1023) overflow.
    LKBValue := ((aBytes - 1) div 1024) + 1;
    Result := ClampKBToInteger(LKBValue);
  end;
begin
  Result := 0;
  LText := UpperCase(Trim(aText));
  if LText = '' then
    Exit;

  LText := RemoveChars(LText, ' ');
  LText := RemoveChars(LText, #9);
  if LText = '' then
    Exit;

  if (Length(LText) >= 3) and (Copy(LText, Length(LText) - 2, 3) = 'KIB') then
  begin
    LUnit := 'K';
    LNumText := Copy(LText, 1, Length(LText) - 3);
  end
  else if (Length(LText) >= 3) and (Copy(LText, Length(LText) - 2, 3) = 'MIB') then
  begin
    LUnit := 'M';
    LNumText := Copy(LText, 1, Length(LText) - 3);
  end
  else if (Length(LText) >= 3) and (Copy(LText, Length(LText) - 2, 3) = 'GIB') then
  begin
    LUnit := 'G';
    LNumText := Copy(LText, 1, Length(LText) - 3);
  end
  else if (Length(LText) >= 2) and (Copy(LText, Length(LText) - 1, 2) = 'KB') then
  begin
    LUnit := 'K';
    LNumText := Copy(LText, 1, Length(LText) - 2);
  end
  else if (Length(LText) >= 2) and (Copy(LText, Length(LText) - 1, 2) = 'MB') then
  begin
    LUnit := 'M';
    LNumText := Copy(LText, 1, Length(LText) - 2);
  end
  else if (Length(LText) >= 2) and (Copy(LText, Length(LText) - 1, 2) = 'GB') then
  begin
    LUnit := 'G';
    LNumText := Copy(LText, 1, Length(LText) - 2);
  end
  else if (Length(LText) >= 1) and (LText[Length(LText)] in ['K', 'M', 'G']) then
  begin
    LUnit := LText[Length(LText)];
    LNumText := Copy(LText, 1, Length(LText) - 1);
  end
  else if (Length(LText) >= 1) and (LText[Length(LText)] = 'B') then
  begin
    LNumText := Copy(LText, 1, Length(LText) - 1);
    Val(LNumText, LValue, LCode);
    if (LCode = 0) and (LValue > 0) then
      Result := BytesToKB(LValue);
    Exit;
  end
  else
  begin
    Val(LText, LValue, LCode);
    if (LCode = 0) and (LValue > 0) then
      Result := BytesToKB(LValue);
    Exit;
  end;

  Val(LNumText, LValue, LCode);
  if (LCode <> 0) or (LValue <= 0) then
    Exit;

  case LUnit of
    'K':
      Result := ClampKBToInteger(LValue);
    'M':
      begin
        if LValue > (High(Integer) div 1024) then
          Result := High(Integer)
        else
          Result := Integer(LValue * 1024);
      end;
    'G':
      begin
        if LValue > (High(Integer) div (1024 * 1024)) then
          Result := High(Integer)
        else
          Result := Integer(LValue * 1024 * 1024);
      end;
  else
    Val(LText, LValue, LCode);
    if (LCode = 0) and (LValue > 0) then
      Result := BytesToKB(LValue)
    else
      Result := 0;
  end;
end;

end.




