{**
 * @desc I/O types for the nextPas system kernel.
 *
 * Defines Text, File, TFileRec, TTextRec, and file I/O functions.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are provided by FPC System.
 *}

const
  { File mode constants }
  fmClosed = $D7B0;
  fmInput  = $D7B1;
  fmOutput = $D7B2;
  fmInOut  = $D7B3;

  { File attribute constants }
  faReadOnly  = $00000001;
  faHidden    = $00000002;
  faSysFile   = $00000004;
  faVolumeID  = $00000008;
  faDirectory = $00000010;
  faArchive   = $00000020;
  faAnyFile   = $0000003F;

  { Seek origin constants }
  fsFromBeginning = 0;
  fsFromCurrent   = 1;
  fsFromEnd       = 2;

type
  { File record — opaque platform type }
  PFileRec = ^TFileRec;
  TFileRec = record
    Handle: LongInt;
    Mode: LongInt;
    Flags: LongInt;
    RecSize: SizeInt;
    BufSize: SizeInt;
    BufPos: SizeInt;
    BufEnd: SizeInt;
    BufPtr: PByte;
    Name: array[0..259] of AnsiChar;
  end;

  { Text record — opaque platform type }
  PTextRec = ^TTextRec;
  TTextRec = record
    Handle: LongInt;
    Mode: LongInt;
    Flags: LongInt;
    RecSize: SizeInt;
    BufSize: SizeInt;
    BufPos: SizeInt;
    BufEnd: SizeInt;
    BufPtr: PByte;
    Name: array[0..259] of AnsiChar;
    LineEnd: array[0..2] of AnsiChar;
    UserData: array[0..59] of Byte;
  end;

  { File types }
  File = file;
  Text = file of TextRec;

  { File date type }
  TFileDate = LongInt;

  { Search record }
  TSearchRec = record
    Time: LongInt;
    Size: Int64;
    Attr: LongInt;
    Name: AnsiString;
    ExcludeAttr: LongInt;
    FindHandle: Pointer;
    PlatformData: array[0..3] of Byte;
  end;

{ File I/O functions }
procedure AssignFile(var AFile: File; const AName: string); overload;
procedure AssignFile(var AText: Text; const AName: string); overload;
procedure Reset(var AFile: File); overload;
procedure Reset(var AText: Text); overload;
procedure Rewrite(var AFile: File); overload;
procedure Rewrite(var AText: Text); overload;
procedure Append(var AText: Text);
procedure CloseFile(var AFile: File); overload;
procedure CloseFile(var AText: Text); overload;
procedure Erase(var AFile: File);
procedure Rename(var AFile: File; const ANewName: string);
procedure Seek(var AFile: File; APosition: LongInt);
function FilePos(var AFile: File): LongInt;
function FileSize(var AFile: File): LongInt;
function EOF(var AFile: File): Boolean; overload;
function EOF(var AText: Text): Boolean; overload;
procedure Truncate(var AFile: File);
procedure BlockRead(var AFile: File; var ABuffer; ACount: LongInt); overload;
procedure BlockRead(var AFile: File; var ABuffer; ACount: LongInt; var AResult: LongInt); overload;
procedure BlockWrite(var AFile: File; const ABuffer; ACount: LongInt); overload;
procedure BlockWrite(var AFile: File; const ABuffer; ACount: LongInt; var AResult: LongInt); overload;

{ Text I/O functions }
procedure Read(var AText: Text; var Args); overload;
procedure ReadLn(var AText: Text); overload;
procedure ReadLn(var AText: Text; var Args); overload;
procedure Write(var AText: Text; const Args); overload;
procedure WriteLn(var AText: Text); overload;
procedure WriteLn(var AText: Text; const Args); overload;

{ Console I/O — standard handles }
var
  Input: Text;
  Output: Text;
  ErrOutput: Text;
  StdIn: Text;
  StdOut: Text;
  StdErr: Text;

implementation

{ File I/O stubs — real implementations provided by runtime }

procedure AssignFile(var AFile: File; const AName: string);
begin
  { Stub — runtime provides real implementation }
end;

procedure AssignFile(var AText: Text; const AName: string);
begin
  { Stub — runtime provides real implementation }
end;

procedure Reset(var AFile: File);
begin
  { Stub — runtime provides real implementation }
end;

procedure Reset(var AText: Text);
begin
  { Stub — runtime provides real implementation }
end;

procedure Rewrite(var AFile: File);
begin
  { Stub — runtime provides real implementation }
end;

procedure Rewrite(var AText: Text);
begin
  { Stub — runtime provides real implementation }
end;

procedure Append(var AText: Text);
begin
  { Stub — runtime provides real implementation }
end;

procedure CloseFile(var AFile: File);
begin
  { Stub — runtime provides real implementation }
end;

procedure CloseFile(var AText: Text);
begin
  { Stub — runtime provides real implementation }
end;

procedure Erase(var AFile: File);
begin
  { Stub — runtime provides real implementation }
end;

procedure Rename(var AFile: File; const ANewName: string);
begin
  { Stub — runtime provides real implementation }
end;

procedure Seek(var AFile: File; APosition: LongInt);
begin
  { Stub — runtime provides real implementation }
end;

function FilePos(var AFile: File): LongInt;
begin
  Result := 0;
end;

function FileSize(var AFile: File): LongInt;
begin
  Result := 0;
end;

function EOF(var AFile: File): Boolean;
begin
  Result := True;
end;

function EOF(var AText: Text): Boolean;
begin
  Result := True;
end;

procedure Truncate(var AFile: File);
begin
  { Stub — runtime provides real implementation }
end;

procedure BlockRead(var AFile: File; var ABuffer; ACount: LongInt);
begin
  { Stub — runtime provides real implementation }
end;

procedure BlockRead(var AFile: File; var ABuffer; ACount: LongInt; var AResult: LongInt);
begin
  AResult := 0;
end;

procedure BlockWrite(var AFile: File; const ABuffer; ACount: LongInt);
begin
  { Stub — runtime provides real implementation }
end;

procedure BlockWrite(var AFile: File; const ABuffer; ACount: LongInt; var AResult: LongInt);
begin
  AResult := 0;
end;

{ Text I/O stubs }

procedure Read(var AText: Text; var Args);
begin
  { Stub — runtime provides real implementation }
end;

procedure ReadLn(var AText: Text);
begin
  { Stub — runtime provides real implementation }
end;

procedure ReadLn(var AText: Text; var Args);
begin
  { Stub — runtime provides real implementation }
end;

procedure Write(var AText: Text; const Args);
begin
  { Stub — runtime provides real implementation }
end;

procedure WriteLn(var AText: Text);
begin
  { Stub — runtime provides real implementation }
end;

procedure WriteLn(var AText: Text; const Args);
begin
  { Stub — runtime provides real implementation }
end;
