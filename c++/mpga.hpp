#ifndef MPGA_HPP
#define MPGA_HPP

#include <iostream>
#include <tuple>
#include <utility>
#include <string>
#include <type_traits>
#include <cstdlib>

namespace MPGA {

// --- Управляющие типы ---
struct Stop {};

template <typename... T> struct Redirect { 
    std::tuple<T...> next_path; 
    Redirect(T... args) : next_path(std::make_tuple(std::move(args)...)) {}
};

template <typename... T> struct RedirectWithReset { 
    std::tuple<T...> next_path; 
    RedirectWithReset(T... args) : next_path(std::make_tuple(std::move(args)...)) {}
};

// --- Трейты ---
template <typename T> struct is_tuple : std::false_type {};
template <typename... Args> struct is_tuple<std::tuple<Args...>> : std::true_type {};

template <typename T> struct is_redirect : std::false_type {};
template <typename... Args> struct is_redirect<Redirect<Args...>> : std::true_type {};

template <typename T> struct is_redirect_reset : std::false_type {};
template <typename... Args> struct is_redirect_reset<RedirectWithReset<Args...>> : std::true_type {};

template <typename T>
struct function_traits : function_traits<decltype(&T::operator())> {};
template <typename C, typename R, typename... Args>
struct function_traits<R(C::*)(Args...) const> { static constexpr size_t arity = sizeof...(Args); };
template <typename C, typename R, typename... Args>
struct function_traits<R(C::*)(Args...)> { static constexpr size_t arity = sizeof...(Args); };
template <typename R, typename... Args>
struct function_traits<R(*)(Args...)> { static constexpr size_t arity = sizeof...(Args); };

template <typename T>
concept IsCallable = requires { &std::remove_cvref_t<T>::operator(); } 
                  || std::is_function_v<std::remove_pointer_t<std::remove_cvref_t<T>>>;

template <typename T, typename A>
struct StepResult { T tasks; A acc; };

// --- Функция STEP ---
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
                std::cerr << "\n[MPGA FATAL] Not enough args for step " << Index << "\n";
                std::abort();
            } else {
                auto call_acc = [&]<size_t... Is>(std::index_sequence<Is...>) {
                    return std::forward_as_tuple(std::get<(available - needed) + Is>(std::move(acc))...);
                }(std::make_index_sequence<needed>{});

                if constexpr (!requires { std::apply(current, std::move(call_acc)); }) {
                    std::cerr << "\n[MPGA FATAL] Type mismatch at step " << Index << "\n";
                    std::abort();
                } else {
                    using RetType = std::remove_cvref_t<decltype(std::apply(current, std::move(call_acc)))>;
                    
                    auto unused_acc = [&]<size_t... Is>(std::index_sequence<Is...>) {
                        return std::make_tuple(std::get<Is>(std::move(acc))...);
                    }(std::make_index_sequence<available - needed>{});

                    auto tail = [&]<size_t... Is>(std::index_sequence<Is...>) {
                        return std::make_tuple(std::get<Is + Index + 1>(std::move(t))...);
                    }(std::make_index_sequence<Size - Index - 1>{});

                    // 1. STOP
                    if constexpr (std::is_same_v<RetType, Stop>) {
                        return StepResult{std::tuple<>{}, std::tuple<>{}};
                    }
                    // 2. REDIRECT (Замена хвоста)
                    else if constexpr (is_redirect<RetType>::value) {
                        auto res = std::apply(current, std::move(call_acc));
                        return StepResult{std::move(res.next_path), std::move(unused_acc)};
                    }
                    // 3. REDIRECT WITH RESET (Замена хвоста + чистка acc)
                    else if constexpr (is_redirect_reset<RetType>::value) {
                        auto res = std::apply(current, std::move(call_acc));
                        return StepResult{std::move(res.next_path), std::tuple<>{}};
                    }
                    // 4. TUPLE (Распаковка и вставка В НАЧАЛО текущего хвоста)
                    else if constexpr (is_tuple<RetType>::value) {
                        auto res = std::apply(current, std::move(call_acc));
                        return StepResult{std::tuple_cat(std::move(res), std::move(tail)), std::move(unused_acc)};
                    }
                    // 5. VOID
                    else if constexpr (std::is_void_v<RetType>) {
                        std::apply(current, std::move(call_acc));
                        return StepResult{std::move(tail), std::move(unused_acc)};
                    }
                    // 6. SINGLE VALUE (int, string, etc.)
                    else {
                        auto res = std::apply(current, std::move(call_acc));
                        return StepResult{std::tuple_cat(std::make_tuple(std::move(res)), std::move(tail)), std::move(unused_acc)};
                    }
                }
            }
        } else {
            return step<Index + 1>(std::move(t), std::tuple_cat(std::move(acc), std::make_tuple(std::move(current))));
        }
    }
}

template <size_t Index = 0, typename... Args>
auto step(std::tuple<Args...>&& t) { return step<Index>(std::move(t), std::tuple<>{}); }

template <typename... Args>
void flow(std::tuple<Args...> t) {
    if constexpr (sizeof...(Args) == 0) return;
    else {
        auto state = step(std::move(t)); 
        if constexpr (std::tuple_size_v<decltype(state.tasks)> > 0) {
            flow(std::tuple_cat(std::move(state.acc), std::move(state.tasks)));
        }
    }
}

template <typename... Args>
void flow(Args&&... args) { flow(std::make_tuple(std::forward<Args>(args)...)); }

} // namespace MPGA

#endif
