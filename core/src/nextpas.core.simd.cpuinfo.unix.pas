unit nextpas.core.simd.cpuinfo.unix;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

// Detect physical and logical core counts on generic Unix/Linux
function DetectCoreCounts(out Physical, Logical: LongInt): Boolean;

implementation

uses
  nextpas.core.base
  {$IFDEF LINUX}
  , Unix
  {$ENDIF}
  ;

{$I nextpas.core.simd.cpuinfo.helpers.inc}

{$IFNDEF FPC_HAS_SYSCONF}
const
  _SC_NPROCESSORS_ONLN = 84; // Linux x86_64 value

function fpSysConf(name: cint): clong; cdecl; external 'c' name 'sysconf';
{$ENDIF}

{$IFDEF LINUX}
// Linux core count detection
// Note: parsing /proc/cpuinfo for physical/core ids is x86 specific; for non-x86 we use sysconf directly
function DetectLinuxCores(out Physical, Logical: LongInt): Boolean;
{$if defined(CPUX86_64) or defined(CPUI386)}
var
  F: TextFile;
  Line: string;
  PhysicalIds, CoreIds: array of Integer;
  CurPhysId, CurCoreId: Integer;
  i: Integer;
  Found: Boolean;
{$endif}
begin
  {$if defined(CPUX86_64) or defined(CPUI386)}
  Physical := 0;
  Logical := 0;
  CurPhysId := -1;
  CurCoreId := -1;
  PhysicalIds := nil;
  CoreIds := nil;
  try
    AssignFile(F, '/proc/cpuinfo');
    Reset(F);
    try
      while not EOF(F) do
      begin
        ReadLn(F, Line);
        if Pos('processor', Line) = 1 then
          Inc(Logical);
        if Pos('physical id', Line) = 1 then
        begin
          i := Pos(':', Line);
          if i > 0 then
            CurPhysId := StrToIntDef(Trim(Copy(Line, i+1, Length(Line))), -1);
        end;
        if Pos('core id', Line) = 1 then
        begin
          i := Pos(':', Line);
          if i > 0 then
            CurCoreId := StrToIntDef(Trim(Copy(Line, i+1, Length(Line))), -1);
          if (CurPhysId >= 0) and (CurCoreId >= 0) then
          begin
            Found := False;
            for i := 0 to High(PhysicalIds) do
            begin
              if (PhysicalIds[i] = CurPhysId) and (CoreIds[i] = CurCoreId) then
              begin
                Found := True;
                Break;
              end;
            end;
            if not Found then
            begin
              SetLength(PhysicalIds, Length(PhysicalIds) + 1);
              SetLength(CoreIds, Length(CoreIds) + 1);
              PhysicalIds[High(PhysicalIds)] := CurPhysId;
              CoreIds[High(CoreIds)] := CurCoreId;
              Inc(Physical);
            end;
          end;
        end;
      end;
    finally
      CloseFile(F);
    end;
    if Logical = 0 then
      Logical := fpSysConf(_SC_NPROCESSORS_ONLN);
    if Physical = 0 then
      Physical := Logical;
    Result := (Physical > 0) and (Logical > 0);
  except
    Logical := fpSysConf(_SC_NPROCESSORS_ONLN);
    Physical := Logical;
    Result := Logical > 0;
  end;
  {$else}
  // Non-x86: prefer sysconf and treat physical = logical
  Logical := fpSysConf(_SC_NPROCESSORS_ONLN);
  if Logical < 1 then Logical := 1;
  Physical := Logical;
  Result := True;
  {$endif}
end;
{$ENDIF}

function DetectCoreCounts(out Physical, Logical: LongInt): Boolean;
begin
  {$IFDEF LINUX}
  Result := DetectLinuxCores(Physical, Logical);
  if not Result then
  begin
    Logical := fpSysConf(_SC_NPROCESSORS_ONLN);
    if Logical < 1 then Logical := 1;
    Physical := Logical;
    Result := True;
  end;
  {$ELSE}
  Logical := fpSysConf(_SC_NPROCESSORS_ONLN);
  if Logical < 1 then Logical := 1;
  Physical := Logical;
  Result := True;
  {$ENDIF}
end;

end.
