#define _POSIX_C_SOURCE 200809L

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "llhttp.h"

typedef void (*bench_proc)(int64_t iters);

typedef struct bench_result_s {
  const char* name;
  int64_t iterations;
  double ns_per_op;
  double ops_per_sec;
} bench_result_t;

static const int64_t target_ns = 50000000;
static const int64_t warmup_iters = 5;
static const int samples = 3;
static const int64_t default_max_iters = 100000;
static const char* bench_filter_env = "NEXTPAS_BENCH_FILTER";

static const char req_simple[] =
  "GET / HTTP/1.1\r\n"
  "Host: localhost\r\n"
  "\r\n";

static const char req_10headers[] =
  "GET /api/v1/users HTTP/1.1\r\n"
  "Host: example.com\r\n"
  "User-Agent: nextpas/1.0\r\n"
  "Accept: application/json\r\n"
  "Accept-Encoding: gzip, deflate\r\n"
  "Accept-Language: en-US\r\n"
  "Connection: keep-alive\r\n"
  "Cache-Control: no-cache\r\n"
  "X-Request-Id: abc123\r\n"
  "X-Forwarded-For: 10.0.0.1\r\n"
  "Authorization: Bearer token123\r\n"
  "\r\n";

static const char req_post_1k_head[] =
  "POST /upload HTTP/1.1\r\n"
  "Host: example.com\r\n"
  "Content-Type: application/octet-stream\r\n"
  "Content-Length: 1024\r\n"
  "\r\n";

static char body_1k[1024];
static char req_post_1k[sizeof(req_post_1k_head) - 1 + sizeof(body_1k) + 1];
static char pipeline[sizeof(req_simple) * 10];
static size_t req_post_1k_len;
static size_t pipeline_len;
static uint64_t sink_value;
static uint64_t callback_sink;
static bench_result_t results[16];
static int result_count;

static uint64_t monotonic_ns(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0;
  }
  return ((uint64_t) ts.tv_sec * 1000000000ull) + (uint64_t) ts.tv_nsec;
}

static int64_t configured_max_iters(void) {
  const char* value = getenv("NEXTPAS_BENCH_MAX_ITERS");
  char* endptr = NULL;
  long long parsed;

  if (value == NULL || value[0] == '\0') {
    return default_max_iters;
  }

  parsed = strtoll(value, &endptr, 10);
  if (endptr == value || *endptr != '\0' || parsed < 100) {
    return default_max_iters;
  }
  return (int64_t) parsed;
}

static const char* configured_filter(void) {
  const char* value = getenv(bench_filter_env);
  if (value == NULL) {
    return "";
  }
  return value;
}

static char ascii_lower(char value) {
  if (value >= 'A' && value <= 'Z') {
    return (char) (value + ('a' - 'A'));
  }
  return value;
}

static int contains_case_insensitive(const char* haystack, const char* needle) {
  size_t haystack_len;
  size_t needle_len;

  if (needle == NULL || needle[0] == '\0') {
    return 1;
  }
  if (haystack == NULL) {
    return 0;
  }

  haystack_len = strlen(haystack);
  needle_len = strlen(needle);
  if (needle_len > haystack_len) {
    return 0;
  }

  for (size_t i = 0; i <= haystack_len - needle_len; i++) {
    size_t j = 0;
    while (j < needle_len &&
        ascii_lower(haystack[i + j]) == ascii_lower(needle[j])) {
      j++;
    }
    if (j == needle_len) {
      return 1;
    }
  }
  return 0;
}

static int should_run_benchmark(const char* name) {
  return contains_case_insensitive(name, configured_filter());
}

static void init_data(void) {
  size_t pos;
  memset(body_1k, 'x', sizeof(body_1k));
  memcpy(req_post_1k, req_post_1k_head, sizeof(req_post_1k_head) - 1);
  memcpy(req_post_1k + sizeof(req_post_1k_head) - 1, body_1k, sizeof(body_1k));
  req_post_1k_len = sizeof(req_post_1k_head) - 1 + sizeof(body_1k);
  req_post_1k[req_post_1k_len] = '\0';

  pos = 0;
  for (int i = 0; i < 10; i++) {
    memcpy(pipeline + pos, req_simple, sizeof(req_simple) - 1);
    pos += sizeof(req_simple) - 1;
  }
  pipeline_len = pos;
  pipeline[pipeline_len] = '\0';
}

static void run_raw_request(const char* req, size_t len, int64_t iters) {
  llhttp_t parser;
  llhttp_settings_t settings;
  llhttp_errno_t err;

  llhttp_settings_init(&settings);
  llhttp_init(&parser, HTTP_REQUEST, &settings);
  for (int64_t i = 0; i < iters; i++) {
    llhttp_reset(&parser);
    err = llhttp_execute(&parser, req, len);
    if (err != HPE_OK) {
      sink_value++;
    }
  }
  sink_value += parser.http_major + parser.http_minor + parser.method;
}

static int noop_data_cb(llhttp_t* parser, const char* at, size_t length) {
  (void) parser;
  (void) at;
  callback_sink += length;
  return 0;
}

static int noop_cb(llhttp_t* parser) {
  (void) parser;
  callback_sink++;
  return 0;
}

static int pause_on_message_complete_cb(llhttp_t* parser) {
  (void) parser;
  callback_sink++;
  return HPE_PAUSED;
}

static void install_noop_callbacks(llhttp_settings_t* settings) {
  settings->on_url = noop_data_cb;
  settings->on_header_field = noop_data_cb;
  settings->on_header_value = noop_data_cb;
  settings->on_body = noop_data_cb;
  settings->on_headers_complete = noop_cb;
  settings->on_message_complete = noop_cb;
}

static void run_paused_pipeline_with_settings(llhttp_settings_t* settings,
    int64_t iters) {
  llhttp_t parser;
  llhttp_errno_t err;
  size_t pos = 0;
  size_t consumed;
  const char* error_pos;

  llhttp_init(&parser, HTTP_REQUEST, settings);
  for (int64_t i = 0; i < iters; i++) {
    pos = 0;
    while (pos < pipeline_len) {
      llhttp_reset(&parser);
      err = llhttp_execute(&parser, pipeline + pos, pipeline_len - pos);
      if (err != HPE_PAUSED) {
        sink_value++;
        break;
      }
      error_pos = llhttp_get_error_pos(&parser);
      if (error_pos == NULL || error_pos < pipeline + pos) {
        break;
      }
      consumed = (size_t) (error_pos - (pipeline + pos));
      if (consumed == 0) {
        break;
      }
      pos += consumed;
    }
  }
  sink_value += callback_sink + pos;
}

static void run_noop_request(const char* req, size_t len, int64_t iters) {
  llhttp_t parser;
  llhttp_settings_t settings;
  llhttp_errno_t err;

  callback_sink = 0;
  llhttp_settings_init(&settings);
  install_noop_callbacks(&settings);
  llhttp_init(&parser, HTTP_REQUEST, &settings);
  for (int64_t i = 0; i < iters; i++) {
    llhttp_reset(&parser);
    err = llhttp_execute(&parser, req, len);
    if (err != HPE_OK) {
      sink_value++;
    }
  }
  sink_value += callback_sink + parser.http_major + parser.http_minor +
    parser.method;
}

static void bench_raw_simple(int64_t iters) {
  run_raw_request(req_simple, sizeof(req_simple) - 1, iters);
}

static void bench_raw_10headers(int64_t iters) {
  run_raw_request(req_10headers, sizeof(req_10headers) - 1, iters);
}

static void bench_raw_post_1k(int64_t iters) {
  run_raw_request(req_post_1k, req_post_1k_len, iters);
}

static void bench_raw_pipeline_pause_only(int64_t iters) {
  llhttp_settings_t settings;
  callback_sink = 0;
  llhttp_settings_init(&settings);
  settings.on_message_complete = pause_on_message_complete_cb;
  run_paused_pipeline_with_settings(&settings, iters);
}

static void bench_noop_simple(int64_t iters) {
  run_noop_request(req_simple, sizeof(req_simple) - 1, iters);
}

static void bench_noop_10headers(int64_t iters) {
  run_noop_request(req_10headers, sizeof(req_10headers) - 1, iters);
}

static void bench_noop_post_1k(int64_t iters) {
  run_noop_request(req_post_1k, req_post_1k_len, iters);
}

static void bench_noop_pipeline(int64_t iters) {
  llhttp_settings_t settings;
  callback_sink = 0;
  llhttp_settings_init(&settings);
  install_noop_callbacks(&settings);
  settings.on_message_complete = pause_on_message_complete_cb;
  run_paused_pipeline_with_settings(&settings, iters);
}

static uint64_t measure_ns(bench_proc proc, int64_t iters) {
  uint64_t start = monotonic_ns();
  uint64_t end;
  proc(iters);
  end = monotonic_ns();
  return end - start;
}

static int64_t calibrate_iterations(bench_proc proc) {
  uint64_t elapsed;
  int64_t iters;
  int64_t max_iters = configured_max_iters();

  proc(warmup_iters);
  iters = 100;
  for (;;) {
    elapsed = measure_ns(proc, iters);
    if (elapsed >= (uint64_t) target_ns) {
      return iters;
    }
    if (elapsed < 1000000) {
      iters *= 10;
    } else {
      iters = (int64_t) (((double) iters * (double) target_ns) /
        (double) elapsed);
    }
    if (iters < 100) {
      iters = 100;
    }
    if (iters > max_iters) {
      return max_iters;
    }
  }
}

static void sort_samples(uint64_t* values, int count) {
  for (int i = 0; i < count - 1; i++) {
    for (int j = i + 1; j < count; j++) {
      if (values[j] < values[i]) {
        uint64_t tmp = values[i];
        values[i] = values[j];
        values[j] = tmp;
      }
    }
  }
}

static void run_benchmark(const char* name, bench_proc proc) {
  uint64_t sample_values[3];
  uint64_t median;
  int64_t iters;

  if (!should_run_benchmark(name)) {
    return;
  }

  iters = calibrate_iterations(proc);

  for (int i = 0; i < samples; i++) {
    sample_values[i] = measure_ns(proc, iters);
  }
  sort_samples(sample_values, samples);
  median = sample_values[samples / 2];

  results[result_count].name = name;
  results[result_count].iterations = iters;
  results[result_count].ns_per_op = (double) median / (double) iters;
  if (results[result_count].ns_per_op > 0.0) {
    results[result_count].ops_per_sec =
      1000000000.0 / results[result_count].ns_per_op;
  } else {
    results[result_count].ops_per_sec = 0.0;
  }

  printf("  %40s%12lld iters%10.1f ns/op%14.0f ops/s\n",
    name,
    (long long) results[result_count].iterations,
    results[result_count].ns_per_op,
    results[result_count].ops_per_sec);
  result_count++;
}

static void print_summary(void) {
  const char* filter = configured_filter();
  printf("\n=== SUMMARY ===\n");
  printf("bench_max_iters=%lld\n", (long long) configured_max_iters());
  if (filter[0] != '\0') {
    printf("bench_filter=%s\n", filter);
  }
  printf("  %40s%10s%14s\n", "Benchmark", "ns/op", "ops/s");
  printf("  %40s%10s%14s\n", "", "", "");
  for (int i = 0; i < result_count; i++) {
    printf("  %40s%10.1f%14.0f\n",
      results[i].name, results[i].ns_per_op, results[i].ops_per_sec);
  }
}

int main(void) {
  init_data();

  printf("=== C llhttp H1 parser comparator ===\n");
  printf("operation=http.h1parser.c_llhttp\n");
  printf("  llhttp version: %d.%d.%d\n",
    LLHTTP_VERSION_MAJOR, LLHTTP_VERSION_MINOR, LLHTTP_VERSION_PATCH);
  printf("  Simple GET: %zu bytes\n", sizeof(req_simple) - 1);
  printf("  10 headers: %zu bytes\n", sizeof(req_10headers) - 1);
  printf("  POST 1KB:   %zu bytes\n", req_post_1k_len);
  printf("  Pipeline:   %zu bytes (10 requests)\n\n", pipeline_len);

  printf("--- C llhttp (no callbacks) ---\n");
  run_benchmark("C raw llhttp: simple GET (~60B)", bench_raw_simple);
  run_benchmark("C raw llhttp: 10 headers (~400B)", bench_raw_10headers);
  run_benchmark("C raw llhttp: POST 1KB body", bench_raw_post_1k);
  run_benchmark("C raw llhttp: pipeline pause-only (10 reqs)",
    bench_raw_pipeline_pause_only);
  printf("\n--- C llhttp with no-op callbacks ---\n");
  run_benchmark("C noop cb: simple GET (~60B)", bench_noop_simple);
  run_benchmark("C noop cb: 10 headers (~400B)", bench_noop_10headers);
  run_benchmark("C noop cb: POST 1KB body", bench_noop_post_1k);
  run_benchmark("C noop cb: pipeline (10 reqs)", bench_noop_pipeline);
  print_summary();

  if (sink_value == 0xFFFFFFFFFFFFFFFFull) {
    fprintf(stderr, "unreachable sink: %llu\n",
      (unsigned long long) sink_value);
  }
  return 0;
}
