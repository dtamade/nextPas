{**
 * nextpas.core.agent.base.constants - agent sentinel / limits constants.
 *
 * 纯常量，零依赖（SECURITY/PERF 阈值单一真源）。被 base.types / base.helpers 共享。
 * 契约：core/docs/agent/API.md §1.2，SECURITY §3。
 *}

unit nextpas.core.agent.base.constants;

{$I nextpas.core.settings.inc}

interface

const
  { ---- Sentinel 常量（API.md §1.2）：未设置的字段绝不上送 wire ---- }
  CTemperatureUnset   = -2.0;          { 合法域 [0.0, 2.0]，负值即 unset }
  CTopPUnset          = -2.0;
  CMaxTokensUnset     = 0;             { >0 有效 }
  CSeedUnset          = Low(Int64);
  CTimeoutDefault     = 0;             { 0=用 transport 默认；<0=无限 }
  CUsageUnknown       = -1;            { TTokenUsage 各字段未知值 }
  CRetryAfterUnknown  = -1;            { RetryAfterMs 未提供/不适用 }
  CAgentMaxSlotMap    = 256;           { 槽位直映表上限：防稀疏大索引 DoS（SECURITY §3）}
  CAgentMaxWireHeaderValueBytes = 8 * 1024;  { 单头 8 KiB（SECURITY §3）}
  CAgentMaxWireTotalHeaderBytes = 64 * 1024; { 总头 64 KiB（SECURITY §3）}
  CAgentMaxSuccessBodyBytes = 8 * 1024 * 1024; { 成功体 8 MiB（SECURITY §3）}
  CAgentMaxRawBodySnippetBytes = 8 * 1024;  { RawBodySnippet 上限，ERRORS §6 }
  CAgentMaxExtraKeys = 64;                 { 未知键捕获上限，SECURITY §3 }
  CAgentMaxToolArgsBytes = 256 * 1024;     { 工具参数预检 256 KiB（SECURITY §3）}
  CAgentToolArgsInitialCap = 1024;         { 工具参数 Args builder 初始容量（PERF §2, 256→1024 少 2 次扩容）}
  CAgentSystemTextInitialCap = 512;        { System 去重拼接初始容量（PERF §2）}
  CAgentSessionForkInitialCap = 1024;      { Session Fork 初始容量（PERF §2）}

implementation

end.
