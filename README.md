# WILDLINE — Field Test 01

Prototipo 3D de supervivencia en primera persona para navegador móvil, construido con Three.js.

## Qué incluye
- Escena 3D con costa, terreno, vegetación, rocas y puesto costero abandonado.
- Cámara en primera persona.
- Joystick táctil, control de cámara por arrastre y controles WASD/Shift en escritorio.
- Recolección de madera, piedra y fibra.
- Indicadores iniciales de salud, agua y energía.
- Cambio de calidad visual y luces/sombras.
- No necesita servidor backend.

## Publicar en GitHub Pages
1. Crea un repositorio llamado `wildline`.
2. Sube `index.html` y este `README.md` a la raíz de la rama `main`.
3. En GitHub abre **Settings → Pages**.
4. En **Build and deployment**, selecciona **Deploy from a branch**.
5. Elige `main` y la carpeta `/(root)`, y pulsa **Save**.
6. Espera a que GitHub Pages publique el sitio y abre la URL desde tu celular.

Three.js se carga desde jsDelivr, por lo que la primera carga requiere conexión a internet.

## Controles
### Móvil
- Joystick inferior izquierdo: movimiento.
- Arrastrar la vista: mirar.
- **＋ Usar**: recoger recursos próximos.
- **Correr**: mantener pulsado para correr.
- **Herram.**: alterna el indicador de herramienta.

### Escritorio
- `WASD` o flechas: movimiento.
- `Shift`: correr.
- Arrastrar con el ratón: mirar.
- `Espacio`: interactuar/recoger.

## Estado del prototipo
Esta es una primera base jugable, no una versión final: el terreno, la vegetación y las mecánicas usan geometría procedural sencilla. El siguiente paso recomendado es probar el rendimiento en el dispositivo objetivo, ajustar controles y después incorporar modelos/texturas PBR optimizados, guardado local, inventario real y criaturas con IA.
