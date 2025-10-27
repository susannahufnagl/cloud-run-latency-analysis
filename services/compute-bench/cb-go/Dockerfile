FROM golang:1.25 AS build
WORKDIR /src

# Module zuerst, damit Caching greift
COPY go.mod go.sum ./
RUN go mod download

# Rest des Codes
COPY . .

# Statisches Linux/amd64-Binary bauen
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/producer .

# ---- Minimal Runtime (non-root, kein Shell) ----
FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/producer /app/producer

# Cloud-Run/CE-Default
ENV PORT=8080
EXPOSE 8080

# Non-root läuft in distroless per default (UID 65532)
ENTRYPOINT ["/app/producer"]
