# Lantern Suite

## Testing

To build Dockerfile:

```bash
docker build -t lantern-suite:latest .
```

To run tests locally:

```bash
# Build the image without cache
docker build --no-cache -t lantern-test .

# Run the container
docker run --rm -v $(pwd)/test:/test -e POSTGRES_HOST_AUTH_METHOD=trust -d --name lantern-test-container lantern-test

# Run the tests
docker exec lantern-test-container bash -c "/test/run-all.sh || exit 1"

# Delete the image after running the tests
docker rmi lantern-test
```
