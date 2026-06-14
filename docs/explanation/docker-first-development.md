# Explanation — Docker-first development

> **Diátaxis quadrant:** Explanation.
> **Release:** `0.1.0-beta4`.

## The rule

All development happens inside the `waffle-dev` Docker container. Native PHP on the host machine is unsupported. Every command in these docs follows the pattern:

```bash
docker exec -it -w /waffle-commons/<component> waffle-dev <command>
```

This is not because we love Docker. It's because the alternative (host-native PHP) costs more than it saves.

## What the container guarantees

| Guarantee | Why it matters |
| :--- | :--- |
| **PHP 8.5 exactly** | The codebase uses Property Hooks, Asymmetric Visibility, typed constants. PHP 8.4 won't compile parts of it. |
| **`ext-yaml`** (PECL YAML) | `waffle-commons/config` uses the native YAML extension; PHP's `yaml_parse_*` functions don't exist in stock builds. |
| **FrankenPHP runtime** | Required for `runtime`'s worker tests and any FrankenPHP-specific behaviour. |
| **Xdebug** | Step debugging works out of the box. |
| **Composer** | Pinned version, consistent across all contributors. |
| **Identical environment everywhere** | Your laptop, the CI runner, the contributor 8 timezones away — same Docker image, same outcome. |

The cost of replicating that on a host machine — particularly the PHP 8.5 + ext-yaml combination, which is still not in most distro repos — is high enough that we just don't.

## What we lose

| Loss | Mitigation |
| :--- | :--- |
| Direct host editor integration with PHP tooling. | Most IDEs (PhpStorm, VS Code) have first-class Docker remote-interpreter support. Configure the container as the project's PHP interpreter. |
| Shell speed when starting tools. | `docker exec` adds ~200ms per invocation. Not noticeable in interactive use; matters in fast loops, mitigated by keeping a long-lived shell open inside the container (`docker exec -it -w /waffle-commons waffle-dev bash`). |
| Native paths in tool output. | Tools running inside the container see `/waffle-commons/security/src/X.php`, not `/Users/you/.../security/src/X.php`. Editor jump-to-definition with Docker remote interpreter handles this automatically. |

## Why not `nix`, `asdf`, `phpbrew`, or `mise`?

We considered them. Each one solves the "PHP version" problem but not the "ext-yaml on every developer's machine" problem, and they all leave room for environmental drift between contributors. Docker is the simplest answer that solves both.

If a future contributor uses one of those tools and gets things working locally, *great* — it's not forbidden, just unsupported. CI runs through Docker. The skeleton ships with Docker. Documentation is written assuming Docker. Help is best-effort outside that.

## "But I just want to run one test quickly"

You can:

```bash
docker exec -it -w /waffle-commons/security waffle-dev vendor/bin/phpunit --filter MyTest
```

The `docker exec` overhead is ~200ms. The test itself is the same as native.

If you find yourself running PHPUnit in a tight `--watch` loop, drop into a persistent shell:

```bash
docker exec -it -w /waffle-commons/security waffle-dev bash
# now inside the container
vendor/bin/phpunit --filter MyTest      # fast
vendor/bin/phpunit --filter OtherTest   # also fast
```

## "But the `loop.sh` script runs on the host, not in the container"

True. `loop.sh` is host-side — it iterates over component directories with shell `cd`. It doesn't wrap commands in `docker exec` because:

- many of its uses are pure shell (`git status`, `ls`);
- for PHP commands, contributors generally already have a shell open in the container and don't want the overhead of nested wrappers.

If you need a PHP command run across all components from the host, wrap explicitly:

```bash
./loop.sh bash -c 'docker exec -w "/waffle-commons/$(basename "$PWD")" waffle-dev composer mago'
```

See [`loop.sh` reference](../reference/scripts/run-all.md).

## When this rule will probably loosen

If PHP 8.5 + ext-yaml becomes universally available across mainstream distros and macOS/Windows package managers, the case for host-native development gets stronger. We'll revisit when the friction tips the other way.

Until then: Docker.

## Related

- [Docker environment reference](../reference/docker-environment.md) — the concrete `waffle-dev` service.
- [Set up your monorepo workspace](../tutorials/setup-your-monorepo-workspace.md) — boots the container.
