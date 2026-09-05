unit nextpas.core.respack.dirsource.mmap;

{** @desc dirsource mmap 单源：TryMmapRequire 零拷贝视图，单块复用。
  Not inline: try..except 不得内联（FPC 内联把 except 变量 E 带入调用方作用域，
  与调用方符号冲突致编译失败）；每文件一次调用，开销可忽略。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
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
      AMap := nil;
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
