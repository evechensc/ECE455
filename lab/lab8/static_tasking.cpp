#include <taskflow/taskflow.hpp> // Taskflow header

int main()
{
    tf::Executor executor;
    tf::Taskflow taskflow("Static Taskflow Demo");
    auto A = taskflow.emplace([]()
                              { printf("Task A\n"); });
    auto B = taskflow.emplace([]()
                              { printf("Task B\n"); });
    auto C = taskflow.emplace([]()
                              { printf("Task C\n"); });
    auto D = taskflow.emplace([]()
                              { printf("Task D\n"); });
    // Define dependencies: A precedes B and C; both B and C precede D.
    A.precede(B, C);
    B.precede(D);
    C.precede(D);
    executor.run(taskflow).wait();
}