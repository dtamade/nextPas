unit nextpas.core.sevenz.levels;

{**
 * nextpas.core.sevenz.levels - 压缩级别到引擎参数的纯映射
 *
 * 将 7z 的 TSevenZCompressionLevel 映射为 deflate/bzip2 等底层引擎
 * 的具体参数，writer 与 bench 共享同一纯函数，避免两处硬编码漂移。
 * 本单元仅依赖 nextpas.core.compress.base，不依赖 intf 的接口声明，
 * 以 Ord 方式接受级别，避免循环依赖。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.compress.base;

function SevenZLevelOrdToDeflateLevel(AOrd: Integer): TCompressionLevel; inline;
function SevenZLevelOrdToBZip2BlockSize(AOrd: Integer): Integer; inline;

implementation

function SevenZLevelOrdToDeflateLevel(AOrd: Integer): TCompressionLevel;
begin
  case AOrd of
    0: Result := clNone;    { szclNone }
    1: Result := clFastest; { szclFastest }
    3: Result := clBest;    { szclBest }
  else
    Result := clDefault;    { szclDefault }
  end;
end;

function SevenZLevelOrdToBZip2BlockSize(AOrd: Integer): Integer;
begin
  case AOrd of
    1: Result := 1; { szclFastest }
    3: Result := 9; { szclBest }
    0: Result := 1; { szclNone -> 1 (Copy 路径为主，取最小块) }
  else
    Result := 9;    { szclDefault }
  end;
end;

end.
