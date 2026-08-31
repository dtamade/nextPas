unit nextpas.core.sevenz.levels;

{**
 * nextpas.core.sevenz.levels - 压缩级别到引擎参数的纯映射
 *
 * 将 7z 的 TSevenZCompressionLevel 映射为 deflate/bzip2 等底层引擎
 * 的具体参数，writer 与 bench 共享同一纯函数，避免两处硬编码漂移。
 * 本单元仅依赖 nextpas.core.compress.base，不依赖 intf 的接口声明，
 * 以 Ord 方式接受级别，避免循环依赖。映射为单源表驱动：以 Ord 为索引
 * 查表，O(1) 且分支预测稳定，bench 可观测为常数开销。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.compress.base;

function SevenZLevelOrdToDeflateLevel(AOrd: Integer): TCompressionLevel; inline;
function SevenZLevelOrdToBZip2BlockSize(AOrd: Integer): Integer; inline;

implementation

const
  { 单源表驱动：以 TSevenZCompressionLevel Ord 为索引 (0=szclNone,1=szclFastest,2=szclDefault,3=szclBest)；
    表即契约，避免枚举重排时分支漂移；查表为 O(1) 索引、分支预测稳定，bench 可观测为常数开销 }
  CSevenZDeflateLevelMap: array[0..3] of TCompressionLevel = (clNone, clFastest, clDefault, clBest);
  CSevenZBZip2BlockSizeMap: array[0..3] of Integer = (1, 1, 9, 9);

function SevenZLevelOrdToDeflateLevel(AOrd: Integer): TCompressionLevel;
begin
  if (AOrd >= Low(CSevenZDeflateLevelMap)) and (AOrd <= High(CSevenZDeflateLevelMap)) then
    Result := CSevenZDeflateLevelMap[AOrd]
  else
    Result := clDefault;
end;

function SevenZLevelOrdToBZip2BlockSize(AOrd: Integer): Integer;
begin
  if (AOrd >= Low(CSevenZBZip2BlockSizeMap)) and (AOrd <= High(CSevenZBZip2BlockSizeMap)) then
    Result := CSevenZBZip2BlockSizeMap[AOrd]
  else
    Result := 9;
end;

end.
