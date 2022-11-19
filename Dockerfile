FROM alpine:edge
RUN apk add --no-cache shellcheck bash make curl
WORKDIR /root
COPY ./ ./
CMD [ "bash" ]
