#!/bin/sh
# Engine B entrypoint — single container for fair resource pinning:
# nginx daemonizes (its own master + 2 workers), php-fpm stays in the
# foreground as PID 1 so it receives compose stop signals and its master
# respawns any crashed child. No supervisord: one fewer resident process
# inside the pinned budget; if nginx itself dies the engine run is invalid
# anyway and the health check fails loudly.
set -e
nginx
exec php-fpm -F
