LABEL org.opencontainers.image.description Redis with RediSearch and RedisJSON for arm64 and amd64
ARG REDIS_VER=7.2.1
#ARG ARCH=arm64v8
#ARG ARCH=x64
ARG OSNICK=bookworm
ARG REDISEARCH_VER=v2.8.4
ARG RUST_VER=1.72.0
ARG REJSON_VER=2.6

# Build RediSearch
FROM debian:bullseye-slim AS redisearch
ARG REDISEARCH_VER
ARG TARGETPLATFORM
RUN apt clean && apt -y update && apt -y install --no-install-recommends \
    ca-certificates build-essential g++ make git clang && rm -rf /var/lib/apt/lists/*
WORKDIR /
RUN git clone --recursive --depth 1 --branch ${REDISEARCH_VER} https://github.com/RediSearch/RediSearch.git
WORKDIR /RediSearch
RUN make setup
RUN make build
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ] ; then cp /RediSearch/bin/linux-arm64v8-release/search/redisearch.so /RediSearch/bin/redisearch.so ; elif [ "$TARGETPLATFORM" = "linux/amd64" ] ; then cp /RediSearch/bin/linux-x64-release/search/redisearch.so /RediSearch/bin/redisearch.so ; else echo "unknown build platform" && exit 1 ; fi

# Build RediJSON
FROM rust:${OSNICK} AS rejson
ARG REJSON_VER
RUN apt-get clean && apt-get -y update && apt -y install --no-install-recommends \
    clang && rm -rf /var/lib/apt/lists/*
WORKDIR /
RUN git clone --depth 1 --branch ${REJSON_VER} https://github.com/RedisJSON/RedisJSON.git
WORKDIR /RedisJSON
RUN cargo build --release

# Run Redis with RediSearch + RedisJSON
FROM redis:${REDIS_VER}-${OSNICK}
ARG REDIS_VER
#ARG ARCH
ARG OSNICK
ARG REDISEARCH_VER
ARG RUST_VER
ARG REJSON_VER

ENV LD_LIBRARY_PATH /usr/lib/redis/modules
WORKDIR /data
COPY --from=redisearch /RediSearch/bin/redisearch.so /usr/lib/redis/modules/
COPY --from=rejson /RedisJSON/target/release/librejson.so /usr/lib/redis/modules/
ENTRYPOINT ["redis-server"]
CMD ["--loadmodule", "/usr/lib/redis/modules/redisearch.so", \
    "--loadmodule", "/usr/lib/redis/modules/librejson.so"]
