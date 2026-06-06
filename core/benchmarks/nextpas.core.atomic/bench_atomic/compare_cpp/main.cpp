#include <atomic>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

constexpr int kIters = 1000000;

std::int32_t gSink32 = 0;
std::uint32_t gSinkU32 = 0;

std::int32_t black_box_i32(std::int32_t value) {
#if defined(__GNUC__) || defined(__clang__)
  asm volatile("" : "+r"(value) : : "memory");
#else
  volatile std::int32_t sink = value;
  value = sink;
#endif
  return value;
}

std::string platform_name() {
#if defined(__linux__)
  const char* os = "linux";
#elif defined(_WIN32)
  const char* os = "windows";
#elif defined(__APPLE__)
  const char* os = "darwin";
#else
  const char* os = "unknown-os";
#endif

#if defined(__x86_64__) || defined(_M_X64)
  const char* arch = "x86_64";
#elif defined(__aarch64__) || defined(_M_ARM64)
  const char* arch = "aarch64";
#elif defined(__i386__) || defined(_M_IX86)
  const char* arch = "i386";
#else
  const char* arch = "unknown-arch";
#endif

  return std::string(os) + " " + arch;
}

void print_result(
    const std::string& name,
    std::chrono::steady_clock::duration elapsed,
    std::int64_t operations) {
  auto elapsed_ns =
      std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed).count();
  if (elapsed_ns <= 0) {
    elapsed_ns = 1;
  }

  const double elapsed_ms = static_cast<double>(elapsed_ns) / 1000000.0;
  const double ns_per_op = static_cast<double>(elapsed_ns) /
                           static_cast<double>(operations);
  const double mops = static_cast<double>(operations) /
                      (static_cast<double>(elapsed_ns) / 1000000000.0) /
                      1000000.0;

  std::cout << "  " << std::left << std::setw(34) << name << std::right
            << std::setw(8) << std::fixed << std::setprecision(2)
            << elapsed_ms << " ms  " << std::setw(6) << std::setprecision(1)
            << mops << " M ops/sec  " << std::setw(5) << ns_per_op
            << " ns/op\n";
}

std::int32_t bench_plain_baseline() {
  std::int32_t value = 0;
  const auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < kIters; ++i) {
    value = black_box_i32(value + static_cast<std::int32_t>((i & 1) + 1));
  }
  print_result("Plain local increment 1M",
               std::chrono::steady_clock::now() - start,
               kIters);
  return value;
}

std::int32_t bench_atomic_load_store32() {
  std::atomic<std::int32_t> value{0};
  std::int32_t sink = 0;
  const auto start = std::chrono::steady_clock::now();
  for (int i = 1; i <= kIters; ++i) {
    value.store(i, std::memory_order_relaxed);
    sink = value.load(std::memory_order_relaxed);
  }
  print_result("AtomicLoad/Store32 2M",
               std::chrono::steady_clock::now() - start,
               kIters * 2);
  return sink;
}

std::int32_t bench_atomic_fetch_add32() {
  std::atomic<std::int32_t> value{0};
  const auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < kIters; ++i) {
    value.fetch_add(1, std::memory_order_relaxed);
  }
  print_result("AtomicFetchAdd32 1M",
               std::chrono::steady_clock::now() - start,
               kIters);
  return value.load(std::memory_order_relaxed);
}

std::int32_t bench_atomic_compare_exchange32() {
  std::atomic<std::int32_t> value{0};
  const auto start = std::chrono::steady_clock::now();
  for (int i = 1; i <= kIters; ++i) {
    std::int32_t expected = i - 1;
    if (!value.compare_exchange_strong(expected,
                                       i,
                                       std::memory_order_seq_cst,
                                       std::memory_order_seq_cst)) {
      throw std::runtime_error("unexpected compare-exchange failure");
    }
  }
  print_result("AtomicCompareExchange32 1M",
               std::chrono::steady_clock::now() - start,
               kIters);
  return value.load(std::memory_order_seq_cst);
}

std::uint32_t bench_typed_atomic_u32() {
  std::atomic<std::uint32_t> value{0};
  const auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < kIters; ++i) {
    value.fetch_add(1, std::memory_order_relaxed);
  }
  print_result("TAtomicUInt32 FetchAdd 1M",
               std::chrono::steady_clock::now() - start,
               kIters);
  return value.load(std::memory_order_relaxed);
}

int main() {
  std::cout << "=== C++ std::atomic comparison (1M iterations) ===\n";
  std::cout << "Platform: " << platform_name() << '\n';
  std::cout << "Compiler flags: g++ -std=c++17 -O2 (recommended manual command)"
            << '\n';
  std::cout << "Input size: ITERS=1000000; scenarios=plain baseline, "
               "AtomicLoad/Store32, AtomicFetchAdd32, AtomicCompareExchange32, "
               "TAtomicUInt32"
            << '\n';
  std::cout << "Baselines: C++ std::atomic single-thread operations; manual "
               "comparison source, not auto-run by Pascal benchmark"
            << '\n';
  std::cout << '\n';

  gSink32 = bench_plain_baseline();
  gSink32 = bench_atomic_load_store32();
  gSink32 = bench_atomic_fetch_add32();
  gSink32 = bench_atomic_compare_exchange32();
  gSinkU32 = bench_typed_atomic_u32();

  std::cout << '\n';
  std::cout << "Sink: " << gSink32 << '/' << gSinkU32 << '\n';
  std::cout << "Done.\n";
  return 0;
}
