program demo_asset_embed;
{$I nextpas.core.settings.inc}
{** @desc S4 示例：前端资源嵌入的最小 consumer。
  构建期：wwwroot/ 经 rp_pack 打包并生成 assets_respack.inc（typed const）编入本程序；
  运行期：同一份 consumer 代码在两种后端上跑——
    --prod（默认）：CreateEmbeddedVfsBorrowed，零拷贝读 const 数组里的 pack blob；
    --dev        ：CreateOsVfs('wwwroot')，直接读磁盘目录，改完刷新即生效。
  这就是"开发态/发布态切换"：差异被收在装配一行，下游只认 IVfs。 }
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.vfs;

{$I assets_respack.inc}   { DEMO_ASSETS / DEMO_ASSETS_SIZE }

{ --dev 的根目录：默认 wwwroot（相对 CWD），可传第二参数覆盖 }
function DevRoot: string;
begin
  if ParamStr(2) <> '' then
    Result := ParamStr(2)
  else
    Result := 'wwwroot';
end;

procedure ServeAssets(const AFs: IVfs; const ALabelName: string);
var
  IndexHtml: string;
begin
  WriteLn('backend: ', ALabelName);
  WriteLn('case-sensitive: ', AFs.CaseSensitive);
  VfsWalk(AFs, '.',
    procedure(const APath: string; const AInfo: TEntryInfo;
      var AStop: Boolean)
    begin
      WriteLn('  asset: /', APath, '  (', AInfo.Size, ' bytes)');
    end);
  if not AFs.Exists('index.html') then
    raise EVfsError.Create('index.html missing in backend');
  IndexHtml := VfsReadAllText(AFs, 'index.html');
  WriteLn('--- index.html ---');
  WriteLn(IndexHtml);
end;

var
  Mode: string;
begin
  try
    Mode := ParamStr(1);
    if Mode = '--dev' then
      ServeAssets(CreateOsVfs(DevRoot), 'os (dev, reads ' + DevRoot + '/)')
    else
      ServeAssets(
        CreateEmbeddedVfsBorrowed(@DEMO_ASSETS[0], SizeUInt(DEMO_ASSETS_SIZE)),
        'embedded (prod, serves in-blob pack)');
  except
    on E: Exception do
    begin
      WriteLn('demo: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
