# Verificación de eliminación de cuenta

Esta evidencia documenta la primera etapa: permitir el borrado de una cuenta sin hogar. La implementación actual añade después la autorización y revocación Apple descritas en [apple-account-revocation.md](apple-account-revocation.md); los hashes y resultados siguientes corresponden al candidato de aquella primera etapa.

La ruta permite que una sesión válida elimine su propia cuenta aunque el usuario aún no pertenezca a un hogar. El borrado de hogares por parte del owner y el borrado individual de caregivers conservan su comportamiento.

## Evidencia

| Comprobación | Resultado |
|---|---|
| Rojo antes del cambio | 4 casos; 3 pasan y el usuario autenticado sin hogar falla con 403: «An active household membership is required» (esperado: 200). |
| Verde enfocado | 4/4: cuenta sin hogar y sus sesiones se borran; sin sesión sigue en 401; borrar un caregiver conserva el hogar y el owner; borrar un owner elimina el hogar y las sesiones de sus miembros. |
| Suite backend | 55/55 pruebas, 0 fallos y 0 omitidas en los 15 archivos `tests/*.test.mjs`. Las cinco pruebas de PostgreSQL real pasaron tras aplicar migraciones a una base PostgreSQL 17.10 efímera. |
| Compilación | `npm run build` terminó correctamente en el candidato aislado `/tmp/nido-account-suite-20261015`. |

La base de pruebas usó almacenamiento temporal y un puerto enlazado a `127.0.0.1`; el contenedor etiquetado para esta ejecución se eliminó al terminar. No se usó Supabase.

## Alcance y límites

- Los hashes SHA-256 de la ruta y el contrato de prueba coincidían con el árbol canónico en aquella ejecución: `44006cfbe362ed6ae11f4d7fc32919f0632c9e1640d71712be60bf9d3c9c914a` y `77943dcd0beb3f4a8a3de662f034cafec2dc33f7d3bbe8f42d464218b34be1df`.
- La prueba directa desde el árbol canónico quedó bloqueada porque iCloud mantiene `db/schema.ts` como `compressed,dataless`; `brctl status` informó CloudDocs Code 141 («Access denied»). La suite y la compilación se ejecutaron en el candidato aislado con los archivos de ruta y prueba idénticos.
- En aquella primera etapa no se implementó la revocación del token de Apple. La unidad posterior incorpora ese contrato de servidor; la interfaz nativa y la aceptación real por Apple requieren su propia validación.

## Límite de reversión

La unidad de reversión es `app/api/nido/auth/account/route.ts` junto con `tests/account-deletion.contract.test.mjs`. En aquella etapa no se creó ningún commit.
