#include "exec.h"
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <array>

#define BUFSIZE 4096
#define snwprintf _snwprintf
#define wtoi _wtoi

using namespace godot;

HANDLE CreateChildProcess(String cmdline, HANDLE childStdIn, HANDLE childStdOut, HANDLE childStdErr);

void NativeExec::_register_methods() {
    register_method("exec", &NativeExec::exec);
}

/**
 * Read the output from the process stdout and stderr streams and add them to the stdout_ and stderr_ arrays.
 * Returns the elapsed time spent reading before the handles were closed.
 */
ULONGLONG NativeExec::readOutput(void *childStdOut, void *childStdErr, PoolStringArray stdout_, PoolStringArray stderr_, godot_int timeoutMs) {
    bool success = false;
    DWORD read_bytes;
    //wchar_t buf[BUFSIZE];
    char buf[BUFSIZE];
    HANDLE handles[] = {childStdOut, childStdErr};
    PoolStringArray output[] = {stdout_, stderr_};
    ULONGLONG startTime = GetTickCount64();
    while (true) {
        ULONGLONG elapsedMs = GetTickCount64() - startTime;
        const size_t handleCount = 2;
        DWORD waitResult = WaitForMultipleObjects(handleCount, handles, false, timeoutMs - elapsedMs);
        size_t i = ~0;
        bool abandoned = false;
        if (waitResult >= WAIT_OBJECT_0 && waitResult < WAIT_OBJECT_0 + handleCount && handles[i] != INVALID_HANDLE_VALUE) {
            i = waitResult - WAIT_OBJECT_0;
        }
        if (waitResult >= WAIT_ABANDONED_0 && waitResult < WAIT_ABANDONED_0 + handleCount && handles[i] != INVALID_HANDLE_VALUE) {
            i = waitResult - WAIT_ABANDONED_0;
            abandoned = true;
        }
        if (i < handleCount) {
            success = ReadFile(handles[i], buf, sizeof(buf), &read_bytes, NULL);
            if (success) {
                output[i].append(godot::String(buf));
            }
            if (!success || read_bytes == 0 || abandoned) {
                handles[i] = INVALID_HANDLE_VALUE;
            };
        }
        if (handles[0] == INVALID_HANDLE_VALUE && handles[1] == INVALID_HANDLE_VALUE) {
            break;
        }
    }
    return GetTickCount64() - startTime;
}

godot_bool NativeExec::exec(String cmd, PoolStringArray stdout_, PoolStringArray stderr_, godot_int timeoutMs) {
    HANDLE childStdInRd = INVALID_HANDLE_VALUE;
    HANDLE childStdInWr = INVALID_HANDLE_VALUE;
    HANDLE childStdOutRd = INVALID_HANDLE_VALUE;
    HANDLE childStdOutWr = INVALID_HANDLE_VALUE;
    HANDLE childStdErrRd = INVALID_HANDLE_VALUE;
    HANDLE childStdErrWr = INVALID_HANDLE_VALUE;
    HANDLE processHandle = INVALID_HANDLE_VALUE;

    DWORD exitCode = 0;
    DWORD waitResult = 0;

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

    processHandle = CreateChildProcess(cmd, childStdInRd, childStdOutWr, childStdErrWr);
    timeoutMs -= readOutput(childStdOutRd, childStdErrRd, stdout_, stderr_, timeoutMs);
    waitResult = WaitForSingleObject(processHandle, timeoutMs);
    if (waitResult == WAIT_TIMEOUT) {
        exitCode = 0xFFFF;
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


HANDLE CreateChildProcess(String cmdline, HANDLE childStdIn, HANDLE childStdOut, HANDLE childStdErr) {
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

    // Create the child process.

    bSuccess = CreateProcessW(NULL,
        (wchar_t *)cmdline.unicode_str(),     // command line
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
        return INVALID_HANDLE_VALUE;
    }
}
