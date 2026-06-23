unit nextpas.core.mem.arena.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base;

type
  {** Arena 标记：用于 SaveMark/RestoreToMark }
  TArenaMark = record
    FrontOffset: SizeUInt;  // 含指针对象的偏移
    BackOffset: SizeUInt;   // 无指针对象的偏移
    TotalUsed: SizeUInt;    // 标记时的 TotalUsed
  end;

  {** Arena 增长策略 }
  TArenaGrowthKind = (
    agkGeometric,  // 几何增长（默认 2x）
    agkLinear      // 线性增长
  );

  {** Arena 统计信息 }
  TArenaStats = record
    TotalAllocated: SizeUInt;  // 总分配字节数
    TotalUsed: SizeUInt;       // 实际使用字节数
    PeakUsed: SizeUInt;        // 峰值使用字节数
    AllocCount: QWord;        // 分配次数（QWord 避免 32 位平台截断）
  end;

  {** Arena 配置 }
  TArenaConfig = record
    InitialSize: SizeUInt;       // 初始大小
    MaxSize: SizeUInt;           // 最大大小（0 = 无限制）
    GrowthKind: TArenaGrowthKind; // 增长策略
    GrowthFactor: Double;        // 几何增长因子（>= 1.1，推荐 2.0）
    GrowthStep: SizeUInt;        // 线性增长步长
    Alignment: SizeUInt;         // 对齐（0 = DEFAULT_ALIGNMENT）
    KeepSegments: Boolean;       // Reset 时是否保留已分配的段

    class function Default(aInitialSize: SizeUInt): TArenaConfig; static;
  end;

const
  {** 预分配虚拟地址空间大小 (256MB) }
  ARENA_VIRTUAL_RESERVE = 256 * 1024 * 1024;
  {** 大对象阈值 (64KB)：>= 此值的对象直接 mmap }
  ARENA_LARGE_THRESHOLD = 64 * 1024;
  {** 默认对齐 }
  ARENA_DEFAULT_ALIGNMENT = DEFAULT_ALIGNMENT;

implementation

class function TArenaConfig.Default(aInitialSize: SizeUInt): TArenaConfig;
begin
  Result.InitialSize := aInitialSize;
  Result.MaxSize := 0;
  Result.GrowthKind := agkGeometric;
  Result.GrowthFactor := 2.0;
  Result.GrowthStep := 0;
  Result.Alignment := 0;
  Result.KeepSegments := True;
end;

end.
