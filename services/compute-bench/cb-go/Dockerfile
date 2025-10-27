FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# 
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/producer ./...

FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/producer /app/producer
EXPOSE 8080
ENV PORT=8080
#falls app auf 0000 port lauschen muss
ENTRYPOINT ["/app/producer"]