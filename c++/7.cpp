#include "mpga.hpp"
#include <iostream>
#include <string>

int main() {
    using namespace MPGA;

    // Сценарий 1: Успешная цепочка
    std::cout << "--- Scenario: Normal Flow ---\n";
    auto step1 = [](int a, int b) {
        return a + b;
    };

    auto step2 = [](int result, std::string prefix) {
        std::cout << "  " << prefix << ": " << result << "\n";
    };

    // 10 и 20 уйдут в step1. "Result is" останется в acc.
    // Затем результат step1 (30) и "Result is" уйдут в step2.
    flow(10, 20, step1, std::string("Result is"), step2);

    std::cout << "\n--- Scenario: Extra Data Note ---\n";
    // Здесь '42' останется нетронутым, так как функции нужно только 1 число
    flow(42, 100, [](int x) { std::cout << "  Got: " << x << "\n"; });

    /* // ТЕСТЫ ОШИБОК (раскомментируйте один для проверки std::abort)

    // Ошибка: мало аргументов
    // flow(10, [](int a, int b){}); 

    // Ошибка: неверный тип (передали строку вместо int)
    // flow("Hello", [](int a){}); 
    */

    return 0;
}
