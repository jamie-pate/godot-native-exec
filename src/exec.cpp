#include "exec.h"
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <array>

#define BUFSIZE 4096
#define snwprintf _snwprintf
#define wtoi _wtoi

using namespace godot;

HANDLE CreateChildProcess(String cmdline, PoolStringArray args, HANDLE childStdIn, HANDLE childStdOut, HANDLE childStdErr);

#ifdef DEBUG
#define debug_print(msg) Godot::print(msg)
#else
#define debug_print(msg)
#endif

#define PRINT_ERROR(desc, err) _godot_print_error(desc, err, __PRETTY_FUNCTION__, __FILE__, __LINE__)
static void _godot_print_error(const char *p_description, int err, const char *p_function, const char *p_file, int p_line) {
    String msg = p_description;
    if (err) {
        msg += " (" + String::num_int64(err) + ")";
        wchar_t *formatted = NULL;
        DWORD fmtChars = FormatMessageW(
            FORMAT_MESSAGE_ALLOCATE_BUFFER |
            FORMAT_MESSAGE_IGNORE_INSERTS |
            FORMAT_MESSAGE_FROM_SYSTEM,
            NULL,
            err,
            MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
            (LPWSTR)&formatted,
            0,
            NULL);
        if (fmtChars > 0) {
            msg += ": " + String(formatted);
            LocalFree(formatted);
        }
    }
    Godot::print_error(msg, p_function, p_file, p_line);
}


static size_t readToArray(HANDLE handle, Array output) {
    bool success = false;
    DWORD read_bytes;
    char *buf;
    success = PeekNamedPipe(handle, NULL, 0, NULL, &read_bytes, NULL);
    if (success && read_bytes > 0) {
        buf = (char *)godot::api->godot_alloc(read_bytes + 1);
        buf[read_bytes] = 0;
        success = ReadFile(handle, buf, read_bytes, &read_bytes, NULL);
        if (success && read_bytes > 0) {
            String str = buf;
            debug_print(str);
            output.append(str);
        }
        godot::api->godot_free(buf);
    }
    return success ? read_bytes : 0;
}

void NativeExec::_register_methods() {
    debug_print("Register NativeExec!");
    register_method("exec", &NativeExec::exec);
}

NativeExec::NativeExec() {
    debug_print("NativeExec()");
}
NativeExec::~NativeExec() {
    debug_print("~NativeExec()");
}

void NativeExec::_init() {
    debug_print("NativeExec::_init()");
}

/**
 * Read the output from the process stdout and stderr streams and add them to the stdout_ and stderr_ arrays.
 * Returns the elapsed time spent reading before the handles were closed.
 */
static ULONGLONG readOutput(HANDLE processHandle, HANDLE childStdOut, HANDLE childStdErr, Array stdout_, Array stderr_, DWORD timeoutMs) {
    HANDLE handles[] = {childStdOut, childStdErr};
    Array output[] = {stdout_, stderr_};
    // use this? https://github.com/erezwanderman/Read_StdOut_StdErr_WIN32/blob/master/ParentProcess/ReadMultiplePipes.cpp
    ULONGLONG startTime = GetTickCount64();
    ULONGLONG elapsedMs = 0;
    if (timeoutMs != INFINITE && timeoutMs < 0) {
        timeoutMs = 0;
    }
    const size_t handleCount = 2;
    const DWORD maxTimeout = 250;
    while (timeoutMs == INFINITE || elapsedMs < (ULONGLONG)timeoutMs) {
        debug_print("WaitForObject " + String::num_int64(timeoutMs - elapsedMs));
        DWORD timeout = timeoutMs == INFINITE ? INFINITE : timeoutMs - elapsedMs;
        DWORD waitResult = WaitForSingleObject(processHandle, timeout < maxTimeout ? timeout : maxTimeout);
        for (size_t i = 0; i < handleCount; ++i) {
            size_t bytes = 0;
            while (bytes = readToArray(handles[i], output[i])) {
                debug_print("read " + String::num_int64(i) + " " + String::num_int64(bytes));
            }
        }
        if (waitResult != WAIT_TIMEOUT) {
            break;
        }
        elapsedMs = GetTickCount64() - startTime;
    }
    // drain the pipes
    debug_print("drain");
    for (size_t i = 0; i < handleCount; ++i) {
        size_t bytes = 0;
        while (bytes = readToArray(handles[i], output[i])) {
            debug_print("drained " + String::num_int64(bytes));
        }
    }
    return GetTickCount64() - startTime;
}

godot_int NativeExec::exec(String cmd, PoolStringArray args, Array stdout_, Array stderr_, godot_int timeoutMs) {
    debug_print("NativeExec::exec()");
    HANDLE childStdInRd = INVALID_HANDLE_VALUE;
    HANDLE childStdInWr = INVALID_HANDLE_VALUE;
    HANDLE childStdOutRd = INVALID_HANDLE_VALUE;
    HANDLE childStdOutWr = INVALID_HANDLE_VALUE;
    HANDLE childStdErrRd = INVALID_HANDLE_VALUE;
    HANDLE childStdErrWr = INVALID_HANDLE_VALUE;
    HANDLE processHandle = INVALID_HANDLE_VALUE;

    DWORD exitCode = 0;
    DWORD waitResult = 0;

    DWORD apiTimeout = INFINITE;
    DWORD duration = INFINITE;

    SECURITY_ATTRIBUTES sAttr;

    sAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
    sAttr.bInheritHandle = true;
    sAttr.lpSecurityDescriptor = nullptr;

    if (!CreatePipe(&childStdOutRd, &childStdOutWr, &sAttr, 0)) {
        goto exit;
    }
    if (!SetHandleInformation(childStdOutRd, HANDLE_FLAG_INHERIT, 0)) {
        goto exit;
    }
    if (!CreatePipe(&childStdErrRd, &childStdErrWr, &sAttr, 0)) {
        goto exit;
    }
    if (!SetHandleInformation(childStdErrRd, HANDLE_FLAG_INHERIT, 0)) {
        goto exit;
    }
    if (!CreatePipe(&childStdInRd, &childStdInWr, &sAttr, 0)) {
        goto exit;
    }
    if (!SetHandleInformation(childStdInWr, HANDLE_FLAG_INHERIT, 0)) {
        goto exit;
    }

    processHandle = CreateChildProcess(cmd, args, childStdInRd, childStdOutWr, childStdErrWr);
    if (processHandle == INVALID_HANDLE_VALUE) {
        exitCode = 0xFFFF;
        goto exit;
    }
    apiTimeout = timeoutMs;
    if (timeoutMs == 0) {
        apiTimeout = INFINITE;
    }
    #pragma GCC poison timeoutMs
    duration = readOutput(processHandle, childStdOutRd, childStdErrRd, stdout_, stderr_, apiTimeout);
    if (apiTimeout != INFINITE) {
        apiTimeout -= duration;
    }
    if (apiTimeout != INFINITE && apiTimeout <= 0) {
        waitResult = WAIT_TIMEOUT;
    } else {
        waitResult = WaitForSingleObject(processHandle, apiTimeout);
    }
    if (waitResult == WAIT_TIMEOUT) {
        exitCode = 0xFFFE;
        TerminateProcess(processHandle, exitCode);
    } else {
        GetExitCodeProcess(processHandle, &exitCode);
    }
exit:
    std::array<HANDLE, 7> handles = {
        processHandle,
        childStdOutRd,
        childStdOutWr,
        childStdErrRd,
        childStdErrWr,
        childStdInRd,
        childStdInWr
    };
    for (const auto& h: handles) {
        if (h != INVALID_HANDLE_VALUE) {
            CloseHandle(h);
        }
    }
    return exitCode;
}


HANDLE CreateChildProcess(String cmd, PoolStringArray args, HANDLE childStdIn, HANDLE childStdOut, HANDLE childStdErr) {
// Create a child process that uses the previously created pipes for STDIN and STDOUT.
    PROCESS_INFORMATION procInfo = {0};
    STARTUPINFOW startInfo = {0};
    bool bSuccess = false;


    // Set up members of the STARTUPINFO structure.
    // This structure specifies the STDIN and STDOUT handles for redirection.

    startInfo.cb = sizeof(startInfo);
    startInfo.hStdError = childStdErr;
    startInfo.hStdOutput = childStdOut;
    startInfo.hStdInput = childStdIn;
    // TODO:  | CREATE_NO_WINDOW; ?
    startInfo.dwFlags |= STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    startInfo.wShowWindow = SW_HIDE;
    String quotedArgs = cmd.find(" ") > -1 ? "\"" + cmd + "\"" : cmd;
    for (int i = 0; i < args.size(); ++i) {
        quotedArgs += " ";
        quotedArgs += args[i].find(" ") > -1 ? "\"" + args[i] + "\"" : args[i];
    }
    debug_print(quotedArgs);
    // Create the child process.
    bSuccess = CreateProcessW(
        // Don't use application name because it won't run from $PATH
        NULL,
        // I think it's ok if this buffer gets modified..
        (wchar_t *)quotedArgs.unicode_str(), // command line
        NULL,          // process security attributes
        NULL,          // primary thread security attributes
        TRUE,          // handles are inherited
        0,             // creation flags
        NULL,          // use parent's environment
        NULL,          // use parent's current directory
        &startInfo,  // STARTUPINFO pointer
        &procInfo);  // receives PROCESS_INFORMATION
     // If an error occurs, exit the application.
    if (bSuccess) {
        // Close handles to the child process primary thread.
        // Some applications might keep these handles to monitor the status
        // of the child process, for example.

        CloseHandle(procInfo.hThread);

        // Close handles to the stdin and stdout pipes no longer needed by the child process.
        // If they are not explicitly closed, there is no way to recognize that the child process has ended.

        CloseHandle(childStdErr);
        CloseHandle(childStdOut);
        CloseHandle(childStdIn);
        return procInfo.hProcess;
    } else {
        PRINT_ERROR("CreateProcess failed", GetLastError());
        return INVALID_HANDLE_VALUE;
    }
}
