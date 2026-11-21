// Edge Function: ai-import
// Lee un PDF o imagen guardado en Storage y devuelve datos estructurados (JSON)
// con un esquema estricto. La clave de Anthropic vive SOLO aquí (secreto).
//
// Secretos necesarios (Supabase > Edge Functions > Secrets):
//   ANTHROPIC_API_KEY   (obligatorio)
//   ANTHROPIC_MODEL     (opcional, por defecto claude-sonnet-5-5)
//
// Petición: POST { path: "<uid>/imports/xxx.pdf", kind: "plan"|"study"|"label"|"competitions"|"bodycomp"|"labs" }
// con la cabecera Authorization: Bearer <token del usuario>.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5";
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

const nullableNum = { type: ["number", "null"] };
const nullableStr = { type: ["string", "null"] };

const exercise = {
  type: "object",
  properties: {
    name: { type: "string" },
    type: { type: ["string", "null"], enum: ["hang", "repeater", "gym", "bloc", "cardio", null] },
    cap: { type: ["string", "null"], enum: ["prioritaria", "complementaria", "suplementaria", "otra", null] },
    sets: nullableNum,
    reps: nullableNum,
    workS: nullableNum,
    restS: nullableNum,
    restRepS: nullableNum,
    grip: nullableStr,
    load: nullableStr,
    notes: nullableStr,
  },
  required: ["name"],
};

const SCHEMAS: Record<string, { name: string; description: string; schema: unknown; prompt: string }> = {
  plan: {
    name: "save_plan",
    description: "Guarda el plan de entrenamiento extraído del documento.",
    schema: {
      type: "object",
      properties: {
        title: nullableStr,
        sessions: {
          type: "array",
          items: {
            type: "object",
            properties: {
              date: { type: ["string", "null"], description: "YYYY-MM-DD solo si aparece explícita" },
              week: nullableNum,
              weekday: nullableStr,
              time: nullableStr,
              title: { type: "string" },
              phase: nullableStr,
              exercises: { type: "array", items: exercise },
            },
            required: ["title", "exercises"],
          },
        },
        uncertain: {
          type: "array",
          items: { type: "string" },
          description: "Lista de datos dudosos o ausentes que el usuario debe revisar",
        },
      },
      required: ["sessions"],
    },
    prompt:
      "Extrae el plan de entrenamiento de escalada de este documento. NO inventes nada: si un dato no aparece o es ambiguo, déjalo en null y añade una nota a 'uncertain'. Tipos de ejercicio: hang (suspensión), repeater (repeaters), gym (fuerza general), bloc (bloque/proyectos), cardio (resistencia/ARC/movilidad). Carga en 'load' tal cual aparece (kg, % del máximo, % del pico, RPE). Tiempos en segundos.",
  },
  study: {
    name: "save_study",
    description: "Guarda los valores y criterios clave de un estudio biomecánico o de rendimiento.",
    schema: {
      type: "object",
      properties: {
        values: {
          type: "array",
          items: {
            type: "object",
            properties: {
              key: { type: "string", description: "identificador corto, p. ej. peak_half_left" },
              label: { type: "string" },
              value: nullableNum,
              text: nullableStr,
              unit: nullableStr,
              page: nullableNum,
              quote: { type: ["string", "null"], description: "cita literal breve del documento" },
            },
            required: ["key", "label"],
          },
        },
        references: {
          type: "array",
          description: "Valores de referencia por nivel (intermedio, avanzado, élite) por test",
          items: {
            type: "object",
            properties: {
              test: { type: "string" },
              level: { type: "string" },
              value: nullableNum,
              unit: nullableStr,
              page: nullableNum,
            },
            required: ["test", "level"],
          },
        },
        recovery_rules: {
          type: "array",
          description: "Criterios de recuperación o carga con su origen en el documento",
          items: {
            type: "object",
            properties: { text: { type: "string" }, page: nullableNum, quote: nullableStr },
            required: ["text"],
          },
        },
        nutrition: {
          type: "array",
          items: {
            type: "object",
            properties: { text: { type: "string" }, page: nullableNum },
            required: ["text"],
          },
        },
        summary: { type: "string" },
      },
      required: ["values", "summary"],
    },
    prompt:
      "Extrae del documento los valores medidos, los valores de referencia por nivel, los criterios de recuperación y los de nutrición. Cita la página. No inventes ni extrapoles: solo lo que aparece en el documento.",
  },
  label: {
    name: "save_food",
    description: "Guarda la etiqueta nutricional de un producto (por 100 g).",
    schema: {
      type: "object",
      properties: {
        name: nullableStr,
        kcal: nullableNum,
        protein: nullableNum,
        carbs: nullableNum,
        sugars: nullableNum,
        fat: nullableNum,
        saturated: nullableNum,
        fiber: nullableNum,
        salt: nullableNum,
        uncertain: { type: "array", items: { type: "string" } },
      },
    },
    prompt:
      "Lee la tabla nutricional del producto y devuelve los valores POR 100 g (o por 100 ml). Si solo aparece por ración, déjalo en null y anótalo en 'uncertain'. No inventes valores.",
  },
  competitions: {
    name: "save_competitions",
    description: "Guarda el calendario de competiciones.",
    schema: {
      type: "object",
      properties: {
        items: {
          type: "array",
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              date: nullableStr,
              place: nullableStr,
              circuit: nullableStr,
              type: { type: ["string", "null"], enum: ["bloque", "cuerda", null] },
            },
            required: ["name"],
          },
        },
        uncertain: { type: "array", items: { type: "string" } },
      },
      required: ["items"],
    },
    prompt: "Extrae las competiciones del calendario. Fechas en YYYY-MM-DD solo si el año está claro; si no, null y anótalo en 'uncertain'.",
  },
  bodycomp: {
    name: "save_bodycomp",
    description: "Guarda una medición de composición corporal (bioimpedancia).",
    schema: {
      type: "object",
      properties: {
        date: nullableStr,
        weightKg: nullableNum,
        fatPct: nullableNum,
        muscleKg: nullableNum,
        waterPct: nullableNum,
        bmrKcal: nullableNum,
        boneKg: nullableNum,
        visceral: nullableNum,
        uncertain: { type: "array", items: { type: "string" } },
      },
    },
    prompt: "Extrae los valores de la bioimpedancia. No inventes: null si no aparece.",
  },
  labs: {
    name: "save_labs",
    description: "Guarda los valores de una analítica de sangre.",
    schema: {
      type: "object",
      properties: {
        date: nullableStr,
        items: {
          type: "array",
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              value: nullableNum,
              unit: nullableStr,
              refMin: nullableNum,
              refMax: nullableNum,
              flag: nullableStr,
            },
            required: ["name"],
          },
        },
      },
      required: ["items"],
    },
    prompt: "Extrae cada parámetro de la analítica con su valor, unidad y rango de referencia. No interpretes ni diagnostiques; solo transcribe.",
  },
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);
    if (!ANTHROPIC_KEY) return json({ error: "Falta el secreto ANTHROPIC_API_KEY en Supabase" }, 500);

    const auth = req.headers.get("Authorization") ?? "";
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const { data: u, error: ue } = await sb.auth.getUser();
    if (ue || !u?.user) return json({ error: "No autenticado" }, 401);
    const { data: prof } = await sb.from("profiles").select("role").eq("uid", u.user.id).maybeSingle();
    if (!prof || prof.role === "client") return json({ error: "Los clientes no pueden usar la IA" }, 403);

    const { path, kind } = await req.json();
    const spec = SCHEMAS[kind as string];
    if (!spec || typeof path !== "string") return json({ error: "Petición no válida" }, 400);

    const { data: file, error: fe } = await sb.storage.from("docs").download(path);
    if (fe || !file) return json({ error: "No se pudo leer el archivo: " + (fe?.message ?? "") }, 400);
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length > 24 * 1024 * 1024) return json({ error: "Archivo demasiado grande (máx. 24 MB)" }, 413);
    const b64 = encodeBase64(bytes);

    const lower = path.toLowerCase();
    const isPdf = lower.endsWith(".pdf");
    const mime = lower.endsWith(".png") ? "image/png" : lower.endsWith(".webp") ? "image/webp" : "image/jpeg";
    const block = isPdf
      ? { type: "document", source: { type: "base64", media_type: "application/pdf", data: b64 } }
      : { type: "image", source: { type: "base64", media_type: mime, data: b64 } };

    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 16000,
        tools: [{ name: spec.name, description: spec.description, input_schema: spec.schema }],
        tool_choice: { type: "tool", name: spec.name },
        messages: [{ role: "user", content: [block, { type: "text", text: spec.prompt }] }],
      }),
    });
    const out = await r.json();
    if (!r.ok) return json({ error: "Error de la API de Anthropic", detail: out }, 502);
    const tool = (out.content ?? []).find((c: { type: string }) => c.type === "tool_use");
    if (!tool) return json({ error: "La IA no devolvió datos estructurados", detail: out }, 502);
    return json({ kind, model: MODEL, data: tool.input, usage: out.usage });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
