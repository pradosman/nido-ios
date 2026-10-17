# Una pantalla: Hoy con Leo

## Encargo y límite

Primera impresión de Nido: iOS, cercana, precisa y propia. Solo se presenta Hoy. Estudio visual estático con datos ficticios, previo a implementar interacciones o modificar la app enviada a revisión. No se aprueba ninguna pantalla posterior por extensión.

## Referencias vistas, no supuestas

- [Fitness · Resumen](https://mobbin.com/screens/2745a5a7-c443-46cf-80bb-a3e7b72ff8f7): cabecera clara, perfil a la derecha; primera tarjeta con gráfico a la izquierda y valor a la derecha; módulos secundarios iguales, cifras grandes y títulos breves; navegación flotante con etiquetas.
- [Fitness · Resumen vacío](https://mobbin.com/screens/5b8d5290-6c52-436f-bac3-9d0a531db829): mantiene la estructura aunque no haya actividad. No llenar huecos con datos inventados.
- [Fitness · Resumen personalizable](https://mobbin.com/screens/a69eb6f0-44e3-4b5c-95e6-43a34561d837): el bloque introductorio desplaza los datos; se descarta para esta pantalla cotidiana.

Se vieron también widgets, que no son una referencia válida para trasladar directamente a esta pantalla. Se guardan solo las tres pantallas completas anteriores en `references/`.

Identidad contrastada con `ios/Nido/Nido/Design/NidoTheme.swift`, `ios/Nido/Nido/Features/Today/TodayView.swift` y la captura original `docs/design-audit-2026-10-16/evidence/today-light.png`: papel claro, musgo, título serif, colores de cuidado, reloj de 24 horas y autor del cuidado. La demo original ocupa demasiado con el reloj; conservar su significado no exige conservar su tamaño.

## Decisiones antes de dibujar

Tesis: saber qué ocurre ahora y cómo ha transcurrido el día de Leo, sin interpretar objetivos ni puntuaciones. La firma es el reloj temporal de Nido, acompañado por cifras legibles.

Paleta clara: fondo #F6F4EE, tarjeta #FFFEFA, texto #263A31, secundario #62695F, acción musgo #526E5E; señales sueño #526E82, toma #936021 y pañal #356E78. Cada señal tiene texto e icono. El fondo de sueño #E9EFF2 sirve solo para el estado activo; no representa valoración médica. Esta primera propuesta está acotada a apariencia clara; el modo oscuro no se da por resuelto.

Tipografía: serif de sistema para «Hoy con Leo», 34 px; SF para cuerpo y controles, 17 px; cifras 26–32 px, peso medio, números tabulares; contexto 12–14 px, etiquetas de navegación 11 px. No titulares publicitarios, textura decorativa ni fotografía.

Composición: estado activo compacto; una tarjeta principal que divide el espacio entre reloj temporal y totales; dos tarjetas iguales que responden cuándo y qué ocurrió por última vez. Una zona inferior reservada mantiene navegación y registro fuera de los datos.

```text
390 px                         320 px
Hoy con Leo        perfil      Hoy con Leo     perfil
fecha                          fecha
[sueño activo     Terminar]     [estado      Terminar]
[reloj24h | sueño/toma/pañal]    [reloj | totales]
[última toma][último pañal]     [toma]       [pañal]
        espacio de seguridad / desplazamiento
[Hoy Historia Ritmos Ajustes] + [Registrar]
```

Con texto ampliado se apilan reloj y totales, así como las tarjetas secundarias. Se permite desplazamiento; no se reduce la letra para mantener todo dentro de una captura. El gráfico conserva sus horas, no se convierte en un anillo de cumplimiento. No hay animación en este estudio.

## Crítica previa

Se elimina el segundo logotipo del centro del reloj: el perfil ya lleva la marca. Se descarta trasladar los anillos de objetivos de Fitness: un bebé no debe «cerrar» metas. Se comprime el sueño activo a un estado útil de aproximadamente 104 px para que no compita con todo el resumen. Se mantiene Ajustes porque pertenece a la navegación actual de Nido; reducir pestañas por copiar una captura sería una decisión sin justificar.

## Antes / después / por qué

| Antes | Esta pantalla | Motivo |
|---|---|---|
| Paisaje, transparencia y frase emocional ocupan la portada. | Datos de Leo sobre superficies claras, con su estado activo al principio. | El contenido cotidiano y la persona recuperan el protagonismo. |
| Reloj enorme en la app original; pequeño y secundario en los intentos posteriores. | Reloj de 24 horas de 156 px junto a cifras y categorías. | Conserva una firma útil y permite entenderla sin depender solo del dibujo. |
| Registro y navegación compiten en tamaño o color. | Cuatro destinos estables y un «+» separado, con espacio inferior propio. | Navegar y registrar siguen siendo acciones distintas. |
| Frases genéricas intentan aportar cercanía. | «Leo», horas concretas y «Marcos» en cada cuidado. | Cercanía basada en la familia y en lo que realmente ha sucedido. |

## Puerta de calidad

Revisión del principal + revisión independiente con capturas locales: legibilidad, jerarquía, significado del reloj, proporciones, espacios, semántica de navegación, 320 px y texto ampliado. El visto bueno es una revisión de diseño del estudio, no una aprobación de Apple ni de una implementación nativa. Registrar y Terminar son representaciones de controles; sus flujos se diseñarán solo tras revisar esta pantalla.
