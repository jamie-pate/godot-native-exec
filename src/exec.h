#pragma once

#include <cstddef>
#include <Godot.hpp>
#include <Reference.hpp>

// 10 minute timeout by default
#define DEFAULT_EXEC_TIMEOUT_MS 60 * 10 * 1000
namespace godot {
    class NativeExec: public Reference {
        GODOT_CLASS(NativeExec, Reference);
    private:
        uint64_t readOutput(void * childStdOut, void *childStdErr, PoolStringArray stdout_, PoolStringArray stderr_, godot_int timeoutMs);
    public:
        static void _register_methods();
        godot_bool exec(String cmd, PoolStringArray stdout_, PoolStringArray stderr_, godot_int timeoutMs = DEFAULT_EXEC_TIMEOUT_MS);
    };
};
