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

  { Managed lifetime contracts. }
  NPSYSTEM_STRING_INIT = 'np.system.string_init';
  NPSYSTEM_STRING_FINI = 'np.system.string_fini';
  NPSYSTEM_STRING_ASSIGN = 'np.system.string_assign';
  NPSYSTEM_DYNARRAY_INIT = 'np.system.dynarray_init';
  NPSYSTEM_DYNARRAY_FINI = 'np.system.dynarray_fini';
  NPSYSTEM_DYNARRAY_SET_LENGTH = 'np.system.dynarray_set_length';
  NPSYSTEM_INTERFACE_ADDREF = 'np.system.interface_addref';
  NPSYSTEM_INTERFACE_RELEASE = 'np.system.interface_release';
  NPSYSTEM_MANAGED_RECORD_INIT = 'np.system.managed_record_init';
  NPSYSTEM_MANAGED_RECORD_FINI = 'np.system.managed_record_fini';
  NPSYSTEM_HEAP_ALLOC = 'np.system.heap_alloc';
  NPSYSTEM_HEAP_FREE = 'np.system.heap_free';

  NPSYSTEM_OBJECT_FREE = 'np.system.object_free';
  NPSYSTEM_OBJECT_FREE_DESTROY = 'np.system.object_free.destroy';
  NPSYSTEM_OBJECT_FREE_CLEANUP = 'np.system.object_free.cleanup';
  NPSYSTEM_OBJECT_FREE_RELEASE = 'np.system.object_free.release';
  NPSYSTEM_RUNTIME_FAULT = 'np.system.runtime_fault';

  { Exception boundary contracts — compiler/runtime handshake names }
  NPSYSTEM_EXCEPTION_TRY_PUSH = 'np.system.exception_try_push';
  NPSYSTEM_EXCEPTION_TRY_POP = 'np.system.exception_try_pop';
  NPSYSTEM_EXCEPTION_RAISE = 'np.system.exception_raise';
  NPSYSTEM_EXCEPTION_FINALLY_END = 'np.system.exception_finally_end';
  NPSYSTEM_EXCEPTION_EXCEPT_END = 'np.system.exception_except_end';

implementation

end.
