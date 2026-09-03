unit nextpas.core.respack.dirsource.mmap;

{** @desc dirsource mmap 单源：TryMmapRequire 零拷贝视图，单块复用。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.mapped;

function TryMmapRequire(const APath: string; const AStatSize: Int64; out AMap: IMappedFile; out AErrMsg: string): Boolean;

implementation

uses
  nextpas.core.text.conv;

function TryMmapRequire(const APath: string; const AStatSize: Int64; out AMap: IMappedFile; out AErrMsg: string): Boolean;
begin
  AMap := nil;
  AErrMsg := '';
  if AStatSize = 0 then Exit(True);
  try
    AMap := MmapOpen(APath);
    if (AMap = nil) or (AMap.Size = 0) or (AMap.Data = nil) then
    begin
      if AStatSize <> 0 then
      begin
        AErrMsg := 'mmap failed: empty mapping for non-empty file (path=' + APath + ')';
        AMap := nil;
        Exit(False);
      end;
      AMap := nil;
    end
    else if SizeUInt(AMap.Size) <> SizeUInt(AStatSize) then
    begin
      AErrMsg := 'mmap size mismatch: stat=' + IntToStr(AStatSize) + ' cmap=' + IntToStr(AMap.Size) + ' (path=' + APath + ')';
      Exit(False);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      AErrMsg := 'mmap failed: ' + E.Message + ' (path=' + APath + ')';
      AMap := nil;
      Result := False;
    end;
  end;
end;

end.
