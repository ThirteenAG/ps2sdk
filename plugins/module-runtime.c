/* Startup for injected modules; game patches remain in the existing init(). */
#include "guest_module.h"
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#ifndef MODULE_STACK_SIZE
#define MODULE_STACK_SIZE (64 * 1024)
#endif
#ifndef MODULE_HEAP_SIZE
#define MODULE_HEAP_SIZE (1024 * 1024)
#endif

extern void init(void);
extern void (*__init_array_start[])(void);
extern void (*__init_array_end[])(void);

typedef struct Block {
    size_t size;
    struct Block* next;
    uint32_t free, reserved;
} Block;
static Block* heap;
static uint8_t* heap_end;
const struct PCSX2FModuleContext* PCSX2FContext;

static void module_entry(const void* raw)
{
    const struct PCSX2FModuleContext* context = raw;
    if (!context || context->size != sizeof(*context) || context->version != PCSX2F_MODULE_VERSION) return;
    PCSX2FContext = context;
    heap_end = (uint8_t*)(uintptr_t)context->heap_end;
    if (context->heap_end - context->heap_begin >= sizeof(Block) + 16) {
        heap = (Block*)(uintptr_t)context->heap_begin;
        heap->size = context->heap_end - context->heap_begin - sizeof(Block);
        heap->next = NULL; heap->free = 1;
    }
    for (void (**ctor)(void) = __init_array_start; ctor != __init_array_end; ++ctor) (*ctor)();
    init();
}
PCSX2F_MODULE(module_entry, MODULE_STACK_SIZE, MODULE_HEAP_SIZE);

void* malloc(size_t size)
{
    if (!size) size = 1;
    if (size > SIZE_MAX - 15) return NULL;
    size = (size + 15) & ~(size_t)15;
    for (Block* block = heap; block; block = block->next) {
        if (!block->free || block->size < size) continue;
        if (block->size >= size + sizeof(Block) + 16) {
            Block* tail = (Block*)((uint8_t*)(block + 1) + size);
            tail->size = block->size - size - sizeof(Block);
            tail->next = block->next; tail->free = 1;
            block->next = tail; block->size = size;
        }
        block->free = 0;
        return block + 1;
    }
    return NULL;
}
void free(void* pointer)
{
    if (!pointer) return;
    if ((uintptr_t)pointer < (uintptr_t)heap + sizeof(Block) || (uintptr_t)pointer >= (uintptr_t)heap_end) return;
    for (Block* block = heap; block; block = block->next) {
        if (block + 1 != pointer) continue;
        block->free = 1;
        for (Block* merge = heap; merge && merge->next;) {
            if (merge->free && merge->next->free) {
                merge->size += sizeof(Block) + merge->next->size;
                merge->next = merge->next->next;
            } else merge = merge->next;
        }
        return;
    }
}
void* calloc(size_t count, size_t size)
{
    if (size && count > SIZE_MAX / size) return NULL;
    size *= count;
    void* pointer = malloc(size);
    if (pointer) memset(pointer, 0, size);
    return pointer;
}
void* realloc(void* pointer, size_t size)
{
    if (!pointer) return malloc(size);
    if (!size) { free(pointer); return NULL; }
    for (Block* block = heap; block; block = block->next) {
        if (block + 1 != pointer || block->free) continue;
        if (block->size >= size) return pointer;
        void* replacement = malloc(size);
        if (replacement) { memcpy(replacement, pointer, block->size); free(pointer); }
        return replacement;
    }
    return NULL;
}
/* Newlib's reentrant helpers also stay within the module's private heap. */
struct _reent;
void* _malloc_r(struct _reent* r, size_t n) { (void)r; return malloc(n); }
void* _calloc_r(struct _reent* r, size_t n, size_t s) { (void)r; return calloc(n, s); }
void* _realloc_r(struct _reent* r, void* p, size_t n) { (void)r; return realloc(p, n); }
void _free_r(struct _reent* r, void* p) { (void)r; free(p); }
/* A guest plugin cannot terminate the game/process through a standalone CRT. */
__attribute__((noreturn)) void _exit(int status)
{
    (void)status;
    __builtin_trap();
    __builtin_unreachable();
}
