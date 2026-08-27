# Nido: local y VPS

Nido puede ejecutarse en local y en `nido.momentumia.com` con la misma aplicación. En Cloudflare Sites usa D1; en el VPS usa una base SQLite persistente dentro de un volumen Docker.

## Arranque local

Necesitas Node.js 22.13 o posterior.

```bash
npm install
npm run local
```

Abre `http://localhost:3000`. Cada arranque verifica el esquema de forma segura y, si hace falta, crea la base local dentro de `.wrangler/state`.

Para comprobar una compilación de producción:

```bash
npm test
```

## Despliegue en el VPS

Requisitos: Docker con Compose, Caddy instalado en el host y un registro DNS `A` o `AAAA` de `nido.momentumia.com` apuntando al VPS.

1. Copia o clona el proyecto en el servidor.
2. Construye y arranca Nido:

   ```bash
   docker compose -f compose.vps.yml up -d --build
   docker compose -f compose.vps.yml ps
   ```

3. Genera una contraseña cifrada para Caddy:

   ```bash
   caddy hash-password
   ```

4. Copia el bloque de `deploy/Caddyfile.example` al Caddyfile del servidor. Define las credenciales sin escribirlas en el repositorio:

   ```bash
   sudo systemctl edit caddy
   ```

   Añade este bloque, sustituyendo los valores:

   ```ini
   [Service]
   Environment="NIDO_AUTH_USER=tu_usuario"
   Environment="NIDO_AUTH_HASH=el_hash_generado"
   ```

   Valida y recarga Caddy:

   ```bash
   sudo caddy validate --config /etc/caddy/Caddyfile
   sudo systemctl reload caddy
   ```

5. Abre `https://nido.momentumia.com` e inicia sesión con esas credenciales.

El contenedor solo publica la aplicación en `127.0.0.1:43129`; Caddy es el único punto expuesto a Internet y obtiene/renueva HTTPS automáticamente.

## Operaciones habituales

| Acción | Comando |
|---|---|
| Ver estado | `docker compose -f compose.vps.yml ps` |
| Ver registros | `docker compose -f compose.vps.yml logs -f nido` |
| Actualizar | `git pull && docker compose -f compose.vps.yml up -d --build` |
| Detener | `docker compose -f compose.vps.yml down` |
| Verificar desde el VPS | `curl -I http://127.0.0.1:43129` |

## Datos y copias de seguridad

Los datos viven en el volumen `nido-data` y sobreviven a reconstrucciones y reinicios. `docker compose down` no los elimina; evita `docker compose down -v` salvo que quieras borrar todo.

Copia de seguridad:

```bash
docker compose -f compose.vps.yml exec -T nido \
  sh -c 'tar -czf - -C /data .' > "nido-backup-$(date +%F).tar.gz"
```

Guarda la copia fuera del VPS. Antes de restaurar, detén Nido y conserva una copia del volumen actual.

## Comprobación final

- `https://nido.momentumia.com` muestra el diálogo de acceso.
- La aplicación abre y permite crear un registro.
- El contenedor figura como `healthy`.
- El registro sigue presente después de `docker compose restart nido`.
