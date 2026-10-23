# Guion del vídeo del TFM

Duración orientativa: 8–10 minutos. El vídeo debe grabar la pantalla durante toda la explicación; la cámara es opcional.

## Preparación

- Mac con Xcode y el simulador de iPhone abierto con Nido instalado (esquema **Nido**, botón **Run**).
- Pestañas abiertas: [repositorio](https://github.com/pradosman/nido-ios), [estado de la API](https://nido.momentumia.com/api/nido/status) y la [presentación](presentacion-nido.pdf).
- Notificaciones del Mac desactivadas y ninguna información personal visible en pantalla.

## Escenas

| Tiempo | Pantalla | Qué contar |
|---|---|---|
| 0:00–0:45 | Diapositivas 1–2 | Quién eres, qué es Nido y el problema de registrar el cuidado del bebé entre varias personas. |
| 0:45–1:30 | Diapositivas 3–4 | Qué resuelve la app y sus funcionalidades principales. |
| 1:30–5:00 | Simulador | Demo en vivo (ver recorrido abajo). |
| 5:00–6:30 | Diapositivas 5–6 y repositorio | Arquitectura, stack y estructura de carpetas (`ios/Nido`, `app/api`, `db`, `tests`, `deploy`, `docs`). |
| 6:30–7:45 | Diapositiva 7 y código | TDD: abre `AGENTS.md`, una prueba de `ios/Nido/Tests` y un contrato de `tests/`. Muestra `npm test` o la pestaña de pruebas de Xcode. |
| 7:45–8:45 | Diapositivas 8–9 y navegador | Privacidad, despliegue en Dokploy y respuesta de `/api/nido/status`. Estado de publicación en App Store. |
| 8:45–9:30 | Diapositivas 10–11 | Aprendizajes, próximos pasos y enlaces. |

## Recorrido de la demo

1. En la pantalla de acceso, explica que el acceso real es con **Iniciar sesión con Apple** y pulsa **Explorar demostración**.
2. **Hoy**: anillos de objetivos de sueño, tomas y pañales; actividad del día.
3. Botón **+**: registra una toma y un pañal; enseña cómo se actualizan los anillos.
4. **Iniciar sueño**: muestra el sueño en curso y finalízalo.
5. **Historia**: cambia de día en la semana, abre el calendario y edita un registro.
6. **Ritmos / Evolución**: gráficas y métricas fijadas.
7. **Crecimiento**: últimas medidas de peso y talla.
8. **Ajustes**: hogar compartido, invitación de cuidador (ficticia en la demo) e informe para el pediatra.
9. Pulsa **Reiniciar** para restaurar los datos de ejemplo y **Salir** para volver al acceso.

## Publicación

Sube el vídeo a YouTube como **No listado** (o a Drive con acceso «Cualquier persona con el enlace»), comprueba el enlace en una ventana privada y añádelo en la sección **Vídeo** del [README](../../README.md).
