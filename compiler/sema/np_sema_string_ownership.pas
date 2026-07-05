{**
 * np_sema_string_ownership.pas
 *
 * 字符串所有权分析模块 — 逻辑分组标记
 *
 * 实现代码已内联到 np_semantic_analyzer.pas（前 {$I np_sema_string_ownership.inc}）。
 * 物理分离为独立类将在后续迭代中完成。
 *
 * 包含的方法类别：
 *   - 运行时变量注册/查询（RegisterRuntimeVar, IsRuntimeVar, ...）
 *   - 字符串所有权跟踪（RegisterOwnedRuntimeStrVar, ...）
 *   - 字符串拼接/比较编码（EmitStrConcatOperand, ...）
 *   - 动态数组管理（RegisterRuntimeArrVar, ...）
 *   - 类/记录/指针变量管理（RegisterClassVar, ...）
 *   - 清理节点生成（EmitOwnedStringCleanupNodes, ...）
 *   - 块标签生成（EmitBlockLabel, EmitGotoLabel）
 *}

unit np_sema_string_ownership;

{$mode objfpc}{$H+}

interface

implementation

end.
