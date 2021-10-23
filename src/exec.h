#pragma once

#include <cstddef>
#include <Godot.hpp>
#include <Reference.hpp>

namespace godot {
    class NativeExec: public Reference {
        GODOT_CLASS(NativeExec, Reference);
    public:
        NativeExec();
        ~NativeExec();
        void _init();
        static void _register_methods();
        godot_int exec(String cmd, PoolStringArray args, Array stdout_, Array stderr_, godot_int timeoutMs);
    };
};
