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
    property Message: string read FMessage;
  end;

  EConvertError = class(Exception);

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
function ExpandFileName(const FileName: string): string;
function ExtractFileDir(const FileName: string): string;
function ExtractFileName(const FileName: string): string;
function ChangeFileExt(const FileName, Extension: string): string;
function IncludeTrailingPathDelimiter(const Path: string): string;
function ExcludeTrailingPathDelimiter(const Path: string): string;

// File search
function FindFirst(const Path: string; Attr: LongInt; var F: TSearchRec): LongInt;
function FindNext(var F: TSearchRec): LongInt;
procedure FindClose(var F: TSearchRec);

// Type conversions
function IntToStr(Value: Integer): string;
function StrToInt(const S: string): Integer;
function StrToIntDef(const S: string; Default: Integer): Integer;

implementation

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
  F: File;
begin
  // Try to open as file first
  Assign(F, Directory);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult = 0 then
  begin
    Close(F);
    Result := False; // It's a file, not a directory
    Exit;
  end;

  // If we can't open it as a file, check if it's a directory
  // by trying to access a non-existent file inside it
  Assign(F, Directory + '/.nextpas_dir_test_' + IntToStr(Random(99999)));
  {$I-}
  Reset(F);
  {$I+}
  // If we get "file not found" error, the directory exists
  // If we get "path not found" error, the directory doesn't exist
  Result := (IOResult = 2); // Error 2 = file not found (directory exists)
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

end.
