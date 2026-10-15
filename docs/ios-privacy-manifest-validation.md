# Validación del manifiesto de privacidad de iOS

Fecha: 15 de octubre de 2026.

`ios/Nido/Nido/Resources/PrivacyInfo.xcprivacy` sustituye la categoría inválida
`NSPrivacyCollectedDataTypeHealthFitness` por `NSPrivacyCollectedDataTypeHealth`
y declara `NSPrivacyCollectedDataTypeUserID`. Ambas categorías están vinculadas
al usuario, no se utilizan para seguimiento y tienen la finalidad
`NSPrivacyCollectedDataTypePurposeAppFunctionality`.

La declaración de salud corresponde a los registros de temperatura, medicación
y síntomas del modelo de actividad. La declaración de identificadores corresponde
a la identidad y las sesiones que persiste la autenticación de Apple. Los valores
se contrastaron con las [categorías oficiales de Apple](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype).

Este cambio modifica metadatos; no aplica TDD unitario. Antes de editar se definió
como sustitución una validación del plist y de sus valores. Se comprobaron:

- `plutil -lint`: formato válido.
- Cuatro categorías únicas: Name, Health, OtherUserContent y UserID.
- Tipos booleanos, finalidad AppFunctionality y ausencia de seguimiento y dominios.
- Acceso a UserDefaults con motivo `CA92.1`, sin cambios.
- Diferencia limitada a la sustitución de categoría y la entrada UserID.

SHA-256 del manifiesto validado:
`c4a0aa91fcd5166c3b2ad63186b0ecc173ea9d15a17d9d618a93c57fb3707188`.

El archivo de dispositivo
`~/.codex/recoveries/nido-20261015/Nido-20261015-release-candidate.xcarchive`
terminó con `ARCHIVE SUCCEEDED`; su log es
`/tmp/nido-close-archive-candidate-20261015.log`. La aplicación arm64 incluida
declara versión 0.1.0, compilación 48. Su `Nido.app/PrivacyInfo.xcprivacy` es
semánticamente idéntico al manifiesto fuente y contiene las cuatro categorías
validadas, con seguimiento desactivado.

El archivo está sin firmar. Esta comprobación no acredita aceptación por App
Store Connect ni sustituye las declaraciones de privacidad de la ficha de la app.

El límite de rollback de esta unidad son el manifiesto y este documento. No cambia
el comportamiento de la aplicación ni modifica datos existentes.
