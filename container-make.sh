mkdir -p tools
ln -fs ../run-build-tool.sh tools/make
./tools/make "$@"
