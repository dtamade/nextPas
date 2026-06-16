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
  nextpas.core.fs.base,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.io,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.url;

type
  TResponseWriterAdapter = class(TInterfacedObject, IWriter)
  private
    FWriter: IHttpResponseWriter;
  public
    constructor Create(const AWriter: IHttpResponseWriter);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

{ ===== Helpers ===== }

constructor TResponseWriterAdapter.Create(const AWriter: IHttpResponseWriter);
begin
  inherited Create;
  FWriter := AWriter;
end;

function TResponseWriterAdapter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FWriter.Write(ABuf, ACount);
end;

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

{ Returns True if the relative path is safe (no traversal). }
function IsSafePath(const ARelative: string): Boolean;
var
  LI, LLen: SizeInt;
begin
  LLen := Length(ARelative);
  if LLen = 0 then Exit(False);
  { Reject absolute paths }
  if ARelative[1] = '/' then Exit(False);
  { Reject Windows path separators before file lookup. }
  for LI := 1 to LLen do
    if ARelative[LI] = '\' then
      Exit(False);
  { Reject any '..' component }
  LI := 1;
  while LI <= LLen do
  begin
    if (ARelative[LI] = '.') and (LI + 1 <= LLen) and (ARelative[LI + 1] = '.') then
    begin
      { Check it's a full component: at start or after '/', and at end or before '/' }
      if ((LI = 1) or (ARelative[LI - 1] = '/')) and
         ((LI + 2 > LLen) or (ARelative[LI + 2] = '/')) then
        Exit(False);
    end;
    Inc(LI);
  end;
  Result := True;
end;

procedure ServeFileContent(const AFilePath: string; const AW: IHttpResponseWriter);
var
  LFile: IFile;
  LInfo: TFileInfo;
  LWriter: IWriter;
  LExt: string;
  LMime: string;
begin
  if not nextpas.core.fs.Exists(AFilePath) then
  begin
    AW.GetHeaders.Set_('content-length', '9');
    AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    AW.Write(PAnsiChar('Not Found')^, 9);
    Exit;
  end;
  LInfo := nextpas.core.fs.Stat(AFilePath);
  if LInfo.FileType <> ftRegular then
  begin
    AW.GetHeaders.Set_('content-length', '9');
    AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    AW.Write(PAnsiChar('Not Found')^, 9);
    Exit;
  end;
  LFile := nextpas.core.fs.Open(AFilePath, [fmRead]);
  LExt := ExtractExt(AFilePath);
  LMime := MimeTypeFromExt(LExt);
  AW.GetHeaders.Set_('content-type', LMime);
  AW.GetHeaders.Set_('content-length', IntToStr(LInfo.Size));
  AW.WriteHeader(HTTP_STATUS_OK);
  LWriter := TResponseWriterAdapter.Create(AW);
  nextpas.core.io.Copy(LWriter, LFile);
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
    try
      LRelative := nextpas.core.http.url.UrlDecode(LRelative);
    except
      AW.GetHeaders.Set_('content-length', '11');
      AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      AW.Write(PAnsiChar('Bad Request')^, 11);
      Exit;
    end;
    { Security: reject traversal attempts }
    if not IsSafePath(LRelative) then
    begin
      AW.GetHeaders.Set_('content-length', '11');
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
