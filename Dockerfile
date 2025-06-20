# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download all dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o email-verifier ./cmd/apiserver

# Final stage
FROM alpine:latest

WORKDIR /app

# Install ca-certificates for SSL
RUN apk --no-cache add ca-certificates

# Copy the binary from builder
COPY --from=builder /app/email-verifier .

# Copy frontend files
COPY frontend/public ./frontend/public

# Copy the test API HTML file
COPY test_api.html .

# Expose the port the app runs on
EXPOSE 8080

# Command to run the executable
CMD ["./email-verifier"]
