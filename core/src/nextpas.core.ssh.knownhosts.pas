unit nextpas.core.ssh.knownhosts;

{** nextpas.core.ssh.knownhosts - KnownHosts 独立协议帧模块（S27′ 晋升）。
 *
 *  薄门面：仅 re-export TSshKnownHosts，解析/验签/指纹/通配单源于 hostkey。
 *  形态：零额外堆分配，hostkey 内 Move 零拷贝视图复用；bytes 判定经 bytes.ops/TConstantTime 单源。
 *  perf: 无额外分配，inline 零拷贝（hostkey 内 Move 单次分配），零二次拷贝；门面自身零堆。
 *  stability: 资源由 TSshKnownHosts 持有，Create/Free 配对，异常路径 SecureZero。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.ssh.hostkey;

type
  TSshKnownHosts = nextpas.core.ssh.hostkey.TSshKnownHosts;

implementation

end.
