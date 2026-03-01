# 🔨 Go CLI Tools

> Building CLI tools in Go with Cobra — the same framework used by kubectl, helm, and the GitHub CLI. A well-built Go CLI tool compiles to a single binary, runs anywhere, starts in milliseconds, and handles flags, subcommands, and configuration in a familiar `kubectl`-style interface.

---

## Project Structure

```
devops-tool/
├── cmd/
│   ├── root.go          ← root command, global flags, config init
│   ├── deploy.go        ← deploy subcommand
│   ├── status.go        ← status subcommand
│   └── version.go       ← version subcommand
├── internal/
│   ├── config/
│   │   └── config.go    ← config loading (Viper)
│   ├── deploy/
│   │   └── deploy.go    ← deploy business logic
│   └── k8s/
│       └── client.go    ← Kubernetes client wrapper
├── main.go
├── go.mod
└── go.sum
```

---

## main.go & Root Command

```go
// main.go
package main

import (
    "os"
    "github.com/JawherKl/devops-tool/cmd"
)

// Version is set at build time:
// go build -ldflags="-X main.version=v1.2.3" .
var version = "dev"

func main() {
    if err := cmd.Execute(version); err != nil {
        os.Exit(1)
    }
}
```

```go
// cmd/root.go
package cmd

import (
    "fmt"
    "os"

    "github.com/spf13/cobra"
    "github.com/spf13/viper"
    "go.uber.org/zap"
)

var (
    cfgFile string
    verbose bool
    logger  *zap.SugaredLogger
    appVersion string
)

var rootCmd = &cobra.Command{
    Use:   "dtool",
    Short: "DevOps automation tool",
    Long: `dtool — deploy, check, and manage infrastructure.

Examples:
  dtool deploy api v1.2.3 --env production
  dtool status --namespace myapp
  dtool version`,
    PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
        return initLogging()
    },
}

func Execute(version string) error {
    appVersion = version
    return rootCmd.Execute()
}

func init() {
    cobra.OnInitialize(initConfig)

    // Persistent flags: available on root and ALL subcommands
    rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "",
        "config file (default: $HOME/.dtool.yaml)")
    rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false,
        "verbose output")
    rootCmd.PersistentFlags().String("context", "",
        "Kubernetes context to use")

    // Bind flag to viper:
    viper.BindPFlag("context", rootCmd.PersistentFlags().Lookup("context"))
}

func initConfig() {
    if cfgFile != "" {
        viper.SetConfigFile(cfgFile)
    } else {
        home, _ := os.UserHomeDir()
        viper.AddConfigPath(home)
        viper.AddConfigPath(".")
        viper.SetConfigName(".dtool")
        viper.SetConfigType("yaml")
    }
    // Override any config key with env: DTOOL_REGISTRY=... maps to registry
    viper.SetEnvPrefix("DTOOL")
    viper.AutomaticEnv()

    if err := viper.ReadInConfig(); err == nil {
        if verbose {
            fmt.Fprintln(os.Stderr, "Config:", viper.ConfigFileUsed())
        }
    }
}

func initLogging() error {
    var cfg zap.Config
    if verbose {
        cfg = zap.NewDevelopmentConfig()
    } else {
        cfg = zap.NewProductionConfig()
    }
    l, err := cfg.Build()
    if err != nil {
        return err
    }
    logger = l.Sugar()
    return nil
}
```

---

## Subcommands

```go
// cmd/deploy.go
package cmd

import (
    "fmt"

    "github.com/spf13/cobra"
    "github.com/spf13/viper"
    "github.com/JawherKl/devops-tool/internal/deploy"
)

var deployCmd = &cobra.Command{
    Use:   "deploy <service> <image-tag>",
    Short: "Deploy a service to Kubernetes",
    Long: `Deploy a service by updating its Deployment image tag.

Waits for the rollout to complete and rolls back automatically on failure.`,
    Example: `  dtool deploy api v1.2.3
  dtool deploy api v1.2.3 --env production --timeout 600
  dtool deploy api v1.2.3 --dry-run`,
    Args: cobra.ExactArgs(2),   // enforce exactly 2 positional args
    RunE: runDeploy,             // RunE returns error (vs Run which doesn't)
}

var (
    deployEnv     string
    deployTimeout int
    deployDryRun  bool
    deployNS      string
)

func init() {
    rootCmd.AddCommand(deployCmd)

    deployCmd.Flags().StringVarP(&deployEnv, "env", "e", "dev",
        "target environment (dev|staging|production)")
    deployCmd.Flags().IntVarP(&deployTimeout, "timeout", "t", 300,
        "rollout timeout in seconds")
    deployCmd.Flags().BoolVarP(&deployDryRun, "dry-run", "n", false,
        "show what would happen without making changes")
    deployCmd.Flags().StringVar(&deployNS, "namespace", "",
        "Kubernetes namespace (defaults to <service>-<env>)")

    // Mark required flags:
    // deployCmd.MarkFlagRequired("env")
}

func runDeploy(cmd *cobra.Command, args []string) error {
    service := args[0]
    imageTag := args[1]

    registry := viper.GetString("registry")
    if registry == "" {
        registry = "registry.example.com"
    }

    ns := deployNS
    if ns == "" {
        ns = fmt.Sprintf("%s-%s", service, deployEnv)
    }

    opts := deploy.Options{
        Service:   service,
        ImageTag:  imageTag,
        Namespace: ns,
        Registry:  registry,
        Timeout:   deployTimeout,
        DryRun:    deployDryRun,
    }

    if deployDryRun {
        fmt.Printf("DRY RUN: would deploy %s:%s to %s/%s\n",
            service, imageTag, ns, service)
        return nil
    }

    logger.Infow("Deploying", "service", service, "tag", imageTag, "ns", ns)
    return deploy.Run(cmd.Context(), opts)
}
```

```go
// cmd/version.go
package cmd

import (
    "fmt"
    "runtime"

    "github.com/spf13/cobra"
)

var versionCmd = &cobra.Command{
    Use:   "version",
    Short: "Print version information",
    Run: func(cmd *cobra.Command, args []string) {
        fmt.Printf("dtool %s\n", appVersion)
        fmt.Printf("go %s %s/%s\n", runtime.Version(), runtime.GOOS, runtime.GOARCH)
    },
}

func init() {
    rootCmd.AddCommand(versionCmd)
}
```

---

## Configuration with Viper

```go
// internal/config/config.go
package config

import (
    "fmt"
    "github.com/spf13/viper"
)

type Config struct {
    Registry    string            `mapstructure:"registry"`
    KubeContext string            `mapstructure:"context"`
    Slack       SlackConfig       `mapstructure:"slack"`
    Environments map[string]EnvConfig `mapstructure:"environments"`
}

type SlackConfig struct {
    WebhookURL string `mapstructure:"webhook_url"`
    Channel    string `mapstructure:"channel"`
}

type EnvConfig struct {
    Namespace  string `mapstructure:"namespace"`
    Replicas   int    `mapstructure:"replicas"`
    AutoDeploy bool   `mapstructure:"auto_deploy"`
}

func Load() (*Config, error) {
    var cfg Config
    if err := viper.Unmarshal(&cfg); err != nil {
        return nil, fmt.Errorf("unmarshal config: %w", err)
    }
    return &cfg, nil
}

// ~/.dtool.yaml:
// registry: registry.example.com
// context: prod-cluster
// slack:
//   webhook_url: https://hooks.slack.com/...
//   channel: "#deployments"
// environments:
//   production:
//     namespace: myapp-prod
//     replicas: 4
//     auto_deploy: false
//   staging:
//     namespace: myapp-staging
//     replicas: 2
//     auto_deploy: true
```

---

## Structured Logging with zap

```go
package main

import (
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
)

func newLogger(verbose bool) *zap.SugaredLogger {
    cfg := zap.NewProductionConfig()

    // Human-readable in dev, JSON in prod (detected by verbose flag or env)
    if verbose {
        cfg = zap.NewDevelopmentConfig()
        cfg.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
    }

    logger, _ := cfg.Build()
    return logger.Sugar()
}

// Usage:
// logger.Infow("Deploy started", "service", "api", "tag", "v1.2.3", "env", "prod")
// → {"level":"info","ts":"...","msg":"Deploy started","service":"api","tag":"v1.2.3","env":"prod"}
```

---

## Building & Distributing

```makefile
# Makefile
VERSION     := $(shell git describe --tags --always --dirty)
BUILD_TIME  := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS     := -ldflags "-X main.version=$(VERSION) -s -w"
PLATFORMS   := linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64

.PHONY: build test lint release clean

build:
	go build $(LDFLAGS) -o bin/dtool .

test:
	go test -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

lint:
	golangci-lint run ./...

release:
	@for platform in $(PLATFORMS); do \
		GOOS=$$(echo $$platform | cut -d/ -f1); \
		GOARCH=$$(echo $$platform | cut -d/ -f2); \
		ext=$$([ "$$GOOS" = "windows" ] && echo ".exe" || echo ""); \
		GOOS=$$GOOS GOARCH=$$GOARCH go build $(LDFLAGS) \
			-o bin/dtool-$$GOOS-$$GOARCH$$ext .; \
		echo "Built: bin/dtool-$$GOOS-$$GOARCH$$ext"; \
	done

clean:
	rm -rf bin/ coverage.out coverage.html
```

```bash
# Install locally:
go install github.com/JawherKl/devops-tool@latest

# Distribute via:
# - GitHub Releases (upload binaries)
# - Homebrew tap: brew install JawherKl/tap/dtool
# - apt/yum repository
# - Docker: FROM scratch + COPY binary
```