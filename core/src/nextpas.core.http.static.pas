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
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.http.base;

{ ===== Helpers ===== }

function ExtractExt(const APath: string): string;
var
  LI: SizeInt;
begin
  for LI := Length(APath) downto 1 do
  begin
    if APath[LI] = '.' then
      Exit(Copy(APath, LI, Length(APath) - LI + 1));
    if APath[LI] = '/' then
      Exit('');
  end;
  Result := '';
end;

function MimeTypeFromExt(const AExt: string): string;
begin
  if AExt = '.html' then Result := 'text/html'
  else if AExt = '.htm' then Result := 'text/html'
  else if AExt = '.css' then Result := 'text/css'
  else if AExt = '.js' then Result := 'application/javascript'
  else if AExt = '.json' then Result := 'application/json'
  else if AExt = '.png' then Result := 'image/png'
  else if AExt = '.jpg' then Result := 'image/jpeg'
  else if AExt = '.jpeg' then Result := 'image/jpeg'
  else if AExt = '.gif' then Result := 'image/gif'
  else if AExt = '.svg' then Result := 'image/svg+xml'
  else if AExt = '.txt' then Result := 'text/plain'
  else if AExt = '.xml' then Result := 'application/xml'
  else if AExt = '.pdf' then Result := 'application/pdf'
  else if AExt = '.wasm' then Result := 'application/wasm'
  else if AExt = '.ico' then Result := 'image/x-icon'
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
  LContent: string;
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
  LContent := nextpas.core.fs.ReadFileText(AFilePath);
  LExt := ExtractExt(AFilePath);
  LMime := MimeTypeFromExt(LExt);
  AW.GetHeaders.Set_('content-type', LMime);
  AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LContent))));
  AW.WriteHeader(HTTP_STATUS_OK);
  if Length(LContent) > 0 then
    AW.Write(LContent[1], SizeUInt(Length(LContent)));
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
      LRelative := AReq.Url.Path;
      { Strip leading slash }
      if (Length(LRelative) > 0) and (LRelative[1] = '/') then
        LRelative := Copy(LRelative, 2, Length(LRelative) - 1);
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
