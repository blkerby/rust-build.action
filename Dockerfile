# Fork of git@github.com:rust-build/rust-build.action.git
FROM rust:1.87.0-bookworm

LABEL "name"="Automate publishing Rust build artifacts for GitHub releases through GitHub Actions"
LABEL "repository"="http://github.com/blkerby/rust-build.action"

# Add regular dependencies
RUN apt update && apt install -y jq zip gdb-mingw-w64 gcc-mingw-w64-x86-64 python3 clang cmake libxml2-dev libssl-dev

RUN git clone https://github.com/tpoechtrager/osxcross /opt/osxcross
RUN curl -Lo /opt/osxcross/tarballs/MacOSX10.12.sdk.tar.xz "https://github.com/joseluisq/macosx-sdks/releases/download/10.12/MacOSX10.12.sdk.tar.xz"
RUN ["/bin/bash", "-c", "cd /opt/osxcross && UNATTENDED=yes OSX_VERSION_MIN=10.12 ./build.sh"]

COPY entrypoint.sh /entrypoint.sh
COPY build.sh /build.sh
COPY common.sh /common.sh

RUN chmod 555 /entrypoint.sh /build.sh /common.sh

ENV OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu
ENTRYPOINT ["/entrypoint.sh"]
