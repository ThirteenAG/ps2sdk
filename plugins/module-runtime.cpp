#include <cstddef>
#include <cstdlib>
#include <new>
#include <bits/functexcept.h>

// Modules are reset with guest memory. No process CRT or emulator-owned heap.
extern "C" {
void* __dso_handle = &__dso_handle;
struct Destructor { void (*function)(void*); void* object; void* dso; };
static Destructor destructors[256];
static unsigned destructor_count;
int __cxa_atexit(void (*function)(void*), void* object, void* dso)
{
    if (destructor_count == 256) return -1;
    destructors[destructor_count++] = {function, object, dso};
    return 0;
}
void __cxa_finalize(void* dso)
{
    for (unsigned i = destructor_count; i; --i) {
        auto& item = destructors[i - 1];
        if (!item.function || (dso && dso != item.dso)) continue;
        auto function = item.function; item.function = nullptr; function(item.object);
    }
}
int __cxa_guard_acquire(unsigned long long* guard) { return !*(unsigned char*)guard; }
void __cxa_guard_release(unsigned long long* guard) { *(unsigned char*)guard = 1; }
void __cxa_guard_abort(unsigned long long*) {}
[[noreturn]] void abort() { __builtin_trap(); __builtin_unreachable(); }
[[noreturn]] void __cxa_pure_virtual() { abort(); }
}
// Weak definitions preserve plugins which already supply their own allocator.
__attribute__((weak)) void* operator new(std::size_t size)
{
    if (auto p = std::malloc(size)) return p;
    std::abort();
}
__attribute__((weak)) void* operator new[](std::size_t size) { return ::operator new(size); }
__attribute__((weak)) void operator delete(void* p) noexcept { std::free(p); }
__attribute__((weak)) void operator delete[](void* p) noexcept { ::operator delete(p); }
__attribute__((weak)) void operator delete(void* p, std::size_t) noexcept { ::operator delete(p); }
__attribute__((weak)) void operator delete[](void* p, std::size_t) noexcept { ::operator delete[](p); }
// Exception-disabled STL must fail at the error site, without pulling in a
// second process CRT and unwinder. Valid existing plugin paths are unchanged.
namespace std {
[[noreturn]] void __throw_bad_exception() { abort(); }
[[noreturn]] void __throw_bad_alloc() { abort(); }
[[noreturn]] void __throw_bad_array_new_length() { abort(); }
[[noreturn]] void __throw_bad_cast() { abort(); }
[[noreturn]] void __throw_bad_typeid() { abort(); }
[[noreturn]] void __throw_logic_error(const char*) { abort(); }
[[noreturn]] void __throw_domain_error(const char*) { abort(); }
[[noreturn]] void __throw_invalid_argument(const char*) { abort(); }
[[noreturn]] void __throw_length_error(const char*) { abort(); }
[[noreturn]] void __throw_out_of_range(const char*) { abort(); }
[[noreturn]] void __throw_out_of_range_fmt(const char*, ...) { abort(); }
[[noreturn]] void __throw_runtime_error(const char*) { abort(); }
[[noreturn]] void __throw_range_error(const char*) { abort(); }
[[noreturn]] void __throw_overflow_error(const char*) { abort(); }
[[noreturn]] void __throw_underflow_error(const char*) { abort(); }
[[noreturn]] void __throw_system_error(int) { abort(); }
[[noreturn]] void __throw_bad_function_call() { abort(); }
}
