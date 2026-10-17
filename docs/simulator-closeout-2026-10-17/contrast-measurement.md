# Contraste de «Ver todo»: medición sobre capturas nativas

La auditoría nativa `.all` de `/tmp/nido-accessibility-final-2026-10-17.xcresult` sigue señalando contraste en el botón «Ver todo» después de reforzar su foreground. No se declara aprobada esa auditoría. Se inspeccionaron las capturas del elemento y de la pantalla completa para comprobar el resultado realmente renderizado.

Se decodificaron los PNG nativos con ImageIO y se dibujaron en un `CGContext` RGBA de 8 bits con espacio sRGB, respetando la conversión del perfil incrustado. Se contó el color más frecuente de los píxeles interiores de los glifos y se comparó su luminancia relativa con las cuatro esquinas del recorte del control. Para cada componente sRGB normalizado se aplicó `c/12.92` si `c <= 0.04045`, o `((c+0.055)/1.055)^2.4`; luminancia `0.2126R + 0.7152G + 0.0722B`, razón `(Lmayor+0.05)/(Lmenor+0.05)`.

| Apariencia | Glifo sRGB | Fondos de las cuatro esquinas | Menor razón calculada | Píxeles del glifo |
| --- | --- | --- | ---: | ---: |
| Oscura | `#FFFFFF` | `#151716`, `#141515`, `#141514`, `#131514` | 18.01:1 | 1537 |
| Clara | `#21392D` | `#F6F7F5`, `#F6F6F4`, `#F5F5F3`, `#F5F6F4` | 11.40:1 | 1637 |

Recortes originales: `contrast-dark-element.png` y `contrast-light-element.png`. Pantallas completas: `contrast-dark-screen.png` y `contrast-light-screen.png`, junto a este informe. No se retocaron los PNG.

El resultado acredita contraste alto de los glifos y los fondos muestreados en estas dos capturas. No certifica todos los píxeles, todos los estados ni toda la app. El texto completo del hallazgo de Xcode no proporciona colores ni una razón medida, por lo que no queda demostrada la causa de la discrepancia. Se alinearon foreground y tint locales del botón; la auditoría nativa siguió fallando en ambos temas (`/tmp/nido-accessibility-tint-recheck-2026-10-17.xcresult`, dos pruebas, dos fallos). No se añadió un fondo decorativo ni se ignoró el hallazgo para obtener una prueba verde.

Es análisis de un renderizado: no aplica TDD unitario. Lo sustituyen la captura nativa conservada, la conversión de color y el cálculo reproducible descritos.
