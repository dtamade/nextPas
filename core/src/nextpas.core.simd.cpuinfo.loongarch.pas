unit nextpas.core.simd.cpuinfo.loongarch;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

{$IFDEF SIMD_LOONGARCH_AVAILABLE}

uses
  nextpas.core.simd.cpuinfo.base;

function DetectLoongArchFeatures: TLoongArchFeatures;
procedure DetectLoongArchVendorAndModel(var aCPUInfo: TCPUInfo);

{$ENDIF}

implementation

{$IFDEF SIMD_LOONGARCH_AVAILABLE}

uses
  SysUtils
  {$IFDEF LINUX}
  , nextpas.core.platform.files.base
  , nextpas.core.platform.files
  {$ENDIF}
  ;

{$IFDEF LINUX}
const
  LINUX_AUXV_AT_NULL   = 0;
  LINUX_AUXV_AT_HWCAP  = 16;
  LINUX_AUXV_AT_HWCAP2 = 26;

  LOONGARCH_HWCAP_LASX = QWord(1) shl 5;

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

function ReadProcCpuInfoSafe: string;
var
  LFile: TextFile;
  LLine: string;
  LText: string;
  LOpened: Boolean;
begin
  LText := '';
  LOpened := False;
  try
    if FileExists('/proc/cpuinfo') then
    begin
      AssignFile(LFile, '/proc/cpuinfo');
      Reset(LFile);
      LOpened := True;
      while not EOF(LFile) do
      begin
        ReadLn(LFile, LLine);
        LText := LText + LLine + LineEnding;
      end;
    end;
  except
    LText := '';
  end;

  if LOpened then
  begin
    try
      CloseFile(LFile);
    except
      // Ignore close failures and return the best-effort snapshot.
    end;
  end;

  Result := LText;
end;

function NormalizeFieldValue(const aValue: string): string;
begin
  Result := Trim(aValue);
  Result := CollapseSpaces(Result);
end;

function TryParseKeyValueLine(const aLine: string; out aKey, aValue: string): Boolean;
var
  LLine: string;
  LSeparatorPos: Integer;
begin
  Result := False;
  aKey := '';
  aValue := '';

  LLine := Trim(aLine);
  if LLine = '' then
    Exit;

  LSeparatorPos := Pos(':', LLine);
  if LSeparatorPos <= 0 then
    Exit;

  aKey := LowerCase(Trim(Copy(LLine, 1, LSeparatorPos - 1)));
  aValue := NormalizeFieldValue(Copy(LLine, LSeparatorPos + 1, MaxInt));
  Result := (aKey <> '') and (aValue <> '');
end;

function ContainsLASXToken(const aText: string): Boolean;
var
  LNormalized: string;
  LIndex: Integer;
begin
  LNormalized := LowerCase(aText);
  for LIndex := 1 to Length(LNormalized) do
    if not (LNormalized[LIndex] in ['a'..'z', '0'..'9']) then
      LNormalized[LIndex] := ' ';
  Result := Pos(' lasx ', ' ' + LNormalized + ' ') > 0;
end;
{$ENDIF}

procedure MergeLoongArchFeaturesFromLinuxHWCAP(var aFeatures: TLoongArchFeatures;
  const aHWCAP, aHWCAP2: QWord);
begin
  {$IFDEF LINUX}
  aFeatures.LinuxHWCAP := aFeatures.LinuxHWCAP or aHWCAP;
  aFeatures.LinuxHWCAP2 := aFeatures.LinuxHWCAP2 or aHWCAP2;
  if (aHWCAP and LOONGARCH_HWCAP_LASX) <> 0 then
    aFeatures.HasLASX := True;
  {$ELSE}
  if (aHWCAP <> 0) or (aHWCAP2 <> 0) then
    ;
  {$ENDIF}
end;

function DetectLoongArchFeatures: TLoongArchFeatures;
{$IFDEF LINUX}
var
  LAuxHWCAP: QWord;
  LAuxHWCAP2: QWord;
  LCpuInfoText: string;
{$ENDIF}
begin
  Result := Default(TLoongArchFeatures);
  {$IFDEF LINUX}
  if TryReadLinuxAuxvHWCAP(LAuxHWCAP, LAuxHWCAP2) then
    MergeLoongArchFeaturesFromLinuxHWCAP(Result, LAuxHWCAP, LAuxHWCAP2);

  LCpuInfoText := ReadProcCpuInfoSafe;
  if ContainsLASXToken(LCpuInfoText) then
    Result.HasLASX := True;
  {$ENDIF}
end;

procedure DetectLoongArchVendorAndModel(var aCPUInfo: TCPUInfo);
{$IFDEF LINUX}
const
  VENDOR_KEYS: array[0..3] of string = (
    'vendor',
    'vendor_id',
    'cpu family',
    'system type'
  );
  MODEL_KEYS: array[0..4] of string = (
    'model name',
    'cpu model',
    'model',
    'machine',
    'processor'
  );
var
  LCPUInfoText: string;
  LLine: string;
  LPos, LStart, LLen: Integer;
  LKey: string;
  LValue: string;

  function KeyMatches(const aKey: string; const aCandidates: array of string): Boolean;
  var
    LCandidateIndex: Integer;
  begin
    for LCandidateIndex := Low(aCandidates) to High(aCandidates) do
      if aKey = aCandidates[LCandidateIndex] then
        Exit(True);
    Result := False;
  end;
{$ENDIF}
begin
  aCPUInfo.Vendor := 'LoongArch';
  aCPUInfo.Model := 'Unknown LoongArch Processor';

  {$IFDEF LINUX}
  LCPUInfoText := ReadProcCpuInfoSafe;
  if LCPUInfoText = '' then
    Exit;

  LLen := Length(LCPUInfoText);
  LStart := 1;
  LPos := 1;
  while LPos <= LLen do
  begin
    if (LCPUInfoText[LPos] = #10) or (LPos = LLen) then
    begin
      if LPos = LLen then
        LLine := Copy(LCPUInfoText, LStart, LPos - LStart + 1)
      else
        LLine := Copy(LCPUInfoText, LStart, LPos - LStart);
      LStart := LPos + 1;

      if TryParseKeyValueLine(LLine, LKey, LValue) and (LValue <> '') then
      begin
        if KeyMatches(LKey, VENDOR_KEYS) and (aCPUInfo.Vendor = 'LoongArch') then
          aCPUInfo.Vendor := LValue;

        if KeyMatches(LKey, MODEL_KEYS) and (aCPUInfo.Model = 'Unknown LoongArch Processor') then
          aCPUInfo.Model := LValue;

        if (aCPUInfo.Vendor <> 'LoongArch') and (aCPUInfo.Model <> 'Unknown LoongArch Processor') then
          Break;
      end;
    end;
    Inc(LPos);
  end;
  {$ENDIF}
end;

{$ENDIF}

end.
