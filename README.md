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
