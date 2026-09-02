unit nextpas.compiler.frontend.compiler_phase;

{$mode objfpc}{$H+}

interface

type
  {**
   * TPhaseStatus — 编译阶段状态枚举
   *
   * 替代当前字符串状态 ('deferred', 'ready', 'failure')，
   * 提供编译期类型安全。
   *}
  TPhaseStatus = (
    psDeferred,   // 尚未执行
    psReady,      // 执行成功
    psFailure     // 执行失败
  );

  {**
   * ICompilerPhase — 编译阶段接口
   *
   * 对标 rustc 的 CompilerPass / Query 概念。
   * 每个编译阶段（词法分析、语法分析、语义分析、IR 降级、后端规划、工具链执行）
   * 实现此接口，由 TCompilationSession 按注册顺序调度。
   *
   * 生命周期：
   *   1. Reset    — 重置阶段状态
   *   2. CanRun   — 检查前置条件（前序阶段必须 Ready）
   *   3. Run      — 执行阶段逻辑
   *   4. Status   — 查询执行结果
   *}
  ICompilerPhase = interface
    {** 阶段名称，用于日志和诊断 }
    function Name: string;

    {** 重置阶段状态为 Deferred }
    procedure Reset;

    {** 检查前置条件是否满足（前序阶段 Ready） }
    function CanRun: Boolean;

    {** 执行阶段逻辑 }
    procedure Run;

    {** 查询当前状态 }
    function Status: TPhaseStatus;
  end;

  {**
   * TPhaseStatusToString — 状态枚举转字符串
   *
   * 用于向后兼容现有字符串状态字段。
   *}
  function PhaseStatusToString(const AStatus: TPhaseStatus): string;

  {**
   * StringToPhaseStatus — 字符串转状态枚举
   *}
  function StringToPhaseStatus(const AStr: string): TPhaseStatus;

implementation

function PhaseStatusToString(const AStatus: TPhaseStatus): string;
begin
  case AStatus of
    psDeferred: Result := 'deferred';
    psReady:    Result := 'ready';
    psFailure:  Result := 'failure';
  else
    Result := 'deferred';
  end;
end;

function StringToPhaseStatus(const AStr: string): TPhaseStatus;
begin
  case LowerCase(AStr) of
    'deferred': Result := psDeferred;
    'ready':    Result := psReady;
    'failure':  Result := psFailure;
  else
    Result := psDeferred;
  end;
end;

end.
