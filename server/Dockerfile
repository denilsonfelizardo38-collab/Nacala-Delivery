# syntax=docker/dockerfile:1

# ---------------------------------------------------------------- build
FROM dart:3.13.7-slim AS build
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o /app/nacala_server

# ---------------------------------------------------------------- runtime
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends libsqlite3-0 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/nacala_server ./nacala_server
RUN mkdir -p /data/uploads

ENV PORT=8080
ENV DB_PATH=/data
ENV UPLOADS_DIR=/data/uploads

EXPOSE 8080
CMD ["./nacala_server"]
