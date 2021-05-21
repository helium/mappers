FROM urbica/martin
RUN apk add curl
RUN mkdir -p /app/config
COPY config.yaml /app/config/docker/config.yaml
COPY entrypoint.sh /app/config/docker/entrypoint.sh

WORKDIR /app
ENTRYPOINT /app/config/docker/entrypoint.sh