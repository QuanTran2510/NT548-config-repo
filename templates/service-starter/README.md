# Service starter

A minimal service plus the CI that takes it to the platform. Copy this folder into a new repo.

1. Rename the service in `.github/workflows/ci.yml` (`service: CHANGE-ME` -> e.g. `shop-cart`).
2. Add the secret `CONFIG_REPO_TOKEN` to the repo (fine-grained token, Contents read/write on the config-repo):
   `gh secret set CONFIG_REPO_TOKEN`
3. Push to `main`. CI runs the tests, builds the image, refuses a root image, smoke-tests it, scans it with Trivy and
   pushes `ghcr.io/<you>/<service>:<sha>`. The job summary shows the exact image reference.
4. First time only: set the GHCR package to **Public**, then register the service in the portal with that image.
5. From then on every push to `main` updates the tag in the config-repo and ArgoCD rolls it out.

Rules enforced both here and by the cluster: non-root user, explicit tag (never `latest`), image from ghcr.io/<you>/.

## Rolling back
A bad release is a Git revert of the `ci(<service>): <tag>` commit in the config-repo; ArgoCD returns to the previous image.
