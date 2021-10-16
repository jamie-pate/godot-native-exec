#pragma once

#include <Godot.hpp>
#include <Reference.hpp>

namespace godot {
    class NativeExec: public Reference {
        GODOT_CLASS(NativeExec, Reference)
    public:
        static void _register_methods();
        int exec();
    };
};
