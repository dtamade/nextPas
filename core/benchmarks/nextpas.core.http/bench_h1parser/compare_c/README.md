# C llhttp comparator

This benchmark compares the Pascal-translated llhttp state machine against a
same-payload C llhttp build. It intentionally measures only raw llhttp and
no-op callback dispatch, not the nextPas `IH1Parser` adapter.

Use llhttp `9.4.1`, matching `nextpas.core.http.impl.h1.llhttp.pas`.

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c \
  clean run LLHTTP_ROOT=/path/to/llhttp-9.4.1
```

Or run it through the parent benchmark directory:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser \
  run-c LLHTTP_ROOT=/path/to/llhttp-9.4.1
```

For focused raw-gap work, use the shared benchmark filter:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='C raw llhttp: 10 headers' \
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c \
  clean run LLHTTP_ROOT=/path/to/llhttp-9.4.1
```

The parent directory also provides a small flag-matrix runner that writes only
under `build/projects/nextpas.core.http/bench_h1parser/flag_matrix`:

```sh
LLHTTP_ROOT=/path/to/llhttp-9.4.1 \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --smoke --no-perf
```

Use `--perf` on machines that allow hardware perf events. The runner probes
`perf stat` first; if perf is blocked by `perf_event_paranoid` or missing
capabilities, it still runs the timing matrix and records `perf_requested=1`
and `perf_usable=0` in `env.txt`.

Supported `LLHTTP_ROOT` layouts:

- `LLHTTP_ROOT/{llhttp.h,api.c,http.c,llhttp.c}`
- `LLHTTP_ROOT/{include/llhttp.h,src/api.c,src/http.c,src/llhttp.c}`
- `LLHTTP_ROOT/{build/llhttp.h,src/native/api.c,src/native/http.c,build/c/llhttp.c}`

`tests/nextpas.core.http/test_http_benchmarks` always checks the missing-root
diagnostic. It also runs a real comparator smoke when `NEXTPAS_LLHTTP_ROOT`
points at an llhttp `9.4.1` source tree.

Do not commit generated objects, binaries, or vendored llhttp sources into this
directory.
