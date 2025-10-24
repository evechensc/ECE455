#include <iostream>
#include <vector>
#include <cmath>
#include <random>
#include <fstream>
#include <iomanip>

// define our own pi so we don't depend on M_PI
constexpr double kPi = 3.14159265358979323846;

int main()
{
    // basic settings
    const int N = 1000;           // number of samples
    const double fs = 1000.0;     // sample rate (samples per second)
    const double f_signal = 50.0; // Hz, your "real" tone frequency
    const double noise_amp = 0.3; // strength of random noise

    // make a RNG for noise (better than rand())
    std::mt19937 rng(12345);
    std::uniform_real_distribution<double> uni(-0.5, 0.5);

    std::vector<double> signal(N);
    for (int n = 0; n < N; ++n)
    {
        double t = n / fs;                                // time in seconds
        double pure = std::sin(2.0 * kPi * f_signal * t); // clean tone
        double noise = noise_amp * uni(rng);              // random noise
        signal[n] = pure + noise;                         // noisy signal
    }

    // print a few values so you see output
    std::cout << "First 10 samples of the noisy signal:\n";
    for (int i = 0; i < 10; ++i)
    {
        std::cout << "signal[" << i << "] = " << signal[i] << "\n";
    }

    // also save to a CSV so you can plot if you want
    std::ofstream file("noisy_signal.csv");
    if (file)
    {
        file << "t,signal\n";
        for (int n = 0; n < N; ++n)
        {
            double t = n / fs;
            file << std::fixed << std::setprecision(9) << t << "," << signal[n] << "\n";
        }
        std::cout << "Wrote noisy_signal.csv\n";
    }
    else
    {
        std::cout << "Could not open noisy_signal.csv for writing.\n";
    }

    return 0;
}