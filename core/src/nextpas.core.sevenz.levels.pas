unit nextpas.core.sevenz.levels;

{**
 * nextpas.core.sevenz.levels - 压缩级别到引擎参数的纯映射
 *
 * 将 7z 的 TSevenZCompressionLevel 映射为 deflate/bzip2 等底层引擎
 * 的具体参数，writer/bench/facade 共享同一纯函数，避免两处硬编码漂移。
 * Ord 入口保持单源表驱动 (O(1) 索引、分支预测稳定、bench 可观测)；
 * typed 重载以 intf 枚举直连 Facade，门面零 Ord 薄逻辑、纯 inline forward。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.compress.base,
  nextpas.core.sevenz.intf;

function SevenZLevelOrdToDeflateLevel(AOrd: Integer): TCompressionLevel; inline;
function SevenZLevelOrdToBZip2BlockSize(AOrd: Integer): Integer; inline;
function SevenZLevelToDeflateLevel(ALevel: TSevenZCompressionLevel): TCompressionLevel; inline;
function SevenZLevelToBZip2BlockSize(ALevel: TSevenZCompressionLevel): Integer; inline;

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

function SevenZLevelToDeflateLevel(ALevel: TSevenZCompressionLevel): TCompressionLevel;
begin
  Result := SevenZLevelOrdToDeflateLevel(Ord(ALevel));
end;

function SevenZLevelToBZip2BlockSize(ALevel: TSevenZCompressionLevel): Integer;
begin
  Result := SevenZLevelOrdToBZip2BlockSize(Ord(ALevel));
end;

end.
