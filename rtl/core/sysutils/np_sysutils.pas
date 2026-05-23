unit SysUtils;

{$mode objfpc}{$H+}

interface

const
  PathDelim = '/';
  DirectorySeparator = '/';

  faAnyFile = $0000003F;
  faDirectory = $00000010;

type
  TStringArray = array of string;

  TDateTime = Double;

  TSearchRec = record
    Name: string;
    Attr: LongInt;
    Size: Int64;
    Time: LongInt;
    FindHandle: Pointer;
    FilterPattern: string;
    SearchDir: string;
  end;

  Exception = class
  private
    FMessage: string;
  public
    constructor Create(const Msg: string);
    property Message: string read FMessage;
  end;

  EConvertError = class(Exception)
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
function StrToInt(const S: string): Integer;
function StrToIntDef(const S: string; Default: Integer): Integer;

// Date/Time
function Now: TDateTime;
function FormatDateTime(const Format: string; DateTime: TDateTime): string;

// String formatting
function Format(const Fmt: string; const Args: array of const): string;

// Memory management
procedure FreeAndNil(var Obj);

implementation

uses
  BaseUnix;

{ C library functions for features not in BaseUnix }

function c_gettimeofday(tv: Pointer; tz: Pointer): LongInt; cdecl;
  external 'c' name 'gettimeofday';

type
  PTmStruct = ^TTmStruct;
  TTmStruct = record
    tm_sec: LongInt;
    tm_min: LongInt;
    tm_hour: LongInt;
    tm_mday: LongInt;
    tm_mon: LongInt;
    tm_year: LongInt;
    tm_wday: LongInt;
    tm_yday: LongInt;
    tm_isdst: LongInt;
  end;

function c_localtime(t: Pointer): PTmStruct; cdecl;
  external 'c' name 'localtime';

{ Exception }

constructor Exception.Create(const Msg: string);
begin
  inherited Create;
  FMessage := Msg;
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
begin
  Result := LowerCase(S1) = LowerCase(S2);
end;

procedure Delete(var S: string; Index, Count: Integer);
begin
  System.Delete(S, Index, Count);
end;

procedure Insert(const Source: string; var S: string; Index: Integer);
begin
  System.Insert(Source, S, Index);
end;

{ File operations - using FpStat for reliability }

function FileExists(const FileName: string): Boolean;
var
  Info: BaseUnix.Stat;
begin
  Result := (FpStat(FileName, Info) = 0) and
    ((Info.st_mode and S_IFMT) <> S_IFDIR);
end;

function DirectoryExists(const Directory: string): Boolean;
var
  Info: BaseUnix.Stat;
begin
  Result := (FpStat(Directory, Info) = 0) and
    ((Info.st_mode and S_IFMT) = S_IFDIR);
end;

function DeleteFile(const FileName: string): Boolean;
begin
  Result := FpUnlink(FileName) = 0;
end;

function FileSearch(const Name, DirList: string): string;
var
  StartPos, EndPos: Integer;
  Dir, TestPath: string;
begin
  if (Length(Name) > 0) and (Name[1] = '/') then
  begin
    if FileExists(Name) then
      Exit(Name)
    else
      Exit('');
  end;

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

  Result := '';
end;

function ForceDirectories(const Dir: string): Boolean;
var
  ParentDir: string;
begin
  if (Dir = '') or (Dir = '/') then
  begin
    Result := True;
    Exit;
  end;

  if DirectoryExists(Dir) then
  begin
    Result := True;
    Exit;
  end;

  ParentDir := ExtractFileDir(Dir);
  if ParentDir <> Dir then
  begin
    if not ForceDirectories(ParentDir) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := FpMkdir(Dir, &755) = 0;
end;

function ExpandFileName(const FileName: string): string;
var
  Cwd: string;
begin
  if FileName = '' then
    Exit('');

  if FileName[1] = '/' then
    Exit(FileName);

  GetDir(0, Cwd);
  Result := IncludeTrailingPathDelimiter(Cwd) + FileName;
end;

function ExtractFileDir(const FileName: string): string;
var
  I: Integer;
  Tmp: string;
  HasTrailingSlash: Boolean;
begin
  if FileName = '' then
    Exit('');

  HasTrailingSlash := FileName[Length(FileName)] = '/';

  // If path ends with '/', strip it and treat as directory path
  if HasTrailingSlash and (Length(FileName) > 1) then
  begin
    Tmp := FileName;
    SetLength(Tmp, Length(Tmp) - 1);
    Exit(Tmp);
  end;

  // No trailing slash: find last '/' and return everything before it
  I := Length(FileName);
  while (I > 0) and (FileName[I] <> '/') do
    Dec(I);

  if I <= 0 then
    Exit('');
  if I = 1 then
    Exit('/');

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
  if Path = '' then
    Exit('/');
  Result := Path;
  if Result[Length(Result)] <> '/' then
    Result := Result + '/';
end;

function ExcludeTrailingPathDelimiter(const Path: string): string;
begin
  Result := Path;
  while (Result <> '') and (Result[Length(Result)] = '/') do
    SetLength(Result, Length(Result) - 1);
end;

{ Glob-style pattern matching for FindFirst }

function GlobMatch(const Pattern, Name: string): Boolean;
var
  PI, NI: Integer;
  StarPI, StarNI: Integer;
begin
  if (Pattern = '') and (Name = '') then
    Exit(True);
  if Pattern = '*' then
    Exit(True);

  PI := 1;
  NI := 1;
  StarPI := 0;
  StarNI := 0;

  while NI <= Length(Name) do
  begin
    if (PI <= Length(Pattern)) and
      ((Pattern[PI] = Name[NI]) or (Pattern[PI] = '?')) then
    begin
      Inc(PI);
      Inc(NI);
    end
    else if (PI <= Length(Pattern)) and (Pattern[PI] = '*') then
    begin
      StarPI := PI;
      StarNI := NI;
      Inc(PI);
    end
    else if StarPI > 0 then
    begin
      PI := StarPI + 1;
      StarNI := StarNI + 1;
      NI := StarNI;
    end
    else
      Exit(False);
  end;

  while (PI <= Length(Pattern)) and (Pattern[PI] = '*') do
    Inc(PI);

  Result := PI > Length(Pattern);
end;

{ File search using BaseUnix FpOpenDir/FpReadDir/FpCloseDir }

function FindFirst(const Path: string; Attr: LongInt; var F: TSearchRec): LongInt;
var
  DirPath, Pattern: string;
  DirPtr: pDir;
  Entry: pDirEnt;
  Info: BaseUnix.Stat;
  FullPath: string;
begin
  F.Name := '';
  F.Attr := 0;
  F.Size := 0;
  F.Time := 0;
  F.FindHandle := nil;
  F.FilterPattern := '';
  F.SearchDir := '';

  DirPath := ExtractFileDir(Path);
  if DirPath = '' then
    DirPath := '.';

  Pattern := ExtractFileName(Path);
  if Pattern = '' then
    Pattern := '*';
  F.FilterPattern := Pattern;
  F.SearchDir := DirPath;

  DirPtr := FpOpenDir(DirPath);
  if DirPtr = nil then
    Exit(-1);

  Entry := FpReadDir(DirPtr^);
  while Entry <> nil do
  begin
    if (Entry^.d_name <> '.') and (Entry^.d_name <> '..') then
    begin
      if GlobMatch(Pattern, Entry^.d_name) then
      begin
        F.Name := Entry^.d_name;
        F.FindHandle := DirPtr;
        FullPath := IncludeTrailingPathDelimiter(DirPath) + F.Name;
        if FpStat(FullPath, Info) = 0 then
        begin
          if (Info.st_mode and S_IFMT) = S_IFDIR then
            F.Attr := faDirectory
          else
            F.Attr := 0;
          F.Size := Info.st_size;
          F.Time := Info.st_ctime;
        end;
        Exit(0);
      end;
    end;
    Entry := FpReadDir(DirPtr^);
  end;

  FpCloseDir(DirPtr^);
  Exit(-1);
end;

function FindNext(var F: TSearchRec): LongInt;
var
  DirPtr: pDir;
  Entry: pDirEnt;
  Info: BaseUnix.Stat;
  FullPath: string;
begin
  DirPtr := pDir(F.FindHandle);
  if DirPtr = nil then
    Exit(-1);

  Entry := FpReadDir(DirPtr^);
  while Entry <> nil do
  begin
    if (Entry^.d_name <> '.') and (Entry^.d_name <> '..') then
    begin
      if GlobMatch(F.FilterPattern, Entry^.d_name) then
      begin
        F.Name := Entry^.d_name;
        F.Attr := 0;
        F.Size := 0;
        F.Time := 0;
        if F.SearchDir <> '' then
        begin
          FullPath := IncludeTrailingPathDelimiter(F.SearchDir) + F.Name;
          if FpStat(FullPath, Info) = 0 then
          begin
            if (Info.st_mode and S_IFMT) = S_IFDIR then
              F.Attr := faDirectory;
            F.Size := Info.st_size;
            F.Time := Info.st_ctime;
          end;
        end;
        Exit(0);
      end;
    end;
    Entry := FpReadDir(DirPtr^);
  end;

  FpCloseDir(DirPtr^);
  F.FindHandle := nil;
  Result := -1;
end;

procedure FindClose(var F: TSearchRec);
var
  DirPtr: pDir;
begin
  if F.FindHandle <> nil then
  begin
    DirPtr := pDir(F.FindHandle);
    FpCloseDir(DirPtr^);
    F.FindHandle := nil;
  end;
end;

{ Type conversions }

function IntToStr(Value: Integer): string;
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

{ Environment }

function GetEnvironmentVariable(const Name: string): string;
var
  P: PChar;
begin
  P := FpGetEnv(PChar(Name));
  if P <> nil then
    Result := string(P)
  else
    Result := '';
end;

{ Date/Time using C library }

function Now: TDateTime;
var
  TV: record tv_sec: Int64; tv_usec: Int64; end;
begin
  c_gettimeofday(@TV, nil);
  Result := TV.tv_sec / 86400.0 + 25569.0;
end;

function FormatDateTime(const Format: string; DateTime: TDateTime): string;
var
  EpochSecs: Int64;
  PTM: PTmStruct;
  Year, Month, Day, Hour, Min, Sec: string;
begin
  EpochSecs := Trunc((DateTime - 25569.0) * 86400.0);
  PTM := c_localtime(@EpochSecs);
  if PTM = nil then
    Exit('1970-01-01 00:00:00');

  Year := IntToStr(PTM^.tm_year + 1900);
  Month := IntToStr(PTM^.tm_mon + 1);
  Day := IntToStr(PTM^.tm_mday);
  Hour := IntToStr(PTM^.tm_hour);
  Min := IntToStr(PTM^.tm_min);
  Sec := IntToStr(PTM^.tm_sec);

  if Pos('yyyy', Format) > 0 then
    Result := Year + '-' + Month + '-' + Day + ' ' + Hour + ':' + Min + ':' + Sec
  else if Pos('yy', Format) > 0 then
    Result := Copy(Year, 3, 2) + '-' + Month + '-' + Day
  else
    Result := Year + '-' + Month + '-' + Day;
end;

{ String formatting - minimal implementation }

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
