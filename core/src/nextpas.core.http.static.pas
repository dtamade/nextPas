unit nextpas.core.http.static;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{ Serve a single file. Returns handler that reads file and writes it as response. }
function ServeFile(const APath: string): THttpHandlerFunc;

{ Serve files from a directory. Path param 'filepath' or URL path used as relative file path.
  Example: router.Get('/static/*filepath', ServeDir('/var/www')) }
function ServeDir(const ARoot: string): THttpHandlerFunc;

implementation

uses
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.io.intf,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.fs.base,
  nextpas.core.http.base,
  nextpas.core.http.url;

{ ===== Writer adapter: bridge IHttpResponseWriter to IWriter ===== }

type
  TResponseWriterAdapter = class(TInterfacedObject, IWriter)
  private
    FWriter: IHttpResponseWriter;
  public
    constructor Create(const AWriter: IHttpResponseWriter);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TResponseWriterAdapter.Create(const AWriter: IHttpResponseWriter);
begin
  inherited Create;
  FWriter := AWriter;
end;

function TResponseWriterAdapter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FWriter.Write(ABuf, ACount);
end;

{ ===== Helpers ===== }

function ExtractExt(const APath: string): string;
var
  LI: SizeInt;
begin
  for LI := Length(APath) downto 1 do
  begin
    if APath[LI] = '.' then
      Exit(System.Copy(APath, LI, Length(APath) - LI + 1));
    if APath[LI] = '/' then
      Exit('');
  end;
  Result := '';
end;

function MimeTypeFromExt(const AExt: string): string;
var
  LExt: string;
begin
  LExt := LowerCase(AExt);
  if LExt = '.html' then Result := 'text/html'
  else if LExt = '.htm' then Result := 'text/html'
  else if LExt = '.css' then Result := 'text/css'
  else if LExt = '.js' then Result := 'application/javascript'
  else if LExt = '.json' then Result := 'application/json'
  else if LExt = '.png' then Result := 'image/png'
  else if LExt = '.jpg' then Result := 'image/jpeg'
  else if LExt = '.jpeg' then Result := 'image/jpeg'
  else if LExt = '.gif' then Result := 'image/gif'
  else if LExt = '.svg' then Result := 'image/svg+xml'
  else if LExt = '.txt' then Result := 'text/plain'
  else if LExt = '.xml' then Result := 'application/xml'
  else if LExt = '.pdf' then Result := 'application/pdf'
  else if LExt = '.wasm' then Result := 'application/wasm'
  else if LExt = '.ico' then Result := 'image/x-icon'
  else Result := 'application/octet-stream';
end;

{ Returns True if the relative path is safe (no traversal).
  Hardened: URL-decodes first, replaces backslashes, normalizes with PathClean,
  then checks the result does not escape the root. }
function IsSafePath(const ARelative: string): Boolean;
var
  LDecoded: string;
  LNormalized: string;
  LI: SizeInt;
begin
  if Length(ARelative) = 0 then Exit(False);
  { Reject absolute paths }
  if ARelative[1] = '/' then Exit(False);
  { URL decode to prevent %2e%2e bypass }
  try
    LDecoded := UrlDecode(ARelative);
  except
    Exit(False);
  end;
  { Replace backslashes to prevent Windows-style traversal }
  for LI := 1 to Length(LDecoded) do
    if LDecoded[LI] = '\' then
      LDecoded[LI] := '/';
  { Normalize path: resolves . and .. segments }
  LNormalized := nextpas.core.fs.PathClean(LDecoded);
  { Reject if normalization produced an absolute path }
  if (Length(LNormalized) > 0) and (LNormalized[1] = '/') then Exit(False);
  { Reject if normalization still starts with .. }
  if (Length(LNormalized) >= 2) and (LNormalized[1] = '.') and (LNormalized[2] = '.') then
  begin
    if (Length(LNormalized) = 2) or (LNormalized[3] = '/') then
      Exit(False);
  end;
  Result := True;
end;

procedure ServeFileContent(const AFilePath: string; const AW: IHttpResponseWriter);
var
  LFile: nextpas.core.fs.IFile;
  LSize: Int64;
  LExt: string;
  LMime: string;
  LAdapter: IWriter;
  LInfo: TFileInfo;
begin
  { Open first to avoid TOCTOU: we get a consistent view of the file. }
  try
    LFile := nextpas.core.fs.Open(AFilePath, [fmRead]);
  except
    AW.GetHeaders.SetHeader('content-length', '9');
    AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    AW.Write(PAnsiChar('Not Found')^, 9);
    Exit;
  end;
  try
    { Reject symlinks, directories, and other non-regular files }
    LInfo := LFile.Stat;
    if LInfo.FileType <> ftRegular then
    begin
      AW.GetHeaders.SetHeader('content-length', '9');
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
      AW.Write(PAnsiChar('Not Found')^, 9);
      Exit;
    end;
    LSize := LInfo.Size;
    LExt := ExtractExt(AFilePath);
    LMime := MimeTypeFromExt(LExt);
    AW.GetHeaders.SetHeader('content-type', LMime);
    AW.GetHeaders.SetHeader('content-length', IntToStr(LSize));
    AW.WriteHeader(HTTP_STATUS_OK);
    LAdapter := TResponseWriterAdapter.Create(AW);
    nextpas.core.io.Copy(LAdapter, LFile as IReader);
  finally
    LFile.Close;
  end;
end;

{ ===== Public API ===== }

function ServeFile(const APath: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    ServeFileContent(APath, AW);
  end;
end;

function ServeDir(const ARoot: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LRelative: string;
    LFullPath: string;
  begin
    { Try wildcard param first, fall back to URL path }
    LRelative := AReq.PathParam('filepath');
    if LRelative = '' then
    begin
      LRelative := AReq.Path;
      { Strip leading slash }
      if (Length(LRelative) > 0) and (LRelative[1] = '/') then
        LRelative := System.Copy(LRelative, 2, Length(LRelative) - 1);
    end;
    { Security: reject traversal attempts }
    if not IsSafePath(LRelative) then
    begin
      AW.GetHeaders.SetHeader('content-length', '11');
      AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      AW.Write(PAnsiChar('Bad Request')^, 11);
      Exit;
    end;
    { Build full path }
    LFullPath := ARoot + '/' + LRelative;
    ServeFileContent(LFullPath, AW);
  end;
end;

end.
