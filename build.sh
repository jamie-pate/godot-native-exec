docker build -t godot-gdnative-exec .
id=$(docker create )
docker cp -L $id:/opt/godot-videodecoder/thirdparty/win32 - | tar -xhC $THIRDPARTY_DIR/
