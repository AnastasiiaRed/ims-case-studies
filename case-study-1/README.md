# shallow-clone-helper

Shallow-clones a git repo for any UNIX compatible OS (POSIX support).

## Requirements

- `git > 1.8.1.4`
- `gh` CLI for private repos (local testing)
- GitHub App token for private repos (production)

## Usage

### Without container

```sh
# public
sh shallow-clone-helper.sh -r https://github.com/chrislgarry/Apollo-11.git

# private
GIT_TOKEN="$(gh auth token)" sh shallow-clone-helper.sh \
  -r https://github.com/org/repo.git -d ./repo
```

### Inside container

```sh
# public
docker run --rm -i --entrypoint sh alpine/git \
  -s -- -r https://github.com/chrislgarry/Apollo-11.git \
  < shallow-clone-helper.sh


# private
# login once to github
gh auth login

# clone
GIT_TOKEN="$(gh auth token)" docker run --rm -i \
  -e GIT_TOKEN \
  --entrypoint sh alpine/git \
  -s -- -r https://github.com/org/repo.git -d /repo \
  < shallow-clone-helper.sh
```



For production replace `gh auth token` with a GitHub App installation token.

## Parameters

| Flag | Description |
|------|-------------|
| `-r` | Repository URL (required) |
| `-d` | Destination directory (optional, defaults to `/tmp/clone_<pid>`) |
| `-f` | Force overwrite if destination exists (optional) |

## Environment

| Variable | Description |
|----------|-------------|
| `GIT_TOKEN` | Token for private repositories |
| `GIT_USERNAME` | Username (default: `oauth2`) |