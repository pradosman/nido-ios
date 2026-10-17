# Validación local del backend — 17 de octubre de 2026

## Bloqueo observado

La compilación y la comprobación TypeScript no han terminado en sus límites de ejecución. El muestreo nativo confirma esperas en lecturas del sistema de archivos de dependencias existentes. No se ha observado un error de compilación que justifique cambiar código o configuración.

- `node node_modules/vinext/dist/cli.js build`: detenido mediante SIGTERM a los 88 segundos. Solo imprimió `vinext build (Vite 8.2.2)`; CPU 0,0 %, RSS aproximada 89–94 MiB.
- El proceso avanzaba lentamente entre archivos abiertos de `tailwindcss/dist/lib.js`, `enhanced-resolve/lib/AliasPlugin.js`, `enhanced-resolve/lib/JoinRequestPlugin.js` y `source-map-js/lib/source-map-consumer.js`.
- `sample` situó la pila principal en `node::fs::ReadFileUtf8 → uv_fs_read → uv__fs_work → read`.
- La ejecución acotada de TypeScript con `--traceResolution` se detuvo leyendo declaraciones existentes de Drizzle. Un muestreo de un segundo situó 785 de 786 muestras en `uv_fs_read → uv__fs_work → read`; `lsof` identificó `drizzle-orm/pg-core/columns/line.d.ts`. A los 24 segundos había avanzado a `columns/varchar.d.ts`, todavía con CPU 0,0 %.

Comando TypeScript de diagnóstico:

```sh
node node_modules/typescript/bin/tsc --noEmit --skipLibCheck --target es2022 --module nodenext --moduleResolution nodenext --traceResolution app/api/nido/baby-care/route.ts db/schema.ts
```

Controles independientes: `tsc --version` devuelve `5.9.3`; la lectura de `_tsc.js` ya en caché (6.213.092 bytes) tarda 1–2 ms. Una pasada de Python sobre archivos de `enhanced-resolve/lib` excedió 15 segundos; ocho archivos leídos después respondieron inmediatamente. Los archivos inspeccionados tienen bloques asignados y no muestran la marca `dataless`. La causa concreta de la espera de almacenamiento sigue sin verificar; una posible hidratación es solo una hipótesis.

Las muestras extraídas y los detalles están en `baby-care-build-diagnosis.log`. No se instalaron dependencias ni se modificó código de producto. TDD unitario no aplica a este diagnóstico; lo sustituye el muestreo reproducible del proceso y la comprobación independiente de lectura.

## Último intento acotado

El precalentamiento utilizó ocho lectores sobre 2.310 archivos de los paquetes `tailwindcss`, `enhanced-resolve`, `drizzle-orm` y `source-map-js`, sin leer configuración privada. Se detuvo por su límite de 115 segundos (salida 124). Último progreso registrado: 750 archivos en 92,34 segundos; 580 lecturas tardaron más de 100 ms.

El último `npm run build` tuvo un límite de 115 segundos dentro del presupuesto de 120. Tras precalentar, avanzó por las cinco etapas: análisis cliente (34,33 s), análisis servidor (6,89 s), RSC (5,85 s), cliente (29,83 s) y SSR (130 ms). La etapa cliente registró 16,6 segundos en `vinext:google-fonts writeBundle`. Sin embargo, el comando no terminó antes del límite: el supervisor devolvió `timeout115 elapsed 115.02`. Se detuvo el grupo con SIGTERM y el proceso vinext restante con SIGKILL. `build:migrate` no llegó a ejecutarse.

Resultado: las cinco etapas imprimieron su marca de compilación, pero la compilación de producción completa sigue **sin validar**, porque no se obtuvo salida cero ni finalizó el empaquetado. El registro exacto está en `baby-care-build-final.log`. No se afirma que el código tenga un fallo ni que la compilación completa haya pasado.


## Seguimiento con caché caliente

Se amplió el presupuesto a 240 segundos para un último `npm run build` (supervisor con límite de 235 s). Las cinco etapas de compilación finalizaron en aproximadamente 12 segundos. El empaquetado posterior siguió copiando dependencias: una muestra de 746 observaciones situó la pila en `node::fs::CopyFile → uv_fs_copyfile → uv__fs_work → pread`; `lsof` mostró un archivo de React DOM de origen y su destino homólogo bajo `dist/standalone/node_modules`. A los 69 segundos el proceso había avanzado a copiar declaraciones de `vinext/dist/entries`. Esto identifica trabajo activo de empaquetado, no una espera de limpieza de fuentes o de handles abiertos.

La ejecución independiente de `npm run build:migrate` terminó con salida **0**. Se lanzó además la comprobación completa `tsc --noEmit --incremental false -p tsconfig.json`, con límite de 115 segundos. La comprobación TypeScript completa excedió 115 segundos sin emitir diagnósticos. El supervisor lanzó SIGTERM; la limpieza posterior con SIGKILL del grupo informó `PermissionError: Operation not permitted`, y la comprobación de procesos confirmó que el PID de tsc ya no existía. El supervisor devolvió 1 por esa excepción de limpieza, no por un diagnóstico del compilador. No se obtuvo una salida del compilador que permita declarar la comprobación aprobada o fallida por código. La compilación ampliada excedió el límite: `timeout235 elapsed 236.19`, con supervisor de salida 0 tras controlar ese timeout. El muestreo a los 209 segundos mostraba copia de `vinext/dist/server/dev-stack-sourcemap.d.ts`. No hubo salida cero de `npm run build` ni se ejecutó su `build:migrate` encadenado. Se confirmó que no quedaban los procesos propios.


## Validación aislada completada

Se copió el código **actual** del árbol de trabajo a un directorio temporal fuera de Documents (`/var/folders/s3/2n7g330n7jq18yr7ts85tjsh0000gn/T/nido-backend-validation-q5rdf34g`). Se incluyeron app, db, public, drizzle-pg, worker, deploy, tests y los nueve archivos de configuración/lock necesarios. No se copiaron archivos `.env`. La comparación SHA-256 de los 93 archivos copiados contra el árbol de trabajo devolvió **cero diferencias**, incluida la ruta nueva de baby-care.

El lockfile se conservó exactamente (SHA-256 `7c763dc103ddabf1f015ad6c70ce3fd901544f45a6ebe61d986ae23a5c75d9cc`). Se ejecutó `npm ci --no-audit --no-fund` exclusivamente en el directorio temporal: salida **0**, 5,87 s. No se modificaron las dependencias del proyecto.

- `npm run build`: salida **0**, 4,59 s; generó `dist/standalone/` y ejecutó correctamente el `build:migrate` encadenado.
- `node node_modules/typescript/bin/tsc --noEmit --incremental false -p tsconfig.json`: salida **0**, 1,43 s, sin diagnósticos.

Registros: `baby-care-isolated-install.log`, `baby-care-isolated-build.log`, `baby-care-isolated-types.log`. La compilación de producción y los tipos del código actual quedan **validados en el entorno temporal limpio**; las ejecuciones originales bajo Documents conservan el bloqueo de lecturas/copia de su árbol de dependencias existente. No se atribuye una causa concreta de sistema operativo sin evidencia adicional.


La ejecución opcional de la suite completa dentro de esta copia parcial terminó con salida 1 (48,73 s): 75 pruebas, 56 aprobadas, 14 fallidas y 5 omitidas. Sus fallos corresponden a recursos no copiados de despliegue y de iOS (`compose.vps.yml`, `.env.example`, `.dockerignore`, README, Dockerfile, `.openai/hosting.json`, scripts de iOS y Live Activity). Esta copia se preparó para compilar el backend; ese intento no valida la suite completa. Se intentó incorporar cinco recursos de despliegue, pero la primera copia, Dockerfile, quedó detenida en lectura/copia de Documents y se canceló alrededor de 80 s. No se reejecutó ni se alteraron expectativas. Para la suite completa se conserva la evidencia del árbol original registrada por el agente principal.
