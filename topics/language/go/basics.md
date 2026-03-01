# 🐹 Go Basics for DevOps

> Go is the language DevOps tools are built with. Docker, Kubernetes, Terraform, Prometheus, Consul, Vault — all Go. Its killer features for operations: compiles to a single static binary (no runtime dependencies), fast startup, strong concurrency, and an excellent standard library. If you're building a CLI tool or daemon that needs to run on arbitrary servers, Go is the right choice.

---

## Why Go for DevOps

```
Python script → needs Python installed, venv, dependencies
Bash script   → limited error handling, no types, hard to test
Go binary     → copy one file, it just works, on any Linux/macOS/Windows
```

```bash
# Single binary: cross-compile for any target
GOOS=linux GOARCH=amd64 go build -o ./bin/mytool-linux-amd64 .
GOOS=darwin GOARCH=arm64 go build -o ./bin/mytool-macos-arm64 .
GOOS=windows GOARCH=amd64 go build -o ./bin/mytool-windows.exe .

# Strip debug info for smallest binary:
go build -ldflags="-s -w" -o ./bin/mytool .

# Embed version at build time:
go build -ldflags="-X main.version=$(git describe --tags)" -o ./bin/mytool .
```

---

## Project Setup

```bash
# Create a new module
mkdir devops-tool && cd devops-tool
go mod init github.com/JawherKl/devops-tool

# Install dependencies
go get github.com/spf13/cobra@latest     # CLI framework
go get github.com/spf13/viper@latest     # config management
go get go.uber.org/zap@latest            # structured logging
go get github.com/aws/aws-sdk-go-v2/...  # AWS SDK v2

# Tidy (remove unused, update go.sum)
go mod tidy

# Run, test, build
go run .
go test ./...
go test -race ./...     # detect race conditions
go build ./...
```

---

## Error Handling

Go errors are values — always check them explicitly. This is the most important Go pattern.

```go
package main

import (
    "errors"
    "fmt"
    "os"
)

// ── Define custom error types ──────────────────────────────────────────────────
type DeployError struct {
    Service string
    Stage   string
    Err     error
}

func (e *DeployError) Error() string {
    return fmt.Sprintf("deploy %s failed at %s: %v", e.Service, e.Stage, e.Err)
}

func (e *DeployError) Unwrap() error { return e.Err }

// Sentinel errors for type-checking:
var (
    ErrNotFound    = errors.New("resource not found")
    ErrUnauthorized = errors.New("not authorized")
    ErrTimeout     = errors.New("operation timed out")
)

// ── Functions return (value, error) ───────────────────────────────────────────
func readConfig(path string) ([]byte, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        // Wrap with context — preserves original error for errors.Is/As
        return nil, fmt.Errorf("readConfig: %w", err)
    }
    return data, nil
}

// ── Check errors immediately ───────────────────────────────────────────────────
func main() {
    data, err := readConfig("/etc/myapp/config.yaml")
    if err != nil {
        // errors.Is: check if ANY error in the chain matches
        if errors.Is(err, os.ErrNotExist) {
            fmt.Fprintln(os.Stderr, "Config file not found — using defaults")
        } else {
            fmt.Fprintf(os.Stderr, "Error: %v\n", err)
            os.Exit(1)
        }
    }
    _ = data

    // errors.As: extract typed error for details
    var deployErr *DeployError
    if err != nil && errors.As(err, &deployErr) {
        fmt.Printf("Failed service: %s, stage: %s\n", deployErr.Service, deployErr.Stage)
    }
}
```

---

## Working with Files, OS, and Processes

```go
package main

import (
    "bufio"
    "fmt"
    "io"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
)

// ── Read file line by line ─────────────────────────────────────────────────────
func processLogFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return fmt.Errorf("open %s: %w", path, err)
    }
    defer f.Close()    // always defer Close immediately after successful open

    scanner := bufio.NewScanner(f)
    scanner.Buffer(make([]byte, 1024*1024), 1024*1024)  // 1MB line buffer (for long lines)
    for scanner.Scan() {
        line := scanner.Text()
        if strings.Contains(line, "ERROR") {
            fmt.Println(line)
        }
    }
    return scanner.Err()
}

// ── Atomic write ──────────────────────────────────────────────────────────────
func atomicWrite(path string, content []byte) error {
    dir := filepath.Dir(path)
    tmp, err := os.CreateTemp(dir, ".tmp-*")
    if err != nil {
        return fmt.Errorf("create temp: %w", err)
    }
    tmpPath := tmp.Name()
    defer func() {
        tmp.Close()
        os.Remove(tmpPath)  // cleanup if rename didn't happen
    }()

    if _, err := tmp.Write(content); err != nil {
        return fmt.Errorf("write: %w", err)
    }
    if err := tmp.Close(); err != nil {
        return fmt.Errorf("close: %w", err)
    }
    return os.Rename(tmpPath, path)  // atomic
}

// ── Run external commands ──────────────────────────────────────────────────────
func runCommand(args ...string) (string, error) {
    cmd := exec.Command(args[0], args[1:]...)
    output, err := cmd.Output()  // captures stdout; stderr goes to terminal
    if err != nil {
        var exitErr *exec.ExitError
        if errors.As(err, &exitErr) {
            return "", fmt.Errorf("command %v exited %d: %s",
                args, exitErr.ExitCode(), exitErr.Stderr)
        }
        return "", fmt.Errorf("run %v: %w", args, err)
    }
    return strings.TrimSpace(string(output)), nil
}

// Stream output in real time:
func runStreaming(args ...string) error {
    cmd := exec.Command(args[0], args[1:]...)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    return cmd.Run()
}

// Walk directory tree:
func findConfigs(root string) ([]string, error) {
    var configs []string
    err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
        if err != nil {
            return err
        }
        if !d.IsDir() && filepath.Ext(path) == ".yaml" {
            configs = append(configs, path)
        }
        return nil
    })
    return configs, err
}
```

---

## Concurrency Patterns

```go
package main

import (
    "context"
    "fmt"
    "sync"
    "time"
)

// ── Fan-out: run N tasks concurrently, collect results ────────────────────────
type Result struct {
    Host string
    Out  string
    Err  error
}

func checkHosts(ctx context.Context, hosts []string) []Result {
    results := make([]Result, len(hosts))
    var wg sync.WaitGroup

    for i, host := range hosts {
        wg.Add(1)
        go func(i int, host string) {
            defer wg.Done()
            out, err := checkHost(ctx, host)
            results[i] = Result{Host: host, Out: out, Err: err}
        }(i, host)
    }
    wg.Wait()
    return results
}

// ── Bounded concurrency (semaphore) ───────────────────────────────────────────
func checkHostsLimited(ctx context.Context, hosts []string, maxConcurrent int) []Result {
    sem := make(chan struct{}, maxConcurrent)  // buffered channel as semaphore
    results := make([]Result, len(hosts))
    var wg sync.WaitGroup

    for i, host := range hosts {
        wg.Add(1)
        go func(i int, host string) {
            defer wg.Done()
            sem <- struct{}{}         // acquire
            defer func() { <-sem }() // release
            out, err := checkHost(ctx, host)
            results[i] = Result{Host: host, Out: out, Err: err}
        }(i, host)
    }
    wg.Wait()
    return results
}

// ── Context: propagate cancellation and timeouts ───────────────────────────────
func deployWithTimeout(service string) error {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
    defer cancel()    // always defer cancel to release resources

    return deploy(ctx, service)
}

func deploy(ctx context.Context, service string) error {
    // Pass ctx to every downstream call:
    if err := pullImage(ctx, service); err != nil {
        return err
    }
    // Check if cancelled between stages:
    select {
    case <-ctx.Done():
        return fmt.Errorf("deploy cancelled: %w", ctx.Err())
    default:
    }
    return rollout(ctx, service)
}
```

---

## HTTP Server & Client

```go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

// ── HTTP health check server ───────────────────────────────────────────────────
type HealthResponse struct {
    Status  string            `json:"status"`
    Version string            `json:"version"`
    Checks  map[string]string `json:"checks"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    checks := map[string]string{
        "database": checkDB(),
        "redis":    checkRedis(),
    }
    status := "ok"
    for _, v := range checks {
        if v != "ok" {
            status = "degraded"
            break
        }
    }
    code := http.StatusOK
    if status != "ok" {
        code = http.StatusServiceUnavailable
    }
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(code)
    json.NewEncoder(w).Encode(HealthResponse{
        Status:  status,
        Version: os.Getenv("VERSION"),
        Checks:  checks,
    })
}

// ── Graceful shutdown ─────────────────────────────────────────────────────────
func runServer(addr string) error {
    mux := http.NewServeMux()
    mux.HandleFunc("/health", healthHandler)
    mux.HandleFunc("/ready", healthHandler)

    srv := &http.Server{
        Addr:         addr,
        Handler:      mux,
        ReadTimeout:  10 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  30 * time.Second,
    }

    // Graceful shutdown on SIGINT/SIGTERM:
    stop := make(chan os.Signal, 1)
    signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

    go func() {
        slog.Info("Starting server", "addr", addr)
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            slog.Error("Server error", "err", err)
            os.Exit(1)
        }
    }()

    <-stop
    slog.Info("Shutting down...")
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    return srv.Shutdown(ctx)
}
```