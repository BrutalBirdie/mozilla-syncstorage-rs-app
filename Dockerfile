FROM cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee AS builder

RUN apt-get update && \
    apt-get install -y libpq-dev pkg-config && \
    rm -rf /var/cache/apt /var/lib/apt/lists

# renovate: datasource=github-releases depName=mozilla-services/syncstorage-rs versioning=semver
ARG SYNCSTORAGE_VERSION=0.24.1

WORKDIR /build
RUN curl -sSLf "https://github.com/mozilla-services/syncstorage-rs/archive/refs/tags/${SYNCSTORAGE_VERSION}.tar.gz" | tar -xz --strip-components 1

# the toolchain follows upstream's rust-version so a release bump cannot outrun it
RUN rust_version=$(sed -n 's/^rust-version = "\([^"]*\)".*/\1/p' Cargo.toml) && \
    curl -sSLf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "${rust_version}"

# version.json is compiled into the /__version__ endpoint
RUN printf '{"source": "https://github.com/mozilla-services/syncstorage-rs", "version": "%s", "commit": "", "build": ""}\n' "${SYNCSTORAGE_VERSION}" > version.json

# py_verifier is left out, the native verifier needs no Python runtime - https://github.com/mozilla-services/syncstorage-rs/tree/master/tokenserver-auth/src/oauth
RUN /root/.cargo/bin/cargo install --path ./syncserver --locked --root /build/out \
        --no-default-features --features=postgres --features=tokenserver-db/postgres

FROM cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee

RUN mkdir -p /app/code /app/pkg
WORKDIR /app/code

COPY --from=builder /build/out/bin/syncserver /app/code/syncserver

COPY env.sh.template start.sh purge.sh /app/pkg/

CMD [ "/app/pkg/start.sh" ]
