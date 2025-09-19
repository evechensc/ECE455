#include <iostream>
#include <thread>
#include <vector>
#include <mutex>
#include <atomic>
#include <chrono>

constexpr int ITER = 100000;

void inc_no_lock(int &counter)
{
    for (int i = 0; i < ITER; ++i)
        counter++; // data race!
}

void inc_with_mutex(int &counter, std::mutex &m)
{
    for (int i = 0; i < ITER; ++i)
    {
        std::lock_guard<std::mutex> lk(m);
        ++counter;
    }
}

void inc_atomic(std::atomic<int> &counter)
{
    for (int i = 0; i < ITER; ++i)
        counter.fetch_add(1, std::
                                 memory_order_relaxed);
}

template <typename F>
int run_and_time(int T, F &&fn)
{
    auto t0 = std::chrono::high_resolution_clock::now();
    std::vector<std::thread> ths;
    ths.reserve(T);
    for (int i = 0; i < T; ++i)
        ths.emplace_back(fn);
    for (auto &t : ths)
        t.join();
    auto t1 = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(t1 - t0).count();
}

int main()
{
    const int T = std::thread::hardware_concurrency() ? std::thread::hardware_concurrency() : 4;
    const int expected = T * ITER;

    { // No lock (incorrect)
        int counter = 0;
        auto ms = run_and_time(T, [&]
                               { inc_no_lock(counter); });
        std::cout << "[No lock] counter=" << counter
                  << " (expected " << expected << "), "
                  << ms << " ms\n";
    }

    { // Mutex
        int counter = 0;
        std::mutex m;
        auto ms = run_and_time(T, [&]
                               { inc_with_mutex(counter, m); });
        std::cout << "[Mutex] counter=" << counter
                  << " (expected " << expected << "), "
                  << ms << " ms\n";
    }

    { // Atomic
        std::atomic<int> counter{0};
        auto ms = run_and_time(T, [&]
                               { inc_atomic(counter); });
        std::cout << "[Atomic] counter=" << counter.load()
                  << " (expected " << expected << "), "
                  << ms << " ms\n";
    }
    return 0;
}