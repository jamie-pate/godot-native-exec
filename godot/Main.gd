extends Control

const ExecThread = preload('res://addons/GodotNativeExec/ExecThread.gd')
var r = RandomNumberGenerator.new()
func _ready():
	r.randomize()
	yield(get_tree().create_timer(0.5), 'timeout')
	_on_Button_pressed()

func _ospath(path: String) -> String:
	if OS.get_name() == 'Windows':
		return path.replace("/", "\\")
	else:
		return path.replace("\\", "/")

func _extract_file(resource_filename: String) -> String:
	var f := File.new()
	var err := f.open(resource_filename, File.READ)
	if err != OK:
		print('Unable to open %s resource for reading' % [resource_filename])
		return ''
	# if the file is > 10 MiB we probably want to rethink this approach
	# they should all be < 1MiB so far
	assert(f.get_len() < 1024 * 1024 * 1)
	var buffer := f.get_buffer(f.get_len())
	f.close()
	var out_filename := resource_filename.get_file()
	return _write_user_file(buffer, out_filename)

func _write_user_file(buffer:PoolByteArray, filename:String) -> String:
	var udd := OS.get_user_data_dir().replace('\\', '/')
	var out_filename = '%s%s%s' % [udd, '/', filename]
	var f := File.new()
	var err := f.open(out_filename, File.WRITE)
	if err != OK || !out_filename:
		print('Unable to open %s script for writing' % out_filename)
		return ''
	f.store_buffer(buffer)
	f.close()
	return out_filename

func _temp_file(suffix) -> String:
	var temp = OS.get_environment('temp')
	return _ospath('%s/%x%s' % [temp, r.randi(), suffix])

const NativeExec = preload('res://addons/GodotNativeExec/godot-native-exec.gdns')
func _on_Button_pressed():

	var sysinfo_js := _extract_file('res://sysinfo.js')
	$VBoxContainer/RichTextLabel.text += 'executing:\n'
	#NativeExec.exec('cmd /V', stdout, stderr, 1000)
	var ne := NativeExec.new()
	# godot_bool exec(String cmd, PoolStringArray stdout_, PoolStringArray stderr_, godot_int timeoutMs = DEFAULT_EXEC_TIMEOUT_MS);

	yield(do_exec('WMIC.exe', ['OS', 'Get', 'CurrentTimeZone']), 'completed')
	var dxdiag_tmp := _temp_file('.xml')
	if !yield(do_exec('dxdiag', ['/dontskip', '/whql:off', '/x', dxdiag_tmp]), 'completed'):
		show_text('dxdiag error')
	else:
		var start = OS.get_ticks_msec()
		var f = File.new()
		var i = 0
		var found:bool = f.file_exists(dxdiag_tmp)
		# sometimes the xml file gets written a few seconds later?
		while !found && OS.get_ticks_msec() - start < 60000:
			i += 1
			found = f.file_exists(dxdiag_tmp)
			yield(get_tree(), 'idle_frame')
		if !found:
			show_text('ERROR: Unable to find %s after %s tries' % [dxdiag_tmp, i])
		else:
			if i > 0:
				show_text('found %s after %sms' % [dxdiag_tmp, OS.get_ticks_msec() - start])
			else:
				show_text('found %s' % [dxdiag_tmp])
			yield(do_exec('cscript', ['/nologo', 'xmltojson.js', dxdiag_tmp]), 'completed')

func do_exec(cmd, args):
	$Sprite.visible = true
	var stdout := Array()
	var stderr := Array()
	var start = OS.get_ticks_msec()
	var et = ExecThread.new()
	var result = yield(et.exec(cmd, args, stdout, stderr), 'completed')
	var duration = OS.get_ticks_msec() - start
	show_text('duration=%sms\ncmd=%s\nargs=%s\nresult=%s\nstdout:%s===\n\nstderr:%s===' % [
		duration,
		cmd,
		args,
		result,
		PoolStringArray(stdout).join('\n'),
		PoolStringArray(stderr).join('\n')
	])
	$Sprite.visible = false
	return result == 0

func show_text(value):
	print(value)
	$VBoxContainer/RichTextLabel.text += '%s\n' % [value]
