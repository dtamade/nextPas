unit SysUtils;

{$mode objfpc}{$H+}

interface

const
  PathDelim = '\';
  DirectorySeparator = '\';

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
    Pattern: string;
  end;

  Exception = class(TObject)
  private
    fmessage: string;
    fhelpcontext: LongInt;
  public
    constructor Create(const AMsg: string);
    property Message: string read fmessage write fmessage;
    property HelpContext: LongInt read fhelpcontext write fhelpcontext;
  end;

  ExceptClass = class of Exception;

  EConvertError = class(Exception);
  EAssertionFailed = class(Exception);

  EHeapMemoryError = class(Exception);
  EHeapException = EHeapMemoryError;
  EInvalidPointer = class(EHeapMemoryError);
  EOutOfMemory = class(EHeapMemoryError);

function Trim(const S: string): string;
function LowerCase(const S: string): string;
function UpperCase(const S: string): string;
function SameText(const S1, S2: string): Boolean;
procedure Delete(var S: string; Index, Count: Integer);
procedure Insert(const Source: string; var S: string; Index: Integer);

function FileExists(const FileName: string): Boolean;
function DirectoryExists(const Directory: string): Boolean;
function DeleteFile(const FileName: string): Boolean;
function ForceDirectories(const Dir: string): Boolean;
function ExpandFileName(const FileName: string): string;
function ExtractFileDir(const FileName: string): string;
function ExtractFileName(const FileName: string): string;
function ChangeFileExt(const FileName, Extension: string): string;
function IncludeTrailingPathDelimiter(const Path: string): string;
function ExcludeTrailingPathDelimiter(const Path: string): string;
function ExtractFileExt(const FileName: string): string;
function ExtractFileDrive(const FileName: string): string;
function LastDelimiter(const Delimiters, S: string): Integer;

function GetEnvironmentVariable(const Name: string): string;

function FindFirst(const Path: string; Attr: LongInt; var F: TSearchRec): LongInt;
function FindNext(var F: TSearchRec): LongInt;
procedure FindClose(var F: TSearchRec);

function IntToStr(Value: Integer): string;
function IntToStr(Value: Int64): string;
function StrToInt(const S: string): Integer;
function StrToIntDef(const S: string; Default: Integer): Integer;
function IntToHex(Value: Int64; Digits: Integer): string;
function TryStrToInt(const S: string; out Value: Integer): Boolean;
function TryStrToInt64(const S: string; out Value: Int64): Boolean;

function StringReplace(const S, OldPattern, NewPattern: string;
  Flags: TReplaceFlags): string;

function ParamStr(Index: Integer): string;
function ParamCount: Integer;
function GetCurrentDir: string;

function Now: TDateTime;
function FormatDateTime(const Format: string; DateTime: TDateTime): string;
function Format(const Fmt: string; const Args: array of const): string;

function Supports(const AIntf: IInterface; const IID: TGUID; out Intf): Boolean;
procedure FreeAndNil(var Obj);

implementation

{ Windows API declarations }
function GetFileAttributesA(lpFileName: PAnsiChar): LongWord; stdcall; external 'kernel32.dll' name 'GetFileAttributesA';
function GetCurrentDirectoryA(nBufferLength: LongWord; lpBuffer: PAnsiChar): LongWord; stdcall; external 'kernel32.dll' name 'GetCurrentDirectoryA';
function GetEnvironmentVariableA(lpName: PAnsiChar; lpBuffer: PAnsiChar; nSize: LongWord): LongWord; stdcall; external 'kernel32.dll' name 'GetEnvironmentVariableA';
function GetCommandLineA: PAnsiChar; stdcall; external 'kernel32.dll' name 'GetCommandLineA';
function GetModuleFileNameA(hModule: Pointer; lpFilename: PAnsiChar; nSize: LongWord): LongWord; stdcall; external 'kernel32.dll' name 'GetModuleFileNameA';

const
  INVALID_FILE_ATTRIBUTES = LongWord(-1);
  FILE_ATTRIBUTE_DIRECTORY = $10;

{ Exception }

constructor Exception.Create(const AMsg: string);
begin
  fmessage := AMsg;
  fhelpcontext := 0;
end;

{ String operations }

function Trim(const S: string): string;
var
  I, L: Integer;
begin
  L := Length(S);
  I := 1;
  while (I <= L) and (S[I] <= ' ') do Inc(I);
  if I > L then Exit('');
  while S[L] <= ' ' do Dec(L);
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
  if L <> Length(S2) then Exit(False);
  for I := 1 to L do
  begin
    C1 := S1[I]; C2 := S2[I];
    if C1 in ['a'..'z'] then C1 := Chr(Ord(C1) - 32);
    if C2 in ['a'..'z'] then C2 := Chr(Ord(C2) - 32);
    if C1 <> C2 then Exit(False);
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

{ File operations — Windows API based }

function FileExists(const FileName: string): Boolean;
var
  Attr: LongWord;
begin
  Attr := GetFileAttributesA(PAnsiChar(AnsiString(FileName)));
  Result := (Attr <> INVALID_FILE_ATTRIBUTES) and
            ((Attr and FILE_ATTRIBUTE_DIRECTORY) = 0);
end;

function DirectoryExists(const Directory: string): Boolean;
var
  Attr: LongWord;
begin
  Attr := GetFileAttributesA(PAnsiChar(AnsiString(Directory)));
  Result := (Attr <> INVALID_FILE_ATTRIBUTES) and
            ((Attr and FILE_ATTRIBUTE_DIRECTORY) <> 0);
end;

function DeleteFile(const FileName: string): Boolean;
begin
  Result := Windows.DeleteFileA(PAnsiChar(AnsiString(FileName)));
end;

function ForceDirectories(const Dir: string): Boolean;
var
  ParentDir: string;
begin
  if (Dir = '') or (Dir = '\') or (Dir = '/') then
    Exit(True);
  if DirectoryExists(Dir) then
    Exit(True);
  ParentDir := ExtractFileDir(Dir);
  if ParentDir <> Dir then
    if not ForceDirectories(ParentDir) then
      Exit(False);
  {$I-}
  MkDir(Dir);
  {$I+}
  Result := IOResult = 0;
end;

function ExpandFileName(const FileName: string): string;
var
  Buf: array[0..4095] of Char;
  N: LongWord;
begin
  N := Windows.GetFullPathNameA(PAnsiChar(AnsiString(FileName)), SizeOf(Buf), @Buf[0], nil);
  if (N > 0) and (N < SizeOf(Buf)) then
    Result := PAnsiChar(@Buf[0])
  else
    Result := FileName;
end;

function ExtractFileDir(const FileName: string): string;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and (FileName[I] in ['\', '/']) do Dec(I);
  while (I > 0) and not (FileName[I] in ['\', '/', ':']) do Dec(I);
  if (I > 0) and (FileName[I] in ['\', '/']) then
    Result := Copy(FileName, 1, I - 1)
  else if (I > 0) and (FileName[I] = ':') then
    Result := Copy(FileName, 1, I)
  else
    Result := '';
end;

function ExtractFileName(const FileName: string): string;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and not (FileName[I] in ['\', '/', ':']) do Dec(I);
  Result := Copy(FileName, I + 1, MaxInt);
end;

function ChangeFileExt(const FileName, Extension: string): string;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and (FileName[I] <> '.') and not (FileName[I] in ['\', '/', ':']) do Dec(I);
  if (I > 0) and (FileName[I] = '.') then
    Result := Copy(FileName, 1, I - 1) + Extension
  else
    Result := FileName + Extension;
end;

function IncludeTrailingPathDelimiter(const Path: string): string;
begin
  Result := Path;
  if (Result <> '') and not (Result[Length(Result)] in ['\', '/']) then
    Result := Result + '\';
end;

function ExcludeTrailingPathDelimiter(const Path: string): string;
begin
  Result := Path;
  while (Result <> '') and (Result[Length(Result)] in ['\', '/']) do
    SetLength(Result, Length(Result) - 1);
end;

function ExtractFileExt(const FileName: string): string;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and (FileName[I] <> '.') and not (FileName[I] in ['\', '/', ':']) do Dec(I);
  if (I > 0) and (FileName[I] = '.') then
    Result := Copy(FileName, I, MaxInt)
  else
    Result := '';
end;

function ExtractFileDrive(const FileName: string): string;
begin
  if (Length(FileName) >= 2) and (FileName[2] = ':') and (UpCase(FileName[1]) in ['A'..'Z']) then
    Result := Copy(FileName, 1, 2)
  else if (Length(FileName) >= 2) and (FileName[1] = '\') and (FileName[2] = '\') then
    Result := Copy(FileName, 1, 2)
  else
    Result := '';
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
  if OldLen = 0 then Exit(S);
  if rfIgnoreCase in Flags then begin SearchStr := UpperCase(S); SearchOld := UpperCase(OldPattern); end
  else begin SearchStr := S; SearchOld := OldPattern; end;
  L := Length(S); Result := ''; Replaced := False; I := 1;
  while I <= L do
  begin
    if (not Replaced or (rfReplaceAll in Flags)) and (I + OldLen - 1 <= L) then
    begin
      SubStr := Copy(SearchStr, I, OldLen);
      if SubStr = SearchOld then
      begin
        Result := Result + NewPattern; Inc(I, OldLen); Replaced := True;
        if not (rfReplaceAll in Flags) then begin Result := Result + Copy(S, I, L - I + 1); I := L + 1; end;
      end
      else begin Result := Result + S[I]; Inc(I); end;
    end
    else begin Result := Result + S[I]; Inc(I); end;
  end;
end;

{ Environment }

function GetEnvironmentVariable(const Name: string): string;
var
  Buf: array[0..4095] of Char;
  N: LongWord;
begin
  N := GetEnvironmentVariableA(PAnsiChar(AnsiString(Name)), @Buf[0], SizeOf(Buf));
  if N > 0 then
    Result := Copy(PAnsiChar(@Buf[0]), 1, N)
  else
    Result := '';
end;

{ Command line — simplified for Windows }

function ParamStr(Index: Integer): string;
var
  CmdLine: PAnsiChar;
  P: PAnsiChar;
  I: Integer;
  InQuote: Boolean;
  Buf: string;
begin
  Result := '';
  if Index < 0 then Exit;
  CmdLine := GetCommandLineA;
  P := CmdLine;
  I := 0;
  InQuote := False;
  Buf := '';
  while P^ <> #0 do
  begin
    if P^ = '"' then
      InQuote := not InQuote
    else if (P^ = ' ') and not InQuote then
    begin
      if Buf <> '' then
      begin
        if I = Index then begin Result := Buf; Exit; end;
        Inc(I);
        Buf := '';
      end;
    end
    else
      Buf := Buf + P^;
    Inc(P);
  end;
  if (Buf <> '') and (I = Index) then
    Result := Buf;
end;

function ParamCount: Integer;
var
  CmdLine: PAnsiChar;
  P: PAnsiChar;
  Cnt: Integer;
  InQuote: Boolean;
  InWord: Boolean;
begin
  CmdLine := GetCommandLineA;
  P := CmdLine;
  Cnt := 0;
  InQuote := False;
  InWord := False;
  while P^ <> #0 do
  begin
    if P^ = '"' then
      InQuote := not InQuote
    else if (P^ = ' ') and not InQuote then
    begin
      if InWord then begin Inc(Cnt); InWord := False; end;
    end
    else
      InWord := True;
    Inc(P);
  end;
  if InWord then Inc(Cnt);
  Result := Cnt - 1; { exclude argv[0] }
end;

function GetCurrentDir: string;
var
  Buf: array[0..4095] of Char;
  N: LongWord;
begin
  N := GetCurrentDirectoryA(SizeOf(Buf), @Buf[0]);
  if N > 0 then
    Result := PAnsiChar(@Buf[0])
  else
    Result := '\';
end;

{ FindFirst/FindNext — simplified stub }

function FindFirst(const Path: string; Attr: LongInt; var F: TSearchRec): LongInt;
begin
  F.Name := '';
  F.Attr := 0;
  F.Size := 0;
  F.Time := 0;
  F.FindHandle := nil;
  F.Pattern := Path;
  Result := -1; { stub: no files found }
end;

function FindNext(var F: TSearchRec): LongInt;
begin
  Result := -1;
end;

procedure FindClose(var F: TSearchRec);
begin
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
  if Code <> 0 then raise EConvertError.Create('Invalid integer: ' + S);
end;

function StrToIntDef(const S: string; Default: Integer): Integer;
var
  Code: Integer;
begin
  Val(S, Result, Code);
  if Code <> 0 then Result := Default;
end;

function IntToHex(Value: Int64; Digits: Integer): string;
const
  HexChars: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
var
  Buf: string;
  UV: QWord;
begin
  if Digits < 1 then Digits := 1;
  UV := QWord(Value); Buf := '';
  repeat Buf := HexChars[UV and $F] + Buf; UV := UV shr 4; until UV = 0;
  while Length(Buf) < Digits do Buf := '0' + Buf;
  Result := Buf;
end;

function TryStrToInt(const S: string; out Value: Integer): Boolean;
var Code: Integer; begin Val(S, Value, Code); Result := Code = 0; end;

function TryStrToInt64(const S: string; out Value: Int64): Boolean;
var Code: Integer; begin Val(S, Value, Code); Result := Code = 0; end;

{ Date/Time stubs }

function Now: TDateTime;
begin
  Result := 0.0;
end;

function FormatDateTime(const Format: string; DateTime: TDateTime): string;
begin
  Result := '2026-01-01 00:00:00';
end;

function Format(const Fmt: string; const Args: array of const): string;
var
  I, ArgIdx: Integer;
  Buf: string;
begin
  if Length(Args) = 0 then Exit(Fmt);
  Result := ''; ArgIdx := 0; I := 1;
  while I <= Length(Fmt) do
  begin
    if (Fmt[I] = '%') and (I < Length(Fmt)) and (ArgIdx <= High(Args)) then
    begin
      Inc(I);
      case Fmt[I] of
        'd','u': begin case Args[ArgIdx].VType of vtInteger: Buf := IntToStr(Args[ArgIdx].VInteger); else Buf := '?'; end; Result := Result + Buf; Inc(ArgIdx); end;
        's': begin case Args[ArgIdx].VType of vtAnsiString: Buf := string(Args[ArgIdx].VAnsiString); vtPChar: Buf := string(Args[ArgIdx].VPChar); else Buf := '?'; end; Result := Result + Buf; Inc(ArgIdx); end;
      else Result := Result + Fmt[I];
      end;
    end
    else Result := Result + Fmt[I];
    Inc(I);
  end;
end;

{ Memory management }

procedure FreeAndNil(var Obj);
var Temp: TObject;
begin
  Temp := TObject(Obj);
  Pointer(Obj) := nil;
  Temp.Free;
end;

function Supports(const AIntf: IInterface; const IID: TGUID; out Intf): Boolean;
var LTemp: IInterface;
begin
  Pointer(Intf) := nil;
  Result := (AIntf <> nil) and (AIntf.QueryInterface(IID, LTemp) = 0);
  if Result then Pointer(Intf) := Pointer(LTemp);
end;

end.
