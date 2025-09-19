#include <iostream>
#include <vector>
#include <thread>
#include <random>
#include <chrono>

void multiply_block(const std::vector<double> &A,
                    const std::vector<double> &B,
                    std::vector<double> &C,
                    int N, int row_start, int row_end)
{
    for (int i = row_start; i < row_end; ++i)
    {
        for (int j = 0; j < N; ++j)
        {
            double sum = 0.0;
            for (int k = 0; k < N; ++k)
            {
                sum += A[i * N + k] * B[k * N + j];
            }
            C[i * N + j] = sum;
        }
    }
}

int main()
{
    const int N = 800;
    const int T = std::thread::hardware_concurrency() ? std::thread::hardware_concurrency() : 4;

    std::vector<double> A(N * N), B(N * N), C(N * N);
    std::mt19937 rng(42);
    std::uniform_real_distribution<double> dist(0.0, 1.0);

    for (auto &x : A)
        x = dist(rng);
    for (auto &x : B)
        x = dist(rng);

    std::vector<std::thread> threads;
    int chunk = N / T;
    auto start_time = std::chrono::high_resolution_clock::now();
    for (int t = 0; t < T; ++t)
    {
        int rs = t * chunk;
        int re = (t == T - 1) ? N : rs + chunk;
        threads.emplace_back(multiply_block,
                             std::cref(A), std::cref(B), std::ref(C),
                             N, rs, re);
    }
    for (auto &th : threads)
        th.join();
    auto end_time = std::chrono::high_resolution_clock::now();

    std::cout << "Parallel multiplication took "
              << std::chrono::duration<double>(end_time - start_time).count()
              << " s\n";
}