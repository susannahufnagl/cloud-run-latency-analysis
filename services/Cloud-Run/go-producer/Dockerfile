
FROM golang:1.25 AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

# Quellcode
COPY . .


RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o app ./...


FROM gcr.io/distroless/base-debian12

WORKDIR /app
COPY --from=build /src/app /app/app


ENV PORT=8080
EXPOSE 8080


ENTRYPOINT ["/app/app"]
