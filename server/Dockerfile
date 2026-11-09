# syntax=docker/dockerfile:1

# ---------------------------------------------------------------- build
FROM dart:3.13 AS build
WORKDIR /app

COPY server/pubspec.yaml server/pubspec.lock ./
RUN dart pub get

COPY server/ ./
RUN dart compile exe bin/server.dart -o /app/nacala_server

# ---------------------------------------------------------------- runtime
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends libsqlite3-0 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Ignora o SIGTERM nativo — o binário Dart só trata sinal.
STOPSIGNAL SIGINT

# Executa como utilizador sem privilégios; /data pertence a ele para a
# base SQLite e os uploads sobreviverem a reinícios com o volume montado.
RUN groupadd --system nacala \
    && useradd --system --gid nacala --home /app nacala \
    && mkdir -p /data/uploads \
    && chown -R nacala:nacala /data

WORKDIR /app
COPY --from=build /app/nacala_server ./nacala_server
RUN chown -R nacala:nacala /app

ENV PORT=8080
ENV DB_PATH=/data
ENV UPLOADS_DIR=/data/uploads
USER nacala

# O bash do bookworm valida /health via /dev/tcp — dispensa curl/python.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/${PORT:-8080} && printf "GET /health HTTP/1.0\r\n\r\n" >&3 && grep -q "200" <&3'

EXPOSE 8080
CMD ["./nacala_server"]
