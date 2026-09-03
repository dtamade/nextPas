unit nextpas.core.sevenz.limits deprecated 'use nextpas.core.sevenz.base';

{**
 * nextpas.core.sevenz.limits - 已移除兼容别名（历史路径空壳）
 *
 * 13 阈值单源已收敛至 nextpas.core.sevenz.base，本单元不再提供第二公共源；
 * 保留空单元仅为历史编译期提示（deprecated），新代码直接 uses nextpas.core.sevenz.base。
 * 四件套外碎片已清理：reader/writer/header 均单源引用 base，无第二公共源。
 * 性能：空单元零拷贝、零运行时开销；稳定性：无资源分配、无泄漏风险。
 *}

{$I nextpas.core.settings.inc}

interface

implementation

end.
