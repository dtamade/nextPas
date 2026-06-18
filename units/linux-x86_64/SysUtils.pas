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

function FileExists(const FileName: string): Boolean;
var
  F: File;
begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  Result := IOResult = 0;
  if Result then
    Close(F);
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

{ TODO: FileAge stub — returns 0 (exists) or -1 (not found).
  Standard FPC FileAge returns the file's last modification time as a
  Unix timestamp. This stub is sufficient for self-hosting because the
  compiler only uses FileAge to check if a cached unit needs recompilation
  (FileAge > 0 means "file changed"). A proper implementation should use
  fpStat from BaseUnix to return the real st_mtime. }
function FileAge(const FileName: string): LongInt;
begin
  if FileExists(FileName) then
    Result := 0
  else
    Result := -1;
end;

function ExpandFileName(const FileName: string): string;
begin
  // Simple implementation: if it starts with /, it's already absolute
  if (FileName <> '') and (FileName[1] = '/') then
    Exit(FileName);

  // Otherwise, we can't expand it without getcwd
  // For now, just return as-is
  // TODO: Implement proper getcwd support
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

{ File search - simplified stub implementation }
{ TODO: Implement proper file search using system calls }

function FindFirst(const Path: string; Attr: LongInt; var F: TSearchRec): LongInt;
begin
  // Stub implementation - always returns "not found"
  F.Name := '';
  F.Attr := 0;
  F.Size := 0;
  F.Time := 0;
  F.FindHandle := nil;
  Result := -1; // Error: no files found
end;

function FindNext(var F: TSearchRec): LongInt;
begin
  // Stub implementation - always returns "no more files"
  Result := -1;
end;

procedure FindClose(var F: TSearchRec);
begin
  // Stub implementation - nothing to close
  F.FindHandle := nil;
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

end.
