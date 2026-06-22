unit SysUtils;

{$mode objfpc}{$H+}

interface

const
  PathDelim = '/';
  DirectorySeparator = '/';

  // File attributes
  faAnyFile = $0000003F;
  faDirectory = $00000010;

type
  TStringArray = array of string;

  TDateTime = Double;

  TReplaceFlags = set of (rfReplaceAll, rfIgnoreCase);

  TSearchRec = record
    Name: string;
    Attr: LongInt;
    Size: Int64;
    Time: LongInt;
    FindHandle: Pointer;
    Pattern: string; { stored by FindFirst, used by FindNext to filter }
  end;

  Exception = class
  private
    FMessage: string;
  public
    constructor Create(const Msg: string);
    constructor CreateFmt(const Msg: string; const Args: array of const);
    property Message: string read FMessage;
  end;

  ExceptClass = class of Exception;

  EHeapMemoryError = class(Exception)
  end;

  EHeapException = EHeapMemoryError;

  EInvalidPointer = class(EHeapMemoryError)
  end;

  EOutOfMemory = class(EHeapMemoryError)
  end;

  EConvertError = class(Exception)
  end;

  EAssertionFailed = class(Exception)
  end;

// String operations
function Trim(const S: string): string;
function LowerCase(const S: string): string;
function UpperCase(const S: string): string;
function SameText(const S1, S2: string): Boolean;
procedure Delete(var S: string; Index, Count: Integer);
procedure Insert(const Source: string; var S: string; Index: Integer);

// File operations
function FileExists(const FileName: string): Boolean;
function DirectoryExists(const Directory: string): Boolean;
function DeleteFile(const FileName: string): Boolean;
function FileSearch(const Name, DirList: string): string;
function ForceDirectories(const Dir: string): Boolean;
function FileAge(const FileName: string): LongInt;
function ExpandFileName(const FileName: string): string;
function ExtractFileDir(const FileName: string): string;
function ExtractFileName(const FileName: string): string;
function ChangeFileExt(const FileName, Extension: string): string;
function IncludeTrailingPathDelimiter(const Path: string): string;
function ExcludeTrailingPathDelimiter(const Path: string): string;

// Environment
function GetEnvironmentVariable(const Name: string): string;

// File search
function FindFirst(const Path: string; Attr: LongInt; var F: TSearchRec): LongInt;
function FindNext(var F: TSearchRec): LongInt;
procedure FindClose(var F: TSearchRec);

// Type conversions
function IntToStr(Value: Integer): string;
function IntToStr(Value: Int64): string;
function StrToInt(const S: string): Integer;
function StrToIntDef(const S: string; Default: Integer): Integer;
function StrToInt64Def(const S: string; Default: Int64): Int64;
function IntToHex(Value: Int64; Digits: Integer): string;
function TryStrToInt(const S: string; out Value: Integer): Boolean;
function TryStrToInt64(const S: string; out Value: Int64): Boolean;

// String manipulation
function StringReplace(const S, OldPattern, NewPattern: string;
  Flags: TReplaceFlags): string;
function ExtractFileExt(const FileName: string): string;
function ExtractFileDrive(const FileName: string): string;
function LastDelimiter(const Delimiters, S: string): Integer;

// Command line
function ParamStr(Index: Integer): string;
function ParamCount: Integer;
function GetCurrentDir: string;

// Date/Time
function Now: TDateTime;
function FormatDateTime(const Format: string; DateTime: TDateTime): string;

// String formatting
function Format(const Fmt: string; const Args: array of const): string;

// Interface support
function Supports(const AIntf: IInterface; const IID: TGUID; out Intf): Boolean;

// Memory management
procedure FreeAndNil(var Obj);

implementation

{ External C functions }
function getenv(name: PChar): PChar; cdecl; external 'c' name 'getenv';
function getcwd(buf: PChar; size: SizeUInt): PChar; cdecl; external 'c' name 'getcwd';
function np_open(path: PChar; flags: LongInt): LongInt; cdecl; external 'c' name 'open';
function np_read(fd: LongInt; buf: Pointer; count: SizeUInt): SizeUInt; cdecl; external 'c' name 'read';
function np_close(fd: LongInt): LongInt; cdecl; external 'c' name 'close';
function readlink(path: PChar; buf: PChar; bufsiz: SizeUInt): SizeInt; cdecl; external 'c' name 'readlink';
function np_stat(path: PChar; buf: Pointer): LongInt; cdecl; external 'c' name 'stat';
function np_realpath(path: PChar; resolved: PChar): PChar; cdecl; external 'c' name 'realpath';

{ Exception }

constructor Exception.Create(const Msg: string);
begin
  inherited Create;
  FMessage := Msg;
end;

constructor Exception.CreateFmt(const Msg: string;
  const Args: array of const);
begin
  Create(Format(Msg, Args));
end;

{ String operations }

function Trim(const S: string): string;
var
  I, L: Integer;
begin
  L := Length(S);
  I := 1;
  while (I <= L) and (S[I] <= ' ') do
    Inc(I);
  if I > L then
    Exit('');
  while S[L] <= ' ' do
    Dec(L);
  Result := Copy(S, I, L - I + 1);
end;

function LowerCase(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] in ['A'..'Z'] then
      Result[I] := Chr(Ord(Result[I]) + 32);
end;

function UpperCase(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] in ['a'..'z'] then
      Result[I] := Chr(Ord(Result[I]) - 32);
end;

function SameText(const S1, S2: string): Boolean;
var
  I, L: Integer;
  C1, C2: Char;
begin
  L := Length(S1);
  if L <> Length(S2) then
    Exit(False);
  for I := 1 to L do
  begin
    C1 := S1[I];
    C2 := S2[I];
    if C1 in ['a'..'z'] then
      C1 := Chr(Ord(C1) - 32);
    if C2 in ['a'..'z'] then
      C2 := Chr(Ord(C2) - 32);
    if C1 <> C2 then
      Exit(False);
  end;
  Result := True;
end;

procedure Delete(var S: string; Index, Count: Integer);
begin
  System.Delete(S, Index, Count);
end;

procedure Insert(const Source: string; var S: string; Index: Integer);
begin
  System.Insert(Source, S, Index);
end;

{ File operations }

function np_access(path: PChar; mode: LongInt): LongInt; cdecl; external 'c' name 'access';

function FileExists(const FileName: string): Boolean;
begin
  { Use access(R_OK) which follows symlinks and works for all file types.
    FPC's Reset(F) on untyped files does not follow symlinks to ELF binaries. }
  Result := np_access(PChar(FileName), 0) = 0; { F_OK = 0: file exists }
end;

function DirectoryExists(const Directory: string): Boolean;
var
  OldDir: string;
begin
  // Try to change to the directory
  GetDir(0, OldDir);
  {$I-}
  ChDir(Directory);
  {$I+}
  Result := IOResult = 0;

  if Result then
  begin
    // Restore original directory
    {$I-}
    ChDir(OldDir);
    {$I+}
    IOResult; // Clear error
  end;
end;

function DeleteFile(const FileName: string): Boolean;
var
  F: File;
begin
  Assign(F, FileName);
  {$I-}
  Erase(F);
  {$I+}
  Result := IOResult = 0;
end;

function FileSearch(const Name, DirList: string): string;
var
  StartPos, EndPos: Integer;
  Dir, TestPath: string;
begin
  // If Name is absolute path and exists, return it
  if (Length(Name) > 0) and (Name[1] = '/') then
  begin
    if FileExists(Name) then
      Exit(Name)
    else
      Exit('');
  end;

  // Search in DirList (colon-separated paths)
  StartPos := 1;
  while StartPos <= Length(DirList) do
  begin
    EndPos := StartPos;
    while (EndPos <= Length(DirList)) and (DirList[EndPos] <> ':') do
      Inc(EndPos);

    Dir := Copy(DirList, StartPos, EndPos - StartPos);
    if Dir <> '' then
    begin
      TestPath := IncludeTrailingPathDelimiter(Dir) + Name;
      if FileExists(TestPath) then
        Exit(TestPath);
    end;

    StartPos := EndPos + 1;
  end;

  // Not found
  Result := '';
end;

function ForceDirectories(const Dir: string): Boolean;
var
  ParentDir: string;
begin
  // Empty or root directory
  if (Dir = '') or (Dir = '/') then
  begin
    Result := True;
    Exit;
  end;

  // Already exists
  if DirectoryExists(Dir) then
  begin
    Result := True;
    Exit;
  end;

  // Create parent first
  ParentDir := ExtractFileDir(Dir);
  if ParentDir <> Dir then
  begin
    if not ForceDirectories(ParentDir) then
    begin
      Result := False;
      Exit;
    end;
  end;

  // Create this directory
  {$I-}
  MkDir(Dir);
  {$I+}
  Result := IOResult = 0;
end;

{ FileAge: returns file modification time as Unix timestamp, or -1 on error.
  Uses libc stat() to query the actual mtime. Matches FPC behavior:
  result > 0 means file exists and has a valid mtime. }
function FileAge(const FileName: string): LongInt;
const
  STAT_MTIME_OFFSET = 88;  { st_mtim.tv_sec offset in struct stat (linux-x86_64) }
var
  LBuf: array[0..143] of Byte;  { sizeof(struct stat) = 144 }
  LSecs: Int64;
begin
  FillChar(LBuf[0], SizeOf(LBuf), 0);
  if np_stat(PChar(FileName), @LBuf[0]) <> 0 then
    Exit(-1);
  Move(LBuf[STAT_MTIME_OFFSET], LSecs, SizeOf(Int64));
  Result := LongInt(LSecs);
end;

{ ExpandFileName: resolve path to absolute, normalizing . and ..
  Uses libc realpath(3) for existing paths. For non-existent paths,
  returns the original path (matching FPC behavior for relative paths
  that don't contain .. components). }
function ExpandFileName(const FileName: string): string;
const
  PATH_MAX = 4096;
var
  LBuf: array[0..PATH_MAX] of Char;
  LRes: PChar;
begin
  if FileName = '' then
  begin
    LRes := getcwd(@LBuf[0], PATH_MAX);
    if LRes <> nil then
      Result := LBuf
    else
      Result := '';
    Exit;
  end;
  FillChar(LBuf[0], SizeOf(LBuf), 0);
  LRes := np_realpath(PChar(FileName), @LBuf[0]);
  if LRes <> nil then
    Result := LBuf
  else
    { realpath fails if file doesn't exist — return original path.
      This matches FPC behavior for relative paths. }
    Result := FileName;
end;

function ExtractFileDir(const FileName: string): string;
var
  I: Integer;
begin
  I := Length(FileName);

  // Skip trailing slashes
  while (I > 0) and (FileName[I] = '/') do
    Dec(I);

  // Find the last slash before the filename
  while (I > 0) and (FileName[I] <> '/') do
    Dec(I);

  if I = 0 then
    Exit('');

  Result := Copy(FileName, 1, I - 1);
end;

function ExtractFileName(const FileName: string): string;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and (FileName[I] <> '/') do
    Dec(I);
  Result := Copy(FileName, I + 1, Length(FileName) - I);
end;

function ChangeFileExt(const FileName, Extension: string): string;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and (FileName[I] <> '.') and (FileName[I] <> '/') do
    Dec(I);

  if (I > 0) and (FileName[I] = '.') then
    Result := Copy(FileName, 1, I - 1) + Extension
  else
    Result := FileName + Extension;
end;

function IncludeTrailingPathDelimiter(const Path: string): string;
begin
  Result := Path;
  if (Result <> '') and (Result[Length(Result)] <> '/') then
    Result := Result + '/';
end;

function ExcludeTrailingPathDelimiter(const Path: string): string;
begin
  Result := Path;
  while (Result <> '') and (Result[Length(Result)] = '/') do
    SetLength(Result, Length(Result) - 1);
end;

function ExtractFileExt(const FileName: string): string;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and (FileName[I] <> '.') and (FileName[I] <> '/') do
    Dec(I);
  if (I > 0) and (FileName[I] = '.') then
    Result := Copy(FileName, I, Length(FileName) - I + 1)
  else
    Result := '';
end;

function ExtractFileDrive(const FileName: string): string;
var
  I: Integer;
begin
  Result := '';
  if Length(FileName) < 2 then
    Exit;
  { Check for Windows-style drive letter (C:\...) }
  if (FileName[2] = ':') and (UpCase(FileName[1]) in ['A'..'Z']) then
  begin
    Result := Copy(FileName, 1, 2);
    Exit;
  end;
  { Check for UNC path (\\server\...) }
  if (FileName[1] = DirectorySeparator) and (FileName[2] = DirectorySeparator) then
  begin
    I := 3;
    while (I <= Length(FileName)) and (FileName[I] <> DirectorySeparator) do
      Inc(I);
    Result := Copy(FileName, 1, I - 1);
  end;
end;

function LastDelimiter(const Delimiters, S: string): Integer;
var
  I, J: Integer;
begin
  Result := 0;
  for I := Length(S) downto 1 do
    for J := 1 to Length(Delimiters) do
      if S[I] = Delimiters[J] then
        Exit(I);
end;

function StringReplace(const S, OldPattern, NewPattern: string;
  Flags: TReplaceFlags): string;
var
  I, OldLen, L: Integer;
  SearchStr, SearchOld, SubStr: string;
  Replaced: Boolean;
begin
  OldLen := Length(OldPattern);
  if OldLen = 0 then
  begin
    Result := S;
    Exit;
  end;

  if rfIgnoreCase in Flags then
  begin
    SearchStr := UpperCase(S);
    SearchOld := UpperCase(OldPattern);
  end
  else
  begin
    SearchStr := S;
    SearchOld := OldPattern;
  end;

  L := Length(S);
  Result := '';
  Replaced := False;
  I := 1;
  while I <= L do
  begin
    if (not Replaced or (rfReplaceAll in Flags))
       and (I + OldLen - 1 <= L) then
    begin
      SubStr := Copy(SearchStr, I, OldLen);
      if SubStr = SearchOld then
      begin
        Result := Result + NewPattern;
        Inc(I, OldLen);
        Replaced := True;
        if not (rfReplaceAll in Flags) then
        begin
          Result := Result + Copy(S, I, L - I + 1);
          I := L + 1;  { exit loop }
        end;
      end
      else
      begin
        Result := Result + S[I];
        Inc(I);
      end;
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

{ File search using libc opendir/readdir/closedir }

const
  DT_REG = 8;   { regular file }
  DT_DIR = 4;   { directory }
  DT_UNKNOWN = 0;

type
  { Minimal struct dirent for linux-x86_64 (280 bytes) }
  TDirent = packed record
    d_ino: QWord;        { inode number, offset 0 }
    d_off: QWord;        { offset to next dirent, offset 8 }
    d_reclen: Word;      { length of this record, offset 16 }
    d_type: Byte;        { type of file, offset 18 }
    d_name: array[0..255] of Char; { filename, offset 19 }
  end;

  { Opaque directory handle — libc DIR* }
  PDirHandle = Pointer;

{ libc functions }
function np_opendir(name: PChar): PDirHandle; cdecl; external 'c' name 'opendir';
function np_readdir(dir: PDirHandle): Pointer; cdecl; external 'c' name 'readdir';
function np_closedir(dir: PDirHandle): LongInt; cdecl; external 'c' name 'closedir';

{ Pattern matching: supports * and *.ext patterns (sufficient for compiler). }
function MatchesPattern(const AName, APattern: string): Boolean;
var
  DotPos: LongInt;
begin
  if (APattern = '*') or (APattern = '') then
    Exit(True);
  { *.ext — match extension (suffix after '*') }
  if (Length(APattern) > 1) and (APattern[1] = '*') and (APattern[2] = '.') then
  begin
    DotPos := Length(AName) - Length(APattern) + 2;
    if DotPos < 1 then
      Exit(False);
    Exit(Copy(AName, DotPos, MaxInt) = Copy(APattern, 2, MaxInt));
  end;
  { exact match }
  Result := SameText(AName, APattern);
end;

function FindFirst(const Path: string; Attr: LongInt; var F: TSearchRec): LongInt;
var
  DirPath, Name: string;
  SepPos: LongInt;
  Ent: ^TDirent;
begin
  F.Name := '';
  F.Attr := 0;
  F.Size := 0;
  F.Time := 0;
  F.FindHandle := nil;
  F.Pattern := '';

  { Split Path into directory + pattern (e.g. "/tmp/*.pas" → "/tmp" + "*.pas") }
  SepPos := Length(Path);
  while (SepPos > 0) and (Path[SepPos] <> '/') do
    Dec(SepPos);
  if SepPos > 0 then
  begin
    DirPath := Copy(Path, 1, SepPos - 1);
    F.Pattern := Copy(Path, SepPos + 1, MaxInt);
  end
  else
  begin
    DirPath := '.';
    F.Pattern := Path;
  end;
  if DirPath = '' then
    DirPath := '/';

  F.FindHandle := np_opendir(PChar(DirPath));
  if F.FindHandle = nil then
  begin
    Result := -1;
    Exit;
  end;

  { Read entries until we find a match }
  while True do
  begin
    Ent := np_readdir(F.FindHandle);
    if Ent = nil then
    begin
      np_closedir(F.FindHandle);
      F.FindHandle := nil;
      Result := -1;
      Exit;
    end;
    Name := Ent^.d_name;
    if (Name = '.') or (Name = '..') then
      Continue;
    if MatchesPattern(Name, F.Pattern) then
    begin
      F.Name := Name;
      if Ent^.d_type = DT_DIR then
        F.Attr := faDirectory
      else
        F.Attr := 0;
      F.Size := 0;
      F.Time := 0;
      Result := 0;
      Exit;
    end;
  end;
end;

function FindNext(var F: TSearchRec): LongInt;
var
  Ent: ^TDirent;
  Name: string;
begin
  if F.FindHandle = nil then
  begin
    Result := -1;
    Exit;
  end;

  while True do
  begin
    Ent := np_readdir(F.FindHandle);
    if Ent = nil then
    begin
      np_closedir(F.FindHandle);
      F.FindHandle := nil;
      Result := -1;
      Exit;
    end;
    Name := Ent^.d_name;
    if (Name = '.') or (Name = '..') then
      Continue;
    if MatchesPattern(Name, F.Pattern) then
    begin
      F.Name := Name;
      if Ent^.d_type = DT_DIR then
        F.Attr := faDirectory
      else
        F.Attr := 0;
      F.Size := 0;
      F.Time := 0;
      Result := 0;
      Exit;
    end;
  end;
end;

procedure FindClose(var F: TSearchRec);
begin
  if F.FindHandle <> nil then
  begin
    np_closedir(F.FindHandle);
    F.FindHandle := nil;
  end;
end;

{ Type conversions }

function IntToStr(Value: Integer): string;
begin
  Str(Value, Result);
end;

function IntToStr(Value: Int64): string;
begin
  Str(Value, Result);
end;

function StrToInt(const S: string): Integer;
var
  Code: Integer;
begin
  Val(S, Result, Code);
  if Code <> 0 then
    raise EConvertError.Create('Invalid integer: ' + S);
end;

function StrToIntDef(const S: string; Default: Integer): Integer;
var
  Code: Integer;
begin
  Val(S, Result, Code);
  if Code <> 0 then
    Result := Default;
end;

function StrToInt64Def(const S: string; Default: Int64): Int64;
var
  Code: Integer;
begin
  Val(S, Result, Code);
  if Code <> 0 then
    Result := Default;
end;

function TryStrToInt(const S: string; out Value: Integer): Boolean;
var
  Code: Integer;
begin
  Val(S, Value, Code);
  Result := Code = 0;
end;

function TryStrToInt64(const S: string; out Value: Int64): Boolean;
var
  Code: Integer;
begin
  Val(S, Value, Code);
  Result := Code = 0;
end;

function IntToHex(Value: Int64; Digits: Integer): string;
const
  HexChars: array[0..15] of Char = (
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
  );
var
  Buffer: string;
  UnsignedValue: QWord;
begin
  if Digits < 1 then
    Digits := 1;

  UnsignedValue := QWord(Value);
  Buffer := '';
  repeat
    Buffer := HexChars[UnsignedValue and $F] + Buffer;
    UnsignedValue := UnsignedValue shr 4;
  until UnsignedValue = 0;

  while Length(Buffer) < Digits do
    Buffer := '0' + Buffer;

  Result := Buffer;
end;

{ Environment }

function GetEnvironmentVariable(const Name: string): string;
var
  P: PChar;
begin
  P := getenv(PChar(Name));
  if P <> nil then
    Result := string(P)
  else
    Result := '';
end;

function ParamStr(Index: Integer): string;
var
  Buf: array[0..4095] of Char;
  N, I, Start, PIdx: Integer;
  Fd: LongInt;
begin
  Result := '';
  if Index < 0 then Exit;

  // ParamStr(0) = executable path via /proc/self/exe
  if Index = 0 then
  begin
    N := readlink('/proc/self/exe', @Buf[0], SizeOf(Buf) - 1);
    if N > 0 then
    begin
      Buf[N] := #0;
      Result := PChar(@Buf[0]);
    end;
    Exit;
  end;

  // ParamStr(N) for N > 0: parse /proc/self/cmdline (null-separated)
  Fd := np_open('/proc/self/cmdline', 0 { O_RDONLY });
  if Fd < 0 then Exit;
  N := np_read(Fd, @Buf[0], SizeOf(Buf) - 1);
  np_close(Fd);
  if N <= 0 then Exit;
  Buf[N] := #0;

  PIdx := 0;
  I := 0;
  while I < N do
  begin
    Start := I;
    while (I < N) and (Buf[I] <> #0) do
      Inc(I);
    if PIdx = Index then
    begin
      SetLength(Result, I - Start);
      Move(Buf[Start], Result[1], I - Start);
      Exit;
    end;
    Inc(PIdx);
    Inc(I); // skip null
  end;
end;

function ParamCount: Integer;
var
  Buf: array[0..4095] of Char;
  N, I, Cnt: Integer;
  Fd: LongInt;
begin
  Result := 0;
  Fd := np_open('/proc/self/cmdline', 0 { O_RDONLY });
  if Fd < 0 then Exit;
  N := np_read(Fd, @Buf[0], SizeOf(Buf) - 1);
  np_close(Fd);
  if N <= 0 then Exit;
  Cnt := 0;
  I := 0;
  while I < N do
  begin
    while (I < N) and (Buf[I] <> #0) do
      Inc(I);
    Inc(Cnt);
    Inc(I); // skip null
  end;
  Result := Cnt - 1; // exclude argv[0]
end;

function GetCurrentDir: string;
var
  Buf: array[0..4095] of Char;
begin
  if getcwd(@Buf[0], SizeOf(Buf)) <> nil then
    Result := string(@Buf[0])
  else
    Result := '/';
end;

{ Date/Time }

function Now: TDateTime;
begin
  // Stub implementation - returns 0
  // TODO: Implement using system calls
  Result := 0.0;
end;

function FormatDateTime(const Format: string; DateTime: TDateTime): string;
begin
  // Stub implementation - returns fixed string
  Result := '2026-05-02 00:00:00';
end;

{ String formatting }

function Format(const Fmt: string; const Args: array of const): string;
var
  I, ArgIdx: Integer;
  Buf: string;
begin
  if Length(Args) = 0 then
    Exit(Fmt);

  Result := '';
  ArgIdx := 0;
  I := 1;
  while I <= Length(Fmt) do
  begin
    if (Fmt[I] = '%') and (I < Length(Fmt)) and (ArgIdx <= High(Args)) then
    begin
      Inc(I);
      case Fmt[I] of
        'd', 'u':
          begin
            case Args[ArgIdx].VType of
              vtInteger: Buf := IntToStr(Args[ArgIdx].VInteger);
            else
              Buf := '?';
            end;
            Result := Result + Buf;
            Inc(ArgIdx);
          end;
        's':
          begin
            case Args[ArgIdx].VType of
              vtAnsiString: Buf := string(Args[ArgIdx].VAnsiString);
              vtPChar: Buf := string(Args[ArgIdx].VPChar);
            else
              Buf := '?';
            end;
            Result := Result + Buf;
            Inc(ArgIdx);
          end;
      else
        Result := Result + Fmt[I];
      end;
    end
    else
      Result := Result + Fmt[I];
    Inc(I);
  end;
end;

{ Memory management }

procedure FreeAndNil(var Obj);
var
  Temp: TObject;
begin
  Temp := TObject(Obj);
  Pointer(Obj) := nil;
  Temp.Free;
end;

function Supports(const AIntf: IInterface; const IID: TGUID; out Intf): Boolean;
var
  LTemp: IInterface;
begin
  Pointer(Intf) := nil;
  Result := (AIntf <> nil) and (AIntf.QueryInterface(IID, LTemp) = 0);
  if Result then
    Pointer(Intf) := Pointer(LTemp);
end;

end.
