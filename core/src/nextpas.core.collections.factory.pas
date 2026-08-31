unit nextpas.core.collections.factory;
{**
 * @desc 兼容 shim：历史单数命名工厂已收敛至 factories（复数）单源。
 *       保留此单元以避免外部 uses 断裂，内部仅 re-export。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.factories;

implementation

end.
