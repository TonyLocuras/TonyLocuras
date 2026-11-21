# Montar el backend (Supabase), paso a paso

Tiempo: unos 15 minutos. Coste: 0 € en el plan gratuito (la IA sí se paga por uso con tu clave de Anthropic).

## 1. Crear el proyecto
1. Entra en **supabase.com**, crea cuenta (con GitHub o correo) y pulsa **New project**.
2. Nombre: `tonylocuras`. Contraseña de base de datos: genera una y guárdala. Región: **Frankfurt** o la más cercana a España.
3. Espera a que termine (1-2 min).

## 2. Desactivar la confirmación de correo
**Authentication > Providers > Email**: desactiva **«Confirm email»** y guarda. Si no, los registros se quedan esperando un correo.

## 3. Crear tablas y permisos
1. **SQL Editor > New query**.
2. Pega **todo** el contenido de `supabase/schema.sql` y pulsa **Run**. Debe decir «Success».

## 4. Clave de Anthropic (secreto)
**Edge Functions > Secrets** (o **Project Settings > Edge Functions**) → añade:
- `ANTHROPIC_API_KEY` = tu clave de la consola de Anthropic.
- (opcional) `ANTHROPIC_MODEL` = `claude-sonnet-5-5`.

La clave solo vive aquí. Ni la app ni el repositorio la contienen.

## 5. Crear las dos funciones de IA
Para cada una: **Edge Functions > Deploy a new function > Via Editor**.
- Nombre `ai-import` → pega `supabase/functions/ai-import/index.ts` → **Deploy**.
- Nombre `ai-plan` → pega `supabase/functions/ai-plan/index.ts` → **Deploy**.

## 6. Pásame dos datos
En **Project Settings > API**:
- **Project URL** (`https://xxxx.supabase.co`).
- **anon public key** (empieza por `eyJ...`). Es pública por diseño. **No me pases la `service_role`.**

Con eso compilo los dos APK ya conectados.

## 7. Control de gasto (recomendado)
En la consola de Anthropic, fija un **límite mensual de gasto** (por ejemplo 10 €).

## Qué queda guardado y dónde
- Tablas: `profiles`, `records`, `coach_links`, `invites` con **permisos por usuario** (un cliente solo ve lo suyo; el entrenador solo ve a sus clientes vinculados).
- Documentos (PDF, fotos): bucket privado `docs`.
- Un cliente puede **desvincularse** de su entrenador y **borrar todos sus datos** desde la app.
