FROM golang:latest as builder
COPY . /consul-mock-service
WORKDIR /consul-mock-service
RUN go build

FROM alpine:latest
COPY --from=builder /consul-mock-service/consul-mock-service /sbin/consul-mock-service
CMD ["/sbin/consul-mock-service", "-config", "/consul-mock-service.json"]