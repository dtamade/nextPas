# macOS trig host proof template (F-015)

> **BLOCKED_UNTIL**: macOS runner / CI host  
> Last updated: 2026-07-26

## Required evidence (when host available)

```bash
# On macOS with FPC trunk matching CI:
make -C core/tests/nextpas.core.math/test_trig clean test
make -C core/tests/nextpas.core.math/test_trig_host_compile_gate clean test
make -C core/tests/nextpas.core.math clean test
```

Record: host model, FPC version, exit codes, any link flags for libm/System.

## Do not

- Mark M8/host matrix complete without the above
- Fake green by skipping link/run
