# Publicación de privacidad y soporte — 15 de octubre de 2026

Estado: **publicado y verificado por HTTPS**, tras la autorización «Hazlo» para ejecutar el plan de cierre.

- [Privacidad](https://nido.momentumia.com/api/nido/legal/privacy): HTTP 200, HTML español, contacto aprobado, declaración correcta de conservación de autoría y `Cache-Control: no-store`.
- [Soporte](https://nido.momentumia.com/api/nido/legal/support): HTTP 200, HTML español, contacto aprobado y `Cache-Control: no-store`.
- Salud pública: HTTP 200. API privada sin credenciales: HTTP 401. Raíz: HTTP 404.

## Alcance y comprobaciones

Se volvió a comprobar el VPS Hostinger `943574`, `srv943574.hstgr.cloud`, IP `148.230.108.174`. El checkout seguía en `b6a8f58bfcf99c0029e5698652e2dc25f29cf1c7`; su único cambio tracked era `compose.vps.yml`, con SHA-256 `f1eb005f1ced4916425053bde12a3ff8475f1aaa4ad78a1bfb36042fb72cd8b3`.

Se aplicó exactamente el [paquete legal validado](legal-only-deployment-2026-10-15.md), parche SHA-256 `35a8b6aa1edfe23803c2f3822b9c8af700e68742ca5ea0c56432257beecb7323`. Los cuatro archivos añadidos coinciden en tamaño y hash con el manifiesto. `git apply --check` y la comprobación de reversión pasaron.

La construcción remota terminó con código 0. Se recreó solo el servicio `nido`, mediante Compose con `--no-deps --no-build --pull never`. La imagen activa es `sha256:de5193fc87ba53e61cc91d64f3a069a769a744e8380e6adb16b8893c7545984a`; el contenedor quedó saludable. Los otros **17 contenedores remotos** conservaron sus identificadores, incluido PostgreSQL. No se ejecutaron migraciones ni se modificaron Compose, variables o datos de producción.

La validación TDD de este código sigue siendo la del paquete preparado: contratos HTTP rojos antes de implementación, verdes enfocados y suite **48/48 con PostgreSQL real, sin omisiones**. La publicación no añade comportamiento; su comprobación específica es construcción, estado del servicio y los cinco escenarios HTTP públicos anteriores.

## Reversión y persistencia

La imagen anterior permanece etiquetada `nido-rollback:legal-20261015-8d9ef7`, correspondiente a `sha256:89f44244667ef7c1e89b519cdb288d3e335d209b69d0ab0cbc5e570a70e4b755`. El rollback afecta solo a las cuatro adiciones y la imagen de la API, siguiendo el procedimiento del plan; PostgreSQL queda fuera.

Los cuatro archivos quedaron aislados en el commit `f56c9ddbd1f1a03c4318d7d83fc8e9ccee9527fd`, hijo directo de la revisión base, después de comprobar que no había cambios preparados y que el único cambio ajeno era Compose. El commit incluye los tres archivos de producción y su contrato HTTP; Compose sigue intacto y fuera de él.

El commit se publicó en la rama `codex/legal-pages-release-20261015` del repositorio de origen y se abrió la [PR de integración #1](https://github.com/pradosman/nido-ios/pull/1), en borrador y adjunta a esta tarea. Falta integrar esa PR en `main` antes de un redeploy que sustituya el checkout desde esa rama. No se realizó `git pull`, `reset`, `clean` ni push a `main`.

La revisión independiente aprobó los cuatro archivos y la evidencia 48/48, sin bloqueos de código. Antes de integrar se comprobó la configuración real de Dokploy en modo lectura: origen `git`, rama `main`, `autoDeploy=true`, activación `push`. No se ha cambiado esa configuración ni se ha fusionado la PR para provocar un redeploy automático sin controlar la conservación del Compose local. La lista de webhooks del repositorio está vacía, pero eso no demuestra ausencia de otras integraciones o disparadores.

Evidencia remota: `/root/nido-releases/legal-20261015-8d9ef7/`. Copia local: `/Users/pradosman/.codex/recoveries/nido-20261015/legal-live-deploy-20261015-8d9ef7/`, con build, inventario previo y verificación posterior. La copia cifrada recuperable anterior sigue preservada fuera del VPS.

Este despliegue no incluye el backend nuevo de borrado/revocación Apple y no cierra ese requisito de publicación en App Store.
