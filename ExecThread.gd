extends Reference

const NativeExec = preload('./godot-native-exec.gdns')
signal _completed(instance)

func _native_exec_new():
	return NativeExec.new()

func exec(cmd: String, args: PoolStringArray, stdout := [], stderr := [], timeout := 10 * 60 * 1000) -> int:
	var thread := Thread.new()
	var stdout_ = []
	var stderr_ = []
	var err = thread.start(self, '_thread_exec', {
		cmd=cmd,
		args=args,
		stdout=stdout_,
		stderr=stderr_,
		timeout=timeout,
		instance=thread
	})
	assert(err == OK)
	var yielded = yield(self, '_completed')
	while yielded != thread:
		yielded = yield(self, '_completed')
	var result = thread.wait_to_finish()
	for s in stdout_:
		stdout.append(s)
	for s in stderr_:
		stderr.append(s)
	return result

func _thread_exec(a):
	var result := 0
	var ne := _native_exec_new() as NativeExec if OS.get_name() == 'Windows' else null
	if ne:
		result = ne.exec(a.cmd, a.args, a.stdout, a.stderr, a.timeout)
	else:
		# unfortunately stderr would be combined here... so disable it
		result = OS.execute(a.cmd, a.args, true, a.stdout, false)
	call_deferred('_emit_completed', a.instance)
	return result

func _emit_completed(instance: Thread):
	emit_signal('_completed', instance)
