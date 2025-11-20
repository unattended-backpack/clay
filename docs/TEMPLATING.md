# Using Clay as a Template

This repository is designed to be a template for creating new multi-image projects. The workflow automatically discovers and builds all images defined in `.env.maintainer`.

## Quick Start

When creating a new project from this template:

1. **Define your images in `.env.maintainer`**:
   ```bash
   # Image naming: <UPPERCASE>_NAME=published-name
   # The workflow looks for Dockerfile.<lowercase> to build
   MYAPP_NAME=myapp
   WORKER_NAME=myapp-worker
   ```

2. **Create corresponding Dockerfiles**:
   - `Dockerfile.myapp`
   - `Dockerfile.worker`

3. **Add binary sources** (if using Rust):
   - `src/bin/myapp.rs`
   - `src/bin/worker.rs`

4. **Update `Cargo.toml`** to include your binaries:
   ```toml
   [[bin]]
   name = "myapp"
   path = "src/bin/myapp.rs"

   [[bin]]
   name = "worker"
   path = "src/bin/worker.rs"
   ```

That's it! The workflow will automatically:
- Discover all `*_NAME` variables in `.env.maintainer`
- Check for corresponding `Dockerfile.*` files
- Build all valid images in parallel
- Push to all configured registries
- Sign and release artifacts

## Adding a New Image

To add a new image to an existing project:

1. Add `<NAME>_NAME=published-name` to `.env.maintainer`
2. Create `Dockerfile.<lowercase-name>`
3. Create `src/bin/<lowercase-name>.rs` (if applicable)
4. Update `Cargo.toml` with the new binary

The workflow will automatically include it in the next release.

## Removing an Image

1. Remove the `*_NAME` variable from `.env.maintainer`
2. Delete the corresponding `Dockerfile.*`
3. Delete the source files

The workflow will automatically skip it.

## How It Works

The `discover-images` job in `.github/workflows/release.yml`:
1. Reads all `*_NAME` variables from `.env.maintainer`
2. Checks if `Dockerfile.<lowercase>` exists for each
3. Generates a build matrix with valid images
4. Passes the matrix to the `build-images` job

This means **you never need to modify the workflow file** when adding or removing images.

## Requirements

- At least one `*_NAME` variable with a corresponding `Dockerfile.*`
- Each Dockerfile must follow the multi-stage build pattern (see existing Dockerfiles)
- Binary names must match the lowercase image name
