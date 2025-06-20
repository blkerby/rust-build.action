#!/bin/bash

set -eu -o pipefail

source /common.sh

crash() {
  error "Command exited with non-zero exit code"
  exit 1
}

trap 'crash' ERR
OUTPUT_DIR="$1"

if [ -z "${SRC_DIR+0}" ]; then
  if [ -z "${INPUT_SRC_DIR+0}" ]; then
    info "No SRC_DIR is set, using repo base dir"
  else
    info "Switching to src dir \"$INPUT_SRC_DIR\""
    cd "$INPUT_SRC_DIR"
  fi
else
  info "Switching to src dir \"$SRC_DIR\""
  cd "$SRC_DIR"
fi

info "Installing additional linkers"
case ${RUSTTARGET} in
"x86_64-pc-windows-gnu") ;;

"x86_64-unknown-linux-musl") ;;

"x86_64-unknown-linux-gnu") ;;

"wasm32-wasi") ;;

"x86_64-apple-darwin")
export CC=/opt/osxcross/target/bin/o64-clang
export CXX=/opt/osxcross/target/bin/o64-clang++
export PATH="/opt/osxcross/target/bin:$PATH"
export LIBZ_SYS_STATIC=1
mkdir -p /.cargo
cat > /.cargo/config.toml << EOF
[target.x86_64-apple-darwin]
linker = "/opt/osxcross/target/bin/x86_64-apple-darwin16-clang"
ar = "/opt/osxcross/target/bin/x86_64-apple-darwin16-ar"
EOF
;;

*)
error "${RUSTTARGET} is not supported"
exit 1
;;
esac

info "Setting up toolchain"
TOOLCHAIN_VERSION="${TOOLCHAIN_VERSION:-""}"
if [ "$TOOLCHAIN_VERSION" != "" ]; then
  rustup default "$TOOLCHAIN_VERSION" >&2
fi
rustup target add "$RUSTTARGET" >&2

if [ -z "${BINARIES}" ]; then
  BINARIES="$(cargo read-manifest | jq -r ".targets[] | select(.kind[] | contains(\"bin\")) | .name")"
fi

OUTPUT_LIST=""
for BINARY in $BINARIES; do
  info "Building $BINARY..."

  if [ -x "./build.sh" ]; then
    OUTPUT=$(./build.sh "${CMD_PATH}" "${OUTPUT_DIR}")
  else
    # We need globbing here to expand the extra flags
    # shellcheck disable=SC2086
    OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu OPENSSL_INCLUDE_DIR=/usr/include PKG_CONFIG_PATH=/usr/lib/pkgconfig CARGO_TARGET_DIR="./target" cargo build --release --target "$RUSTTARGET" --bin "$BINARY" $EXTRA_COMMAND_FLAGS >&2
    OUTPUT=$(find "target/${RUSTTARGET}/release/" -maxdepth 1 -type f -executable \( -name "${BINARY}" -o -name "${BINARY}.*" \) -print0 | xargs -0)
  fi

  info "$OUTPUT"

  if [ "$OUTPUT" = "" ]; then
    error "Unable to find output"
    exit 1
  fi
  
  if is_true "$MINIFY"; then
    info "Minifying ${OUTPUT}..."
    
    info "Stripping..."
    strip "${OUTPUT}" >&2 || info "Strip failed."
    info "File stripped successfully."

    info "Compressing using UPX..."
    upx "${OUTPUT}" >&2 || info "Compression failed."
    info "File compressed successfully."
  fi

  info "Saving $OUTPUT..."

  # We need globbing here to move all files
  # shellcheck disable=SC2086
  mv $OUTPUT "$OUTPUT_DIR" || error "Unable to copy binary"

  for f in $OUTPUT; do
    OUTPUT_LIST="$OUTPUT_LIST $(basename "$f")"
  done
done
echo "$OUTPUT_LIST"
