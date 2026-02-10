# mailu-server

Public repository to deploy a Mailu service inside a Hetzner server

## Useful commands

```bash
docker compose exec mailu-smtp postsuper -d ALL # Delete all mail in the queue
```

```bash
docker compose exec mailu-smtp postqueue -p # Show mail queue
```

>This repo is an example on how to deploy Mailu on a Hetzner server. For more information about Mailu configuration, please refer to the [official documentation](https://mailu.io/2024.06/).

---

## Transport map override & CI automation 🔧

This repo supports a Postfix transport map override so specific addresses (for example, `noreply@dreamit.software` or `osmar.betancourt@dreamit.software`) are relayed to Google instead of delivered locally.

> Important: Postfix is configured to use an LMDB file at `/etc/postfix/transport.map`. The source map you edit lives in `overrides/postfix/transport.map`; CI compiles it and copies the generated LMDB into `/etc/postfix/` during deploy.

### Manual (one-time) steps — copy/paste these on the host where `docker compose` is run

1) Add mappings to `overrides/postfix/transport.map`:

```text
# example: relay noreply and osmar to Google
noreply@dreamit.software smtp:[aspmx.l.google.com]
osmar.betancourt@dreamit.software smtp:[aspmx.l.google.com]
```

2) Compile the map and install the LMDB into `/etc/postfix`:

```bash
# fix permissions on host (bind mount requires write access for container)
chmod 666 ./overrides/postfix/transport.map.lmdb || true

# compile from the overrides source
docker compose exec mailu-smtp postmap /overrides/postfix/transport.map

# copy the generated LMDB into /etc and set ownership/permissions
docker compose exec mailu-smtp bash -lc "cp /overrides/postfix/transport.map.lmdb /etc/postfix/transport.map.lmdb && chown root:postfix /etc/postfix/transport.map.lmdb && chmod 0644 /etc/postfix/transport.map.lmdb"

# reload smtp
docker compose restart mailu-smtp
```

3) Verify everything:

```bash
# Postfix config should point to /etc
docker compose exec mailu-smtp postconf -n | grep transport_maps
# expected: transport_maps = lmdb:/etc/postfix/transport.map, ${podop}transport

# lookups must return the Google relay
docker compose exec mailu-smtp postmap -q 'noreply@dreamit.software' /etc/postfix/transport.map
# expected: smtp:[aspmx.l.google.com]

docker compose exec mailu-smtp postmap -q 'osmar.betancourt@dreamit.software' /etc/postfix/transport.map
# expected: smtp:[aspmx.l.google.com]

# check LMDB perms
docker compose exec mailu-smtp stat -c '%U:%G %a %n' /etc/postfix/transport.map.lmdb
# expected: root:postfix 644
```

4) Make sure there is no local mailbox/alias for the addresses you relay — a local account will always be delivered locally and bypass the transport map.

### CI automation (what the workflow does)

The deployment workflow (`.github/workflows/deploy-production.yml`) will:

- run `postmap /overrides/postfix/transport.map` inside the `mailu-smtp` container
- copy `/overrides/postfix/transport.map.lmdb` to `/etc/postfix/transport.map.lmdb` and set `root:postfix` + `0644`
- restart `mailu-smtp`

Trigger it via **Actions → Deploy Mailu to Hetzner (Production) → Run workflow**.

### Troubleshooting

- If `postmap` fails with permission denied, the LMDB file on the host needs write permissions for the container:

```bash
# on the host
chmod 666 ./overrides/postfix/transport.map.lmdb
```

- If `/overrides/postfix` is not visible inside the container, check the bind mount and working directory:

```bash
# on the host
pwd
ls -la ./overrides

docker inspect mailu-smtp --format '{{range .Mounts}}{{println .Source " -> " .Destination}}{{end}}'
```

- If files exist on the host but not in the container, recreate containers from the correct project dir:

```bash
docker compose down && docker compose up -d --build
```

- If the workflow fails on remote deploy due to quoting, it was fixed to avoid nested single-quote issues (the workflow now uses a double-quoted inner `bash -lc`).

---

### Optional: `Makefile` target (run from repo root)

```makefile
transport:
	@docker compose exec mailu-smtp postmap /overrides/postfix/transport.map && \
	docker compose exec mailu-smtp bash -lc "cp /overrides/postfix/transport.map.lmdb /etc/postfix/transport.map.lmdb && chown root:postfix /etc/postfix/transport.map.lmdb && chmod 0644 /etc/postfix/transport.map.lmdb" && \
	docker compose restart mailu-smtp
```

Run with: `make transport`

---

If you want, I can also add the `Makefile` to the repo and a CI check to verify the map lookup on deploy. Say the word and I’ll add it.