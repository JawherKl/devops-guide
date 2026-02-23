# Docker CLI — Quick Reference Card

> Print this and stick it on your monitor until the commands are muscle memory.

---

## Images

```bash
docker pull IMAGE[:TAG]               # download image
docker images                         # list local images
docker image rm IMAGE                 # remove image
docker image prune                    # remove dangling images
docker image prune -a                 # remove ALL unused images
docker history IMAGE                  # show layer history
docker inspect IMAGE                  # full metadata JSON
```

## Containers — Run

```bash
docker run IMAGE                      # run in foreground
docker run -d IMAGE                   # run detached (background)
docker run -it IMAGE sh               # interactive shell
docker run --rm IMAGE CMD             # run and auto-remove
docker run --name NAME IMAGE          # give it a name
docker run -p 8080:80 IMAGE           # map host:container port
docker run -e KEY=VAL IMAGE           # set environment variable
docker run -v VOL:/path IMAGE         # mount named volume
docker run -v /host:/ctr IMAGE        # bind mount host path
docker run --network NET IMAGE        # use specific network
docker run --memory 512m IMAGE        # memory limit
docker run --cpus 1.0 IMAGE           # CPU limit
docker run --restart unless-stopped   # auto-restart policy
```

## Containers — Inspect

```bash
docker ps                             # running containers
docker ps -a                          # all (incl. stopped)
docker inspect NAME                   # full JSON metadata
docker inspect -f '{{.State.Status}}' NAME  # specific field
docker logs NAME                      # stdout/stderr logs
docker logs -f NAME                   # follow (tail -f)
docker logs --tail 50 -t NAME         # last 50 lines + timestamps
docker stats                          # live resource usage (all)
docker stats NAME --no-stream         # snapshot one container
docker top NAME                       # processes inside
docker diff NAME                      # filesystem changes
```

## Containers — Interact

```bash
docker exec -it NAME sh               # open shell in running container
docker exec NAME CMD                  # run command, return output
docker exec -u root NAME sh           # exec as root
docker cp NAME:/remote ./local        # copy from container
docker cp ./local NAME:/remote        # copy to container
docker attach NAME                    # attach to PID 1 (careful!)
```

## Containers — Lifecycle

```bash
docker stop NAME                      # SIGTERM → wait → SIGKILL
docker kill NAME                      # SIGKILL immediately
docker restart NAME                   # stop + start
docker pause NAME                     # freeze (SIGSTOP)
docker unpause NAME                   # resume
docker rm NAME                        # remove stopped container
docker rm -f NAME                     # force remove running
docker container prune                # remove all stopped
```

## Volumes

```bash
docker volume create VOL              # create named volume
docker volume ls                      # list volumes
docker volume inspect VOL             # volume details
docker volume rm VOL                  # remove (must be unused)
docker volume prune                   # remove all unused
```

## Networks

```bash
docker network ls                     # list networks
docker network create NET             # create bridge network
docker network inspect NET            # network details
docker network connect NET CTR        # connect container
docker network disconnect NET CTR     # disconnect container
docker network rm NET                 # remove network
docker network prune                  # remove unused networks
```

## System

```bash
docker system df                      # disk usage
docker system prune                   # clean unused resources
docker system prune -a                # clean everything unused
docker system prune --volumes         # also remove volumes
docker info                           # daemon info
docker version                        # client + server version
docker events                         # live event stream
```

## Build

```bash
docker build -t NAME:TAG .            # build from Dockerfile
docker build -f FILE -t NAME .        # use specific Dockerfile
docker build --no-cache -t NAME .     # skip cache
docker build --target STAGE -t NAME . # build specific stage
docker buildx build --platform linux/amd64,linux/arm64 . # multi-arch
```

---

## Common Patterns

```bash
# Stop and remove all containers
docker rm -f $(docker ps -aq)

# Remove all dangling images
docker image prune

# Get IP of a container
docker inspect -f '{{.NetworkSettings.IPAddress}}' NAME

# See which port a container is using on the host
docker port NAME

# Follow logs for multiple containers
docker compose logs -f service1 service2

# One-liner: build, run, test, clean
docker build -t test . && docker run --rm test npm test ; docker rmi test
```