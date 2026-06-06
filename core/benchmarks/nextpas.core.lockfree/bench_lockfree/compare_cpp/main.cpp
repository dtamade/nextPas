#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

constexpr int kOps = 1000000;
constexpr std::size_t kCapacity = 1024;

std::uint64_t gSink = 0;

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

class BoundedQueue {
 public:
  void push(std::uint64_t value) {
    std::unique_lock<std::mutex> lock(mutex_);
    not_full_.wait(lock, [this]() { return queue_.size() < kCapacity; });
    queue_.push(value);
    lock.unlock();
    not_empty_.notify_one();
  }

  std::uint64_t pop() {
    std::unique_lock<std::mutex> lock(mutex_);
    not_empty_.wait(lock, [this]() { return !queue_.empty(); });
    const std::uint64_t value = queue_.front();
    queue_.pop();
    lock.unlock();
    not_full_.notify_one();
    return value;
  }

 private:
  std::mutex mutex_;
  std::condition_variable not_empty_;
  std::condition_variable not_full_;
  std::queue<std::uint64_t> queue_;
};

std::uint64_t bench_bounded_spsc() {
  BoundedQueue queue;
  std::uint64_t sum = 0;

  const auto start = std::chrono::steady_clock::now();
  std::thread producer([&queue]() {
    for (std::uint64_t value = 0; value < static_cast<std::uint64_t>(kOps);
         ++value) {
      queue.push(value);
    }
  });
  std::thread consumer([&queue, &sum]() {
    for (int i = 0; i < kOps; ++i) {
      sum += queue.pop();
    }
  });

  producer.join();
  consumer.join();
  print_result("mutex+condvar queue 1P+1C",
               std::chrono::steady_clock::now() - start,
               kOps);
  return sum;
}

std::uint64_t bench_bounded_mpmc() {
  BoundedQueue queue;
  std::uint64_t sum = 0;
  std::mutex sum_mutex;
  std::vector<std::thread> producers;
  std::vector<std::thread> consumers;

  const auto start = std::chrono::steady_clock::now();
  for (int producer_index = 0; producer_index < 2; ++producer_index) {
    producers.emplace_back([&queue, producer_index]() {
      const int first = producer_index * (kOps / 2);
      for (int offset = 0; offset < kOps / 2; ++offset) {
        queue.push(static_cast<std::uint64_t>(first + offset));
      }
    });
  }

  for (int consumer_index = 0; consumer_index < 2; ++consumer_index) {
    consumers.emplace_back([&queue, &sum, &sum_mutex]() {
      std::uint64_t local_sum = 0;
      for (int i = 0; i < kOps / 2; ++i) {
        local_sum += queue.pop();
      }
      std::lock_guard<std::mutex> lock(sum_mutex);
      sum += local_sum;
    });
  }

  for (auto& producer : producers) {
    producer.join();
  }
  for (auto& consumer : consumers) {
    consumer.join();
  }

  print_result("mutex+condvar queue 2P+2C",
               std::chrono::steady_clock::now() - start,
               kOps);
  return sum;
}

std::uint64_t bench_mutex_queue_single_thread() {
  std::queue<std::uint64_t> queue;
  std::mutex mutex;
  std::uint64_t sum = 0;

  const auto start = std::chrono::steady_clock::now();
  for (std::uint64_t value = 0; value < static_cast<std::uint64_t>(kOps);
       ++value) {
    std::lock_guard<std::mutex> lock(mutex);
    queue.push(value);
    sum += queue.front();
    queue.pop();
  }

  print_result("mutex queue 1T",
               std::chrono::steady_clock::now() - start,
               kOps);
  return sum;
}

int main() {
  std::cout << "=== C++ std lockfree comparison (1M ops) ===\n";
  std::cout << "Platform: " << platform_name() << '\n';
  std::cout << "Compiler flags: g++ -std=c++17 -O2 -pthread (recommended manual command)"
            << '\n';
  std::cout << "Input size: OPS=1000000; capacity=1024; scenarios=mutex+condvar queue 1P+1C, mutex+condvar queue 2P+2C, mutex queue 1T"
            << '\n';
  std::cout << "Baselines: C++ std synchronization primitives only; manual comparison source, not auto-run by Pascal benchmark"
            << '\n';
  std::cout << '\n';

  gSink = bench_bounded_spsc() ^
          bench_bounded_mpmc() ^
          bench_mutex_queue_single_thread();

  std::cout << '\n';
  std::cout << "Sink: " << gSink << '\n';
  std::cout << "Done.\n";
  return 0;
}
