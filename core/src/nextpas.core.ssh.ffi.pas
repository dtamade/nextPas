unit nextpas.core.ssh.ffi;

{** nextpas.core.ssh - 已废弃兼容别名（空单元）。
 * 历史遗留：曾为 re-export shim（`TSshDefaultDialer` 等经 `net.ffi` 转发），
 * 现已收敛为零依赖空单元，不再拉取 net owner。
 * 单源约束：唯一拉取 net 的单元为 `nextpas.core.ssh.net.ffi`；
 * 本单元零 `uses`、零类型别名、零 `inline` 转发，仅为兼容旧 `uses` 保留，下一主版本可移除。
 * 新代码应直接 `uses nextpas.core.ssh.net.ffi`（`SshDefaultDialer`/`SshAsyncTcp*` 经 `net.ffi` 单源 `inline` 零拷贝）。 *}

{$I nextpas.core.settings.inc}

interface

implementation

end.
