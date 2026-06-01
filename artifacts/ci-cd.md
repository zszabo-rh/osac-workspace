# OSAC CI/CD Workflows

## Fulfillment Service
- **check-pull-request.yaml**: Pre-commit, code format (gofmt), generated code check, unit tests, integration tests (Helm + Kustomize)
- **publish-image.yaml**: Build and publish container image
- **publish-charts.yaml**: Publish Helm charts
- **publish-proto.yaml**: Publish protobuf definitions

## OSAC Operator
- **pre-commit.yaml**: Pre-commit hooks
- **build-image.yaml**: Build and publish container image

## OSAC AAP
- **tests.yml**: ansible-lint on PRs and daily schedule
- **execution-environment.yml**: Build and push AAP Execution Environment image to GHCR

## Fulfillment CLI
- **check-pull-request.yaml**: PR validation
- **release.yaml**: Build and release binaries

## Development Workflow

### Component-only changes
1. Implement and unit test locally — `ginkgo run -r`
2. Integration test locally — use KIND environment
3. Submit PR — CI runs full automated test suite

### Cross-component or provisioning features
1. Implement and unit test locally
2. Integration test locally where possible
3. Build custom images — push to personal Quay registry
4. Deploy personal stack on hypershift1 — use osac-installer overlay
5. Run E2E tests — use `osac-test-infra` playbooks
6. For bare metal testing — request machines from ESI contacts
7. Submit PR — CI runs full automated test suite
