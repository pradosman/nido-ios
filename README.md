# Nido para iPhone: local y VPS

Nido es una app nativa para iPhone. La interfaz web está retirada y `/` responde con `404`; el servicio conserva y sincroniza los datos entre cuidadores mediante la API. En el VPS utiliza una base SQLite persistente dentro de un volumen Docker.

## Arranque local

Necesitas Node.js 22.13 o posterior.

```bash
npm install
npm run local
```

Cada arranque verifica el esquema de forma segura y, si hace falta, crea la base local dentro de `.wrangler/state`. Comprueba el servicio con:

```bash
curl http://localhost:3000/api/nido/status
```

El estado público indica las capacidades disponibles:

```json
{"canCreateHousehold":true,"canJoinWithInvitation":true}
```

Para usarlo desde el Simulator, configura `NIDO_API_BASE_URL` en el target `Nido` con la dirección local del servicio. En un iPhone físico usa la IP local del Mac, no `127.0.0.1`.

Para comprobar una compilación de producción:

```bash
npm test
```

## Despliegue en Dokploy

Requisitos: un registro DNS `A` de `nido.momentumia.com` apuntando al VPS y una clave SSH de sólo lectura con acceso al repositorio privado.

1. Crea un servicio de tipo **Docker Compose** en Dokploy.
2. Selecciona el proveedor **Git** y configura:

   | Campo | Valor |
   |---|---|
   | Repository URL | `git@github.com:pradosman/nido-ios.git` |
   | Branch | `main` |
   | Compose Path | `./compose.vps.yml` |

3. En **Domains**, añade el dominio limitándolo a la API:

   | Campo | Valor |
   |---|---|
   | Host | `nido.momentumia.com` |
   | Path | `/api` |
   | Service | `nido` |
   | Container Port | `3000` |
   | HTTPS | Activado |
   | Certificate | Let's Encrypt |
   | Strip Path | Desactivado |

4. Guarda y pulsa **Deploy**. Dokploy conecta Traefik al puerto interno `3000`; el Compose no publica ningún puerto directamente en el host.
5. Comprueba la API:

   ```bash
   curl https://nido.momentumia.com/api/nido/status
   ```

Al usar `/api` como ruta pública, Traefik expone únicamente la API. `/api/nido/status` es público; las API de datos del hogar requieren `Authorization: Bearer <credencial>`. La app guarda esa credencial en el Keychain del iPhone. No añadas `basic_auth` delante de la API: impediría que la app nativa sincronizase.

## Operaciones habituales

| Acción | Comando |
|---|---|
| Ver estado | Dokploy → Deployments |
| Ver registros | Dokploy → Logs |
| Actualizar | Dokploy → Redeploy |
| Detener | Dokploy → Stop |
| Verificar | `curl https://nido.momentumia.com/api/nido/status` |

## Datos y copias de seguridad

Los datos viven en el volumen `nido-data` y sobreviven a reconstrucciones y reinicios. `docker compose down` no los elimina; evita `docker compose down -v` salvo que quieras borrar todo.

Copia de seguridad:

```bash
docker compose -p nido-nido-wuwhrr -f compose.vps.yml exec -T nido \
  sh -c 'tar -czf - -C /data .' > "nido-backup-$(date +%F).tar.gz"
```

El nombre de proyecto puede variar; Dokploy lo muestra al principio de cada despliegue. También puedes programar la copia del volumen `nido-data` desde **Volume Backups**. Guarda las copias fuera del VPS. Antes de restaurar, detén Nido y conserva una copia del volumen actual.

## Comprobación final

- `/` responde con `404` y no sirve una interfaz web.
- `/api/nido/status` responde con `canCreateHousehold` y `canJoinWithInvitation`.
- Las API de datos del hogar rechazan peticiones sin credencial bearer.
- La aplicación de iPhone abre y permite crear un registro.
- Un segundo iPhone puede unirse con una invitación y ve la misma información.
- El contenedor figura como `healthy`.
- El registro sigue presente después de `docker compose restart nido`.
