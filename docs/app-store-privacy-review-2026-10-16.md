# Revisión independiente del borrador App Privacy

16 de octubre de 2026. **Sin omisiones concretas demostradas ni contradicciones bloqueantes en el alcance examinado.** No certifica exhaustividad ni cumplimiento general y no constituye una publicación o autorización externa para publicar.

Se solicitó una segunda revisión de solo lectura, independiente de la preparación del mapa. No se utilizaron la interfaz, builds, pruebas, conexiones remotas o material privado de claves.

## Alcance y resultado

Se contrastaron el mapa, el manifiesto canónico de siete tipos, el esquema y las rutas de la base de producción conservada en `legal-only-preparation-20261015/candidate/`, junto a la evidencia existente de infraestructura. El backend nuevo de borrado sigue sin desplegarse; no se presupone activo el staging de credenciales.

| Selección | Evidencia y conclusión |
|---|---|
| Name, Health, Other User Content, User ID | Nombres de bebé/cuidadores, cuidados y notas, cuenta Apple e identificadores de hogar/autor. Respaldados por esquema y flujos de entrada/persistencia. |
| Other Data Types | Fecha de nacimiento completa y obligatoria en profiles. Clasificación residual razonable; no se afirma que Apple publique una equivalencia específica DOB→ese tipo. |
| Product Interaction | Contadores y eventos persistidos de autenticación e invitación. Su uso de seguridad es compatible con App Functionality y no obliga a declarar Analytics. |
| Contacts | Relaciones entre cuidadores, hogar y cuentas. Apple incluye el grafo social; no requiere acceso a la agenda del dispositivo. |
| App Functionality / vinculado Sí / tracking No | Uso de acceso, sincronización, registros, colaboración y seguridad; vínculo mantenido por cuenta/hogar. Sin evidencia examinada de publicidad, intermediarios de datos u otro uso que contradiga las selecciones. |

Referencia primaria contrastada: [App privacy details de Apple](https://developer.apple.com/app-store/app-privacy-details/). Los identificadores del manifiesto también se validaron previamente contra la enumeración oficial DocC. Las tres asignaciones adicionales son inferencias de clasificación justificadas por los campos, no hechos adicionales inventados a partir del manifiesto.

La revisión principal comprobó además que los enlaces `mailto:` de las páginas no adjuntan datos de usuario y que la verificación Apple devuelve subject; no hay un campo de correo de usuario en ese esquema. Publicar el correo de soporte no demuestra recogida de correos de usuarios.

## Límites que se conservan

La configuración examinada de Traefik no declara access-log; Docker rota stdout/stderr y la búsqueda de logger propio fue negativa. Eso no demuestra ausencia absoluta de logs de framework/host/proveedor. El buzón y tratamiento auxiliar de soporte no se han auditado. No constituyen por sí solos una omisión demostrada, pero impiden certificar exhaustividad de todo tratamiento externo.

No se encontró una razón técnica objetiva para rechazar las siete selecciones examinadas. La decisión de guardar o publicar el cuestionario corresponde a su propietario, con esos límites presentes. Este informe no marca como resueltos el borrado en producción, la prueba Apple real, la firma, accesibilidad global o el envío a revisión.

## Estado comunicado por Store al cierre

- Clave SIWA de borrado ya creada y limitada a la app principal de Nido. Material privado validado y protegido localmente y en VPS; configuración separada de staging **sin activar**. No se debe crear o pedir de nuevo esa clave. No se han leído o copiado sus valores en esta revisión ni se guardan en Git.
- Capturas ordenadas **Hoy → Toma → Sueño → Historial → Cuidados compartidos**, persistentes tras recarga según Store. Supera el orden de recepción anterior.
- Firma de distribución/exportación aún bloqueada por cuenta/perfiles de Xcode. El borrador de privacidad sigue sin publicación acreditada en esta revisión.

No aplica TDD unitario a este informe: se valida mediante contraste de fuentes, segunda revisión y separación entre hallazgos, inferencias y límites. No se ha cambiado comportamiento ni estado externo.

## Actualización posterior a la revisión

Store comunica que el usuario confirmó expresamente la acción final y que el cuestionario de siete tipos ya figura **publicado** en ASC, con la URL legal correcta. La revisión anterior se conserva con su fecha, alcance y límites; la publicación fue una acción posterior del propietario, no del revisor. No implica publicación binaria, TestFlight o envío a revisión de la app, ni amplía la conclusión a cumplimiento general.
