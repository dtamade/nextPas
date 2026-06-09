unit nextpas.core.system.contracts;
{**
 * @desc Stable names for compiler/runtime system handshakes.
 *}

{$I nextpas.core.settings.inc}

interface

const
  NPSYSTEM_PROCESS_INIT = 'np.system.process_init';
  NPSYSTEM_PROCESS_FINI = 'np.system.process_fini';
  NPSYSTEM_UNIT_INIT = 'np.system.unit_init';
  NPSYSTEM_UNIT_FINI = 'np.system.unit_fini';
  NPSYSTEM_HALT = 'np.system.halt';
  NPSYSTEM_OBJECT_FREE = 'np.system.object_free';
  NPSYSTEM_OBJECT_FREE_DESTROY = 'np.system.object_free.destroy';
  NPSYSTEM_OBJECT_FREE_CLEANUP = 'np.system.object_free.cleanup';
  NPSYSTEM_OBJECT_FREE_RELEASE = 'np.system.object_free.release';
  NPSYSTEM_RUNTIME_FAULT = 'np.system.runtime_fault';

implementation

end.
