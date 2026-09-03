unit nextpas.core.net.maintenance.base;

{** nextpas.core.net.maintenance.base - 维护策略常量基座（L1）。
 *
 *  通用重协商/KeepAlive 阈值，L1 单源，供 ssh/tls/quic/http 复用。
 *  零依赖（仅常量），四件套 base 层。 *}

{$I nextpas.core.settings.inc}

interface

const
  NET_REKEY_BYTES_DEFAULT = UInt64(1) * 1024 * 1024 * 1024;
  NET_REKEY_INTERVAL_MS_DEFAULT = 3600 * 1000;
  NET_KEEPALIVE_INTERVAL_MS_DEFAULT = 0;

implementation

end.
