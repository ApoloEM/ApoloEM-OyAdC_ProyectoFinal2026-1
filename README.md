# 🎱 Billar 8-Ball — Proyecto Final OyAdC 2026-1

Juego de billar 8-ball donde **toda la lógica y la física viven en ensamblador MASM x86**
(compilado como una DLL) y la **interfaz gráfica está en C# / WPF**. Incluye una
presentación animada del proyecto.

> Universidad Autónoma de Baja California · Facultad de Ingeniería Mexicali
> Organización y Arquitectura de Computadoras

---

## 📂 Qué hay en el proyecto

| Carpeta / archivo | Qué es |
|---|---|
| `Billar8Ball.slnx` | La solución de Visual Studio. **Empieza aquí.** |
| `BillarGUI/` | Interfaz del juego en C# / WPF (lo que se ve y se toca). |
| `BillarLogica/` | Motor en ensamblador MASM (`.asm`) → genera `BillarLogica.dll`. |
| `presentacion-react/` | Código fuente de la presentación animada. |
| `Billar8Ball-Presentacion.html` | **Presentación animada lista para ver (doble clic).** |
| `Billar8Ball-Presentacion.pdf` | La misma presentación como PDF (respaldo estático). |

> 📝 **Dos versiones del código:** los archivos con el nombre normal (p. ej.
> `BillarLogica.asm`, `MainWindow.xaml.cs`) son los que **compilan y se ejecutan**, sin
> comentarios. Las copias `*_comentada.*` (p. ej. `BillarLogica_comentada.asm`) son
> idénticas pero **con comentarios**, solo como referencia — no entran a la compilación.

---

## ✅ Paso 1 — Requisitos (instalar una sola vez)

1. **Windows 10 u 11.**
2. **Visual Studio 2022** (la edición *Community* es gratuita):
   <https://visualstudio.microsoft.com/es/downloads/>
3. Al instalar Visual Studio (o luego en **Visual Studio Installer → Modificar**),
   marca estas **dos cargas de trabajo** y dale *Instalar*:
   - ☑️ **Desarrollo para el escritorio con C++**  ← trae el ensamblador MASM (`ml.exe`)
   - ☑️ **Desarrollo de escritorio de .NET**  ← trae C#, WPF y .NET 9

> Sin la carga de **C++** el ensamblador no compila; sin la de **.NET** no abre la interfaz.
> Las dos son obligatorias.

---

## ⬇️ Paso 2 — Descargar el proyecto

**Opción A — sin git (la más fácil):**
1. En la página de GitHub, botón verde **`Code`** → **`Download ZIP`**.
2. Descomprime el ZIP en una carpeta (por ejemplo, el Escritorio).

**Opción B — con git:**
```bash
git clone https://github.com/ApoloEM/OyAdC_ProyectoFinal2026-1.git
```

---

## ▶️ Paso 3 — Abrir y ejecutar el JUEGO

1. Doble clic en **`Billar8Ball.slnx`** (se abre Visual Studio).
2. En la barra de arriba, en el desplegable de **plataforma** elige **`x86`**
   (debe quedar **`Debug | x86`**). *Esto es importante: la DLL es de 32 bits.*
3. Si en el panel **Explorador de soluciones** el proyecto **`BillarGUI`** no aparece en
   **negritas**, haz clic derecho sobre él → **“Establecer como proyecto de inicio”**.
4. Presiona **`F5`** (o el botón verde **▶ Iniciar**).
   Visual Studio compila el ensamblador, genera `BillarLogica.dll`, la copia junto al
   `.exe` y abre el juego automáticamente.

### 🎮 Cómo jugar
- **Apuntar y tirar:** haz clic sostenido cerca de la bola blanca, **arrastra** para elegir
  dirección y fuerza (la barra de potencia sube), y **suelta** para tirar.
- Tras una falta te toca **bola en mano**: haz clic en un lugar válido del paño para
  recolocar la blanca.

### 🛠️ Si algo falla
| Mensaje / problema | Solución |
|---|---|
| `No se encontró BillarLogica.dll` | Menú **Compilar → Recompilar solución**, asegúrate de estar en **x86** y ejecuta de nuevo. |
| Error de MASM / `ml.exe` no reconocido | Falta la carga **Desarrollo para el escritorio con C++**. Instálala desde *Visual Studio Installer*. |
| Error de **.NET 9** / falta el SDK | Actualiza Visual Studio o instala el **SDK de .NET 9**: <https://dotnet.microsoft.com/download/dotnet/9.0> |
| Abre pero no aparecen las bolas | Confirma que la plataforma sea **x86** y vuelve a **Recompilar solución**. |
| No abre el archivo `Billar8Ball.slnx` | Actualiza Visual Studio 2022 a la **última versión** (el formato `.slnx` requiere una versión reciente). |

---

## 🖥️ Paso 4 — Ver la PRESENTACIÓN (animada, sin comandos)

Haz **doble clic** en **`Billar8Ball-Presentacion.html`**.
Se abre en tu navegador (Chrome, Edge, etc.) con todas las animaciones.

- Avanza / retrocede con las **flechas ← →** del teclado (o los botones de abajo a la derecha).
- Solo necesita **internet para las tipografías**; sin conexión se ve con fuentes del
  sistema, pero funciona igual.
- Si prefieres algo estático, abre **`Billar8Ball-Presentacion.pdf`**.

> Nota: el botón *“Lanzar Billar8Ball.exe”* de la última diapositiva solo funciona en modo
> desarrollo (`npm run dev`). Para jugar, usa Visual Studio como en el **Paso 3**.

---

## 👥 Autores
**Erick Moya · Alexandra Martínez** — Ingeniería en Computación, UABC Mexicali.
