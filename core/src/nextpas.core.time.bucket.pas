unit nextpas.core.time.bucket;

{** @desc UTC 时间桶键（Time Bucket Key）
  @details epoch 秒 → 桶序号（整数除法，非负）定宽前导补零字符串。
    字典序 = 时间序，定长可比较——范围查询/排序/分组直接可用字符串运算。
    桶宽任意（秒/分/时/天…），调用方按聚合粒度选择。
  @design 纯整数算术（不依赖日历/时区）：epoch 秒 div 桶宽即桶序号，
    避免 TDateTime 精度漂移与 Decode* 整点截断风险。仅支持非负时间戳
    （Unix 惯例；负数 epoch 的桶键无定长补零语义）。
  @example TimeBucketKey(1785900000) → '000000496083'（小时桶）；
    TimeBucketKey(1785900000, 86400) → '000000020670'（天桶）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

{ UTC 时间桶键：AUnixSeconds div ABucketSeconds 的定宽补零字符串。
  ABucketSeconds：桶宽秒数（>=1，默认 1 小时）；AWidth：定宽位数
  （默认 12，须 >= 桶序号位数，否则 EArgumentError——定长不可压缩）。
  负数时间戳拒绝（EArgumentError）。 }
function TimeBucketKey(const AUnixSeconds: Int64;
  const ABucketSeconds: Int64 = 3600; const AWidth: Integer = 12): string;

implementation

{ Int64 → 十进制字符串（纯 System 算术，无 FPC RTL 依赖——core 契约
  仅 nextpas.core.system 域可用 RTL；单分配缓冲 O(n) 替代 Chr+Result O(n²)）。 }
function Digits(const AValue: Int64): string;
var
  LRem: Int64;
  LBuf: array[0..19] of Char;
  LLen, I: Integer;
begin
  if AValue = 0 then Exit('0');
  LRem := AValue;
  LLen := 0;
  while LRem > 0 do
  begin
    LBuf[LLen] := Chr(Ord('0') + LRem mod 10);
    LRem := LRem div 10;
    Inc(LLen);
  end;
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    Result[I + 1] := LBuf[LLen - 1 - I];
end;

function TimeBucketKey(const AUnixSeconds: Int64;
  const ABucketSeconds: Int64; const AWidth: Integer): string;
var
  LBucket: Int64;
  LDigits: string;
  LPad: Integer;
begin
  if ABucketSeconds < 1 then
    raise EArgumentError.Create('time bucket: bucket seconds must be >= 1');
  if AUnixSeconds < 0 then
    raise EArgumentError.Create(
      'time bucket: negative timestamps unsupported (Unix convention)');
  LBucket := AUnixSeconds div ABucketSeconds;
  LDigits := Digits(LBucket);
  if Length(LDigits) > AWidth then
    raise EArgumentError.Create(
      'time bucket: width too small for bucket index ' + LDigits);
  LPad := AWidth - Length(LDigits);
  if LPad > 0 then
    Result := StringOfChar('0', LPad) + LDigits
  else
    Result := LDigits;
end;

end.