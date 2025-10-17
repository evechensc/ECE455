#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <random>
#include <vector>
#include <cmath>

#define TILE_SIZE 16
#define MAT_DIM 1024

#define checkCuda(val) check((val), #val, __FILE__, __LINE__)

void check(cudaError_t err, const char *const func, const char *const file, int line)
{
    if (err != cudaSuccess)
    {
        std::cerr << "CUDA Runtime Error at: " << file << ":" << line << std::endl;
        std::cerr << cudaGetErrorString(err) << " " << func << std::endl;
        std::exit(EXIT_FAILURE);
    }
}

// ---------------- Random Initialization ----------------
template <typename T>
std::vector<T> create_rand_vector(size_t n, T min_val = 0, T max_val = 10)
{
    std::random_device r;
    std::default_random_engine e(r());
    std::uniform_real_distribution<double> dist(min_val, max_val);
    std::vector<T> vec(n);
    for (size_t i = 0; i < n; ++i)
        vec[i] = static_cast<T>(dist(e));
    return vec;
}

// ---------------- CPU Reference (double accumulator) ----------------
template <typename T>
void mm_host(const T *A, const T *B, T *C, int N)
{
    for (int i = 0; i < N; ++i)
    {
        for (int j = 0; j < N; ++j)
        {
            double acc = 0.0;
            for (int k = 0; k < N; ++k)
                acc += static_cast<double>(A[i * N + k]) * static_cast<double>(B[k * N + j]);
            C[i * N + j] = static_cast<T>(acc);
        }
    }
}

// ---------------- Naive Global Memory Kernel (1D threads) ----------------
template <typename T>
__global__ void mm_naive(const T *A, const T *B, T *C, int N)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    int total_elems = N * N;
    if (tid >= total_elems)
        return;

    int row = tid / N;
    int col = tid % N;

    T val = 0;
    for (int k = 0; k < N; ++k)
        val += A[row * N + k] * B[k * N + col];

    C[tid] = val;
}

// ---------------- Tiled Shared Memory Kernel ----------------
template <typename T>
__global__ void mm_tiled(const T *A, const T *B, T *C, int N)
{
    __shared__ T tile_A[TILE_SIZE][TILE_SIZE];
    __shared__ T tile_B[TILE_SIZE][TILE_SIZE];

    int row = blockIdx.y * TILE_SIZE + threadIdx.y;
    int col = blockIdx.x * TILE_SIZE + threadIdx.x;

    T val = 0;

    for (int t = 0; t < (N + TILE_SIZE - 1) / TILE_SIZE; ++t)
    {
        if (row < N && (t * TILE_SIZE + threadIdx.x) < N)
            tile_A[threadIdx.y][threadIdx.x] = A[row * N + t * TILE_SIZE + threadIdx.x];
        else
            tile_A[threadIdx.y][threadIdx.x] = 0;

        if (col < N && (t * TILE_SIZE + threadIdx.y) < N)
            tile_B[threadIdx.y][threadIdx.x] = B[(t * TILE_SIZE + threadIdx.y) * N + col];
        else
            tile_B[threadIdx.y][threadIdx.x] = 0;

        __syncthreads();

        for (int k = 0; k < TILE_SIZE; ++k)
            val += tile_A[threadIdx.y][k] * tile_B[k][threadIdx.x];

        __syncthreads();
    }

    if (row < N && col < N)
        C[row * N + col] = val;
}

// ---------------- Validation (Relative Error) ----------------
template <typename T>
bool validate_results(const std::vector<T> &ref,
                      const std::vector<T> &gpu,
                      int N,
                      T rel_tol = static_cast<T>(1e-2))
{
    for (int i = 0; i < N; ++i)
    {
        for (int j = 0; j < N; ++j)
        {
            size_t idx = i * N + j;
            T diff = std::abs(ref[idx] - gpu[idx]);
            T denom = std::max(static_cast<T>(1.0), std::abs(ref[idx]));
            if (diff / denom > rel_tol)
            {
                std::cerr << "Mismatch at (" << i << ", " << j << "): "
                          << "CPU=" << ref[idx] << ", GPU=" << gpu[idx]
                          << ", rel_err=" << diff / denom << std::endl;
                return false;
            }
        }
    }
    return true;
}

// ---------------- CUDA Event Timing ----------------
template <typename KernelFunc, typename T>
float measure_kernel_time(KernelFunc kernel, int N, bool tiled)
{
    cudaEvent_t startEvent, stopEvent;
    checkCuda(cudaEventCreate(&startEvent));
    checkCuda(cudaEventCreate(&stopEvent));

    T *d_A, *d_B, *d_C;
    checkCuda(cudaMalloc(&d_A, sizeof(T) * N * N));
    checkCuda(cudaMalloc(&d_B, sizeof(T) * N * N));
    checkCuda(cudaMalloc(&d_C, sizeof(T) * N * N));

    dim3 threads, blocks;

    if (tiled)
    {
        threads = dim3(TILE_SIZE, TILE_SIZE);
        blocks = dim3((N + TILE_SIZE - 1) / TILE_SIZE,
                      (N + TILE_SIZE - 1) / TILE_SIZE);
    }
    else
    {
        int threadsPerBlock = 256;
        int totalThreads = N * N;
        blocks = dim3((totalThreads + threadsPerBlock - 1) / threadsPerBlock);
        threads = dim3(threadsPerBlock);
    }

    // Warm-up
    if (tiled)
        mm_tiled<T><<<blocks, threads>>>(d_A, d_B, d_C, N);
    else
        mm_naive<T><<<blocks, threads>>>(d_A, d_B, d_C, N);
    checkCuda(cudaDeviceSynchronize());

    // Timed run
    checkCuda(cudaEventRecord(startEvent, 0));
    if (tiled)
        mm_tiled<T><<<blocks, threads>>>(d_A, d_B, d_C, N);
    else
        mm_naive<T><<<blocks, threads>>>(d_A, d_B, d_C, N);
    checkCuda(cudaEventRecord(stopEvent, 0));
    checkCuda(cudaEventSynchronize(stopEvent));

    float time_ms;
    checkCuda(cudaEventElapsedTime(&time_ms, startEvent, stopEvent));

    checkCuda(cudaFree(d_A));
    checkCuda(cudaFree(d_B));
    checkCuda(cudaFree(d_C));
    return time_ms;
}

// ---------------- Main ----------------
int main()
{
    const int N = MAT_DIM;
    std::vector<float> h_A = create_rand_vector<float>(N * N);
    std::vector<float> h_B = create_rand_vector<float>(N * N);
    std::vector<float> h_C_ref(N * N, 0);
    std::vector<float> h_C_gpu_tiled(N * N, 0);
    std::vector<float> h_C_gpu_naive(N * N, 0);

    std::cout << "Running CPU reference..." << std::endl;
    mm_host(h_A.data(), h_B.data(), h_C_ref.data(), N);

    float *d_A, *d_B, *d_C;
    checkCuda(cudaMalloc(&d_A, sizeof(float) * N * N));
    checkCuda(cudaMalloc(&d_B, sizeof(float) * N * N));
    checkCuda(cudaMalloc(&d_C, sizeof(float) * N * N));

    checkCuda(cudaMemcpy(d_A, h_A.data(), sizeof(float) * N * N, cudaMemcpyHostToDevice));
    checkCuda(cudaMemcpy(d_B, h_B.data(), sizeof(float) * N * N, cudaMemcpyHostToDevice));

    // ---- Run Naive Kernel ----
    {
        int threadsPerBlock = 256;
        int totalThreads = N * N;
        dim3 blocks((totalThreads + threadsPerBlock - 1) / threadsPerBlock);
        dim3 threads(threadsPerBlock);
        mm_naive<float><<<blocks, threads>>>(d_A, d_B, d_C, N);
        checkCuda(cudaDeviceSynchronize());
        checkCuda(cudaMemcpy(h_C_gpu_naive.data(), d_C, sizeof(float) * N * N, cudaMemcpyDeviceToHost));
    }

    // ---- Run Tiled Kernel ----
    {
        dim3 threads(TILE_SIZE, TILE_SIZE);
        dim3 blocks((N + TILE_SIZE - 1) / TILE_SIZE, (N + TILE_SIZE - 1) / TILE_SIZE);
        mm_tiled<float><<<blocks, threads>>>(d_A, d_B, d_C, N);
        checkCuda(cudaDeviceSynchronize());
        checkCuda(cudaMemcpy(h_C_gpu_tiled.data(), d_C, sizeof(float) * N * N, cudaMemcpyDeviceToHost));
    }

    // ---- Validate ----
    std::cout << "Validating tiled version..." << std::endl;
    bool ok_tiled = validate_results(h_C_ref, h_C_gpu_tiled, N);
    bool ok_naive = validate_results(h_C_ref, h_C_gpu_naive, N);

    if (!ok_tiled || !ok_naive)
    {
        std::cerr << "Validation FAILED." << std::endl;
        return 1;
    }
    std::cout << "Validation PASSED for both." << std::endl;

    // ---- Measure Runtime ----
    float time_naive = measure_kernel_time<decltype(mm_naive<float>), float>(mm_naive<float>, N, false);
    float time_tiled = measure_kernel_time<decltype(mm_tiled<float>), float>(mm_tiled<float>, N, true);

    std::cout << std::fixed << std::setprecision(4);
    std::cout << "Naive (global memory): " << time_naive << " ms" << std::endl;
    std::cout << "Tiled (shared memory): " << time_tiled << " ms" << std::endl;
    std::cout << "Speedup: " << time_naive / time_tiled << "x" << std::endl;

    checkCuda(cudaFree(d_A));
    checkCuda(cudaFree(d_B));
    checkCuda(cudaFree(d_C));
    return 0;
}