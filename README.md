# labels-action

A GitHub Action to intercept Docker and Docker Buildx commands and inject build metadata as labels, or optionally send labels via `curl` to an external endpoint.

## Usage

Search for **labels-action** in the GitHub Marketplace, or reference it directly in your workflow:

```yaml
uses: scribe-security/labels-action@v1
```

### Inputs

| Input  | Description                                                                                            | Default |
| ------ | ------------------------------------------------------------------------------------------------------ | ------- |
| `curl` | Whether to POST labels to an external endpoint instead of injecting them into Docker commands.         | `false` |
| `url`  | The HTTP endpoint to which labels will be POSTed if `curl` is `true`. Required when `curl` is enabled. | —       |

## Examples

### 1. Injecting labels into Docker commands

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Inject build labels
        uses: scribe-security/labels-action@v1
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: myorg/myapp:latest
```

### 2. Sending labels via curl

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Send build labels to external service
        uses: scribe-security/labels-action@v1
        with:
          curl: true
          url: https://metrics.example.com/labels
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: myorg/myapp:latest
```

### 3. Raw `curl` example

You can also test your endpoint directly with `curl`:

```bash
curl -X POST https://metrics.example.com/labels \
  -H "Content-Type: application/json" \
  -d '{
    "GITHUB_SHA": "${{ github.sha }}",
    "GITHUB_RUN_NUMBER": "${{ github.run_number }}"
}'
```
