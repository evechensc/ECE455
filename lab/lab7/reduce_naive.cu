#include <iostream>
#include <vector>
#include <random>
#include <cassert>
#include <iomanip>
#include <chrono>

#define BLOCK_DIM 256
#define N (1 << 24)  // 16,777,216 elements

// ---------- CUDA Error Checking ----------
#define checkCuda(val) check((val), #val, __FILE__, __LINE__)
void check(cudaError_t err, const char* const func, const char* const file, int line) {
    if (err != cudaSuccess) {
        std::cerr << "CUDA Error at " << file << ":" << line << " — "
                  << cudaGetErrorString(err) << " (" << func << ")" << std::endl;
        std::exit(EXIT_FAILURE);
    }
}

// ---------- Random Initialization ----------
std::vector<int> create_rand_vector(size_t n, int min_val = 0, int max_val = 100) {
    std::random_device r;
    std::default_random_engine e(r());
    std::uniform_int_distribution<int> dist(min_val, max_val);
    std::vector<int> vec(n);
    for (size_t i = 0; i < n; ++i)
        vec[i] = dist(e);
    return vec;
}

// ---------- CPU Reference Reduction ----------
int reduce_host(const std::vector<int>& data) {
    long long sum = 0;
    for (auto v : data)
        sum += v;
    return static_cast<int>(sum);
}

// ---------- Naive GPU Kernel (global memory) ----------
__global__ void reduce_naive(const int* in, int* out, size_t n_elems) {
    unsigned int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n_elems)
        atomicAdd(out, in[idx]);
}

// ---------- GPU Launcher with Averaging ----------
int reduce_cuda_naive(const std::vector<int>& h_in, float& avg_time_ms) {
    int *d_in, *d_out;
    int h_out = 0;

    checkCuda(cudaMalloc(&d_in, sizeof(int) * N));
    checkCuda(cudaMalloc(&d_out, sizeof(int)));
    checkCuda(cudaMemcpy(d_in, h_in.data(), sizeof(int) * N, cudaMemcpyHostToDevice));
    checkCuda(cudaMemset(d_out, 0, sizeof(int)));

    dim3 threads(BLOCK_DIM);
    dim3 blocks((N + BLOCK_DIM - 1) / BLOCK_DIM);

    cudaEvent_t start, stop;
    checkCuda(cudaEventCreate(&start));
    checkCuda(cudaEventCreate(&stop));

    const int num_warmups = 1;
    const int num_runs = 3;
    float total_ms = 0.0f;

    // Warm-up
    for (int i = 0; i < num_warmups; ++i)
        reduce_naive<<<blocks, threads>>>(d_in, d_out, N);
    checkCuda(cudaDeviceSynchronize());

    // Actual runs
    for (int i = 0; i < num_runs; ++i) {
        checkCuda(cudaMemset(d_out, 0, sizeof(int)));
        checkCuda(cudaEventRecord(start));
        reduce_naive<<<blocks, threads>>>(d_in, d_out, N);
        checkCuda(cudaEventRecord(stop));
        checkCuda(cudaEventSynchronize(stop));
        float elapsed_ms;
        checkCuda(cudaEventElapsedTime(&elapsed_ms, start, stop));
        total_ms += elapsed_ms;
    }

    avg_time_ms = total_ms / num_runs;
    checkCuda(cudaMemcpy(&h_out, d_out, sizeof(int), cudaMemcpyDeviceToHost));

    checkCuda(cudaFree(d_in));
    checkCuda(cudaFree(d_out));
    checkCuda(cudaEventDestroy(start));
    checkCuda(cudaEventDestroy(stop));

    return h_out;
}

// ---------- Main ----------
int main() {
    std::cout << "Running Naive Reduction (global memory, N = " << N << ")...\n";

    std::vector<int> h_in = create_rand_vector(N);

    // ---- CPU reference + timing ----
    std::cout << "Computing CPU reference..." << std::endl;
    auto cpu_start = std::chrono::high_resolution_clock::now();
    int ref = reduce_host(h_in);
    auto cpu_end = std::chrono::high_resolution_clock::now();
    double cpu_time_ms =
        std::chrono::duration<double, std::milli>(cpu_end - cpu_start).count();

    // ---- GPU reduction ----
    float avg_gpu_time = 0.0f;
    int gpu_result = reduce_cuda_naive(h_in, avg_gpu_time);

    // ---- Validation ----
    bool ok = (ref == gpu_result);
    std::cout << std::fixed << std::setprecision(5);
    std::cout << "CPU Result: " << ref << "\nGPU Result: " << gpu_result
              << "\nDifference: " << (ref - gpu_result) << std::endl;

    if (ok)
        std::cout << "Validation PASSED.\n";
    else
        std::cout << "Validation FAILED.\n";

    std::cout << "\n--- Performance ---\n";
    std::cout << "CPU time: " << cpu_time_ms << " ms\n";
    std::cout << "GPU avg kernel time (3 runs): " << avg_gpu_time << " ms\n";
    std::cout << "Speedup (CPU / GPU): " << (cpu_time_ms / avg_gpu_time) << "x\n";

    return 0;
}