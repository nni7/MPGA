#ifndef MPGA_HPP
#define MPGA_HPP

#include <iostream>
#include <tuple>
#include <utility>
#include <string>
#include <type_traits>
#include <cstdlib>

namespace MPGA {

// --- Интроспекция (Arity) ---
template <typename T>
struct function_traits : function_traits<decltype(&T::operator())> {};

template <typename C, typename R, typename... Args>
struct function_traits<R(C::*)(Args...) const> {
    static constexpr size_t arity = sizeof...(Args);
};

template <typename C, typename R, typename... Args>
struct function_traits<R(C::*)(Args...)> {
    static constexpr size_t arity = sizeof...(Args);
};

template <typename T>
concept IsCallable = requires { &std::remove_cvref_t<T>::operator(); } 
                  || std::is_function_v<std::remove_pointer_t<std::remove_cvref_t<T>>>;

template <typename T, typename A>
struct StepResult {
    T tasks;
    A acc;
};

// --- Функция STEP (Основная реализация) ---
// Теперь tasks (t) идет первым, acc — вторым.
template <size_t Index = 0, typename... Args, typename... Acc>
auto step(std::tuple<Args...>&& t, std::tuple<Acc...>&& acc) {
    constexpr size_t Size = sizeof...(Args);

    if constexpr (Index >= Size) {
        return StepResult{std::tuple<>{}, std::move(acc)};
    } else {
        auto&& current = std::get<Index>(t);
        using F = std::remove_cvref_t<decltype(current)>;

        if constexpr (IsCallable<F>) {
            constexpr size_t needed = function_traits<F>::arity;
            constexpr size_t available = sizeof...(Acc);

            if constexpr (available < needed) {
                std::cerr << "\n[MPGA FATAL] Argument count mismatch at step index [" << Index << "]\n"
                          << "  Function needs: " << needed << " argument(s)\n"
                          << "  Available in accumulator: " << available << "\n";
                std::abort();
            } else {
                auto call_acc = [&]<size_t... Is>(std::index_sequence<Is...>) {
                    return std::forward_as_tuple(std::get<(available - needed) + Is>(std::move(acc))...);
                }(std::make_index_sequence<needed>{});

                if constexpr (!requires { std::apply(current, std::move(call_acc)); }) {
                    std::cerr << "\n[MPGA FATAL] Type mismatch at step index [" << Index << "]\n"
                              << "  The provided " << needed << " argument(s) do not match function signature.\n";
                    std::abort();
                } else {
                    if constexpr (available > needed) {
                        std::cout << "[MPGA NOTE] Step " << Index << ": Function consumed last " << needed 
                                  << " item(s). " << (available - needed) << " item(s) remain in accumulator.\n";
                    }

                    auto unused_acc = [&]<size_t... Is>(std::index_sequence<Is...>) {
                        return std::make_tuple(std::get<Is>(std::move(acc))...);
                    }(std::make_index_sequence<available - needed>{});

                    auto tail = [&]<size_t... Is>(std::index_sequence<Is...>) {
                        return std::make_tuple(std::get<Is + Index + 1>(std::move(t))...);
                    }(std::make_index_sequence<Size - Index - 1>{});

                    using RetType = decltype(std::apply(current, std::move(call_acc)));

                    if constexpr (std::is_void_v<RetType>) {
                        std::apply(current, std::move(call_acc));
                        return StepResult{std::move(tail), std::move(unused_acc)};
                    } else {
                        auto result = std::apply(current, std::move(call_acc));
                        auto new_tasks = std::tuple_cat(std::make_tuple(std::move(result)), std::move(tail));
                        return StepResult{std::move(new_tasks), std::move(unused_acc)};
                    }
                }
            }
        } else {
            // Рекурсивный вызов: данные переходят в аккумулятор
            return step<Index + 1>(std::move(t), std::tuple_cat(std::move(acc), std::make_tuple(std::move(current))));
        }
    }
}

// --- Перегрузка STEP (Опциональный acc) ---
template <size_t Index = 0, typename... Args>
auto step(std::tuple<Args...>&& t) {
    return step<Index>(std::move(t), std::tuple<>{});
}

// --- Функция FLOW ---
template <typename... Args>
void flow(std::tuple<Args...> t) {
    if constexpr (sizeof...(Args) == 0) return;
    else {
        // Теперь вызываем step только с одним аргументом — красиво!
        auto state = step(std::move(t)); 
        
        if constexpr (std::tuple_size_v<decltype(state.tasks)> > 0) {
            flow(std::tuple_cat(std::move(state.acc), std::move(state.tasks)));
        } else {
            std::cout << "[MPGA] Pipeline finished successfully.\n";
        }
    }
}

template <typename... Args>
void flow(Args&&... args) {
    flow(std::make_tuple(std::forward<Args>(args)...));
}

} // namespace MPGA

#endif
