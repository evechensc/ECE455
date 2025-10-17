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

// ---------- CUDA Error Checking ----------
#define checkCuda(val) check((val), #val, __FILE__, __LINE__)
void check(cudaError_t err, const char *const func, const char *const file, int line)
{
    if (err != cudaSuccess)
    {
        std::cerr << "CUDA Runtime Error at " << file << ":" << line << " — "
                  << cudaGetErrorString(err) << " (" << func << ")" << std::endl;
        std::exit(EXIT_FAILURE);
    }
}

// ---------- Random Initialization ----------
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

// ---------- CPU Reference Implementation (double accumulator) ----------
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

// ---------- GPU Shared Memory Kernel (Tiled) ----------
template <typename T>
__global__ void mm_tiled(const T *A, const T *B, T *C, int N)
{
    // Shared-memory tiles for A and B
    __shared__ T tile_A[TILE_SIZE][TILE_SIZE];
    __shared__ T tile_B[TILE_SIZE][TILE_SIZE];

    // Global row/col this thread computes
    int row = blockIdx.y * TILE_SIZE + threadIdx.y;
    int col = blockIdx.x * TILE_SIZE + threadIdx.x;

    T val = 0;

    // Loop over all sub-tiles of A and B needed to compute this C element
    for (int t = 0; t < (N + TILE_SIZE - 1) / TILE_SIZE; ++t)
    {

        // Load a tile of A into shared memory
        if (row < N && (t * TILE_SIZE + threadIdx.x) < N)
            tile_A[threadIdx.y][threadIdx.x] =
                A[row * N + t * TILE_SIZE + threadIdx.x];
        else
            tile_A[threadIdx.y][threadIdx.x] = 0;

        // Load a tile of B into shared memory
        if (col < N && (t * TILE_SIZE + threadIdx.y) < N)
            tile_B[threadIdx.y][threadIdx.x] =
                B[(t * TILE_SIZE + threadIdx.y) * N + col];
        else
            tile_B[threadIdx.y][threadIdx.x] = 0;

        __syncthreads(); // Wait until all data is loaded

        // Compute partial products
        for (int k = 0; k < TILE_SIZE; ++k)
            val += tile_A[threadIdx.y][k] * tile_B[k][threadIdx.x];

        __syncthreads(); // Wait before loading next tiles
    }

    // Store the result
    if (row < N && col < N)
        C[row * N + col] = val;
}

// ---------- GPU Launcher ----------
template <typename T>
void mm_cuda(const T *d_A, const T *d_B, T *d_C, int N)
{
    dim3 threadsPerBlock(TILE_SIZE, TILE_SIZE);
    dim3 blocksPerGrid((N + TILE_SIZE - 1) / TILE_SIZE,
                       (N + TILE_SIZE - 1) / TILE_SIZE);
    mm_tiled<T><<<blocksPerGrid, threadsPerBlock>>>(d_A, d_B, d_C, N);
}

// ---------- Validation (Relative Error) ----------
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

// ---------- CUDA Event Timing ----------
template <typename T>
float measure_latency_mm_cuda(int N, int num_tests, int num_warmups)
{
    cudaEvent_t startEvent, stopEvent;
    float time_ms{0.0f};

    checkCuda(cudaEventCreate(&startEvent));
    checkCuda(cudaEventCreate(&stopEvent));

    T *d_A, *d_B, *d_C;
    checkCuda(cudaMalloc(&d_A, sizeof(T) * N * N));
    checkCuda(cudaMalloc(&d_B, sizeof(T) * N * N));
    checkCuda(cudaMalloc(&d_C, sizeof(T) * N * N));

    for (int i = 0; i < num_warmups; ++i)
        mm_cuda<T>(d_A, d_B, d_C, N);

    checkCuda(cudaEventRecord(startEvent, 0));
    for (int i = 0; i < num_tests; ++i)
        mm_cuda<T>(d_A, d_B, d_C, N);
    checkCuda(cudaEventRecord(stopEvent, 0));
    checkCuda(cudaEventSynchronize(stopEvent));
    checkCuda(cudaEventElapsedTime(&time_ms, startEvent, stopEvent));

    checkCuda(cudaFree(d_A));
    checkCuda(cudaFree(d_B));
    checkCuda(cudaFree(d_C));

    return time_ms / num_tests;
}

// ---------- Main ----------
int main()
{
    const int N = MAT_DIM;
    std::vector<float> h_A = create_rand_vector<float>(N * N);
    std::vector<float> h_B = create_rand_vector<float>(N * N);
    std::vector<float> h_C_ref(N * N, 0);
    std::vector<float> h_C_gpu(N * N, 0);

    std::cout << "Running CPU reference..." << std::endl;
    mm_host(h_A.data(), h_B.data(), h_C_ref.data(), N);

    float *d_A, *d_B, *d_C;
    checkCuda(cudaMalloc(&d_A, sizeof(float) * N * N));
    checkCuda(cudaMalloc(&d_B, sizeof(float) * N * N));
    checkCuda(cudaMalloc(&d_C, sizeof(float) * N * N));

    checkCuda(cudaMemcpy(d_A, h_A.data(), sizeof(float) * N * N, cudaMemcpyHostToDevice));
    checkCuda(cudaMemcpy(d_B, h_B.data(), sizeof(float) * N * N, cudaMemcpyHostToDevice));

    // ---- Run tiled kernel ----
    mm_cuda<float>(d_A, d_B, d_C, N);
    checkCuda(cudaDeviceSynchronize());
    checkCuda(cudaMemcpy(h_C_gpu.data(), d_C, sizeof(float) * N * N, cudaMemcpyDeviceToHost));

    // ---- Validate ----
    std::cout << "Validating results..." << std::endl;
    bool ok = validate_results(h_C_ref, h_C_gpu, N);
    if (!ok)
    {
        std::cerr << "Validation FAILED." << std::endl;
        return 1;
    }
    std::cout << "Validation PASSED." << std::endl;

    // ---- Measure average runtime ----
    const int num_measurement_tests = 3;
    const int num_measurement_warmups = 1;
    float avg_ms = measure_latency_mm_cuda<float>(N, num_measurement_tests, num_measurement_warmups);
    std::cout << "Average kernel runtime: " << std::fixed << std::setprecision(4)
              << avg_ms << " ms" << std::endl;

    checkCuda(cudaFree(d_A));
    checkCuda(cudaFree(d_B));
    checkCuda(cudaFree(d_C));
    return 0;
}