// Edge Function: ai-plan
// Borrador de plan de entrenamiento para un cliente. El entrenador SIEMPRE lo revisa
// y edita antes de subirlo. Cada decisión lleva su origen:
//   "documento: <nombre>"  -> sale de una fuente que el entrenador aportó
//   "conocimiento general" -> criterio general de la IA, no es evidencia revisada
//
// Secretos: ANTHROPIC_API_KEY (obligatorio), ANTHROPIC_MODEL (opcional).
// Petición: POST { goal, level, daysPerWeek, weeks, limitations, equipment, sources: [{label, text}], startDate }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5";
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

const nullableNum = { type: ["number", "null"] };
const nullableStr = { type: ["string", "null"] };

const schema = {
  type: "object",
  properties: {
    summary: { type: "string", description: "Resumen del enfoque del plan en 3-5 líneas" },
    sessions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          week: { type: "number" },
          weekday: { type: "number", description: "1=lunes ... 7=domingo" },
          title: { type: "string" },
          phase: nullableStr,
          exercises: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                type: { type: "string", enum: ["hang", "repeater", "gym", "bloc", "cardio"] },
                cap: { type: "string", enum: ["prioritaria", "complementaria", "suplementaria", "otra"] },
                sets: nullableNum,
                reps: nullableNum,
                workS: nullableNum,
                restS: nullableNum,
                restRepS: nullableNum,
                grip: nullableStr,
                load: nullableStr,
                notes: nullableStr,
                origin: { type: "string", description: "'documento: <nombre>' o 'conocimiento general'" },
              },
              required: ["name", "type", "origin"],
            },
          },
        },
        required: ["week", "weekday", "title", "exercises"],
      },
    },
    cautions: {
      type: "array",
      items: { type: "string" },
      description: "Puntos que el entrenador debe validar (lesiones, cargas, progresiones)",
    },
  },
  required: ["summary", "sessions", "cautions"],
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
    if (!prof || prof.role !== "coach") return json({ error: "Solo un entrenador puede generar planes" }, 403);

    const b = await req.json();
    const sources = Array.isArray(b.sources) ? b.sources : [];
    const srcText = sources.length
      ? sources.map((s: { label: string; text: string }, i: number) => `### FUENTE ${i + 1}: ${s.label}\n${s.text}`).join("\n\n")
      : "(el entrenador no aportó fuentes)";

    const prompt = `Eres asistente de un entrenador de escalada. Diseña un BORRADOR de plan para este cliente.
Objetivo: ${b.goal ?? "sin especificar"}
Nivel: ${b.level ?? "sin especificar"}
Días por semana: ${b.daysPerWeek ?? 3}
Semanas: ${b.weeks ?? 4}
Limitaciones / lesiones: ${b.limitations ?? "ninguna indicada"}
Material disponible: ${b.equipment ?? "no indicado"}

REGLAS:
- Etiqueta CADA ejercicio con su origen: "documento: <nombre de la fuente>" solo si la decisión se apoya en una fuente de abajo; en caso contrario "conocimiento general".
- No inventes citas ni fuentes. Si no hay fuentes, todo es "conocimiento general".
- Progresión prudente y descarga en la última semana si hay 4 o más semanas.
- En 'cautions' lista lo que el entrenador debe validar. Eres un borrador, no una prescripción.

FUENTES:
${srcText}`;

    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": ANTHROPIC_KEY, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 16000,
        tools: [{ name: "save_draft", description: "Guarda el borrador del plan", input_schema: schema }],
        tool_choice: { type: "tool", name: "save_draft" },
        messages: [{ role: "user", content: prompt }],
      }),
    });
    const out = await r.json();
    if (!r.ok) return json({ error: "Error de la API de Anthropic", detail: out }, 502);
    const tool = (out.content ?? []).find((c: { type: string }) => c.type === "tool_use");
    if (!tool) return json({ error: "La IA no devolvió datos estructurados", detail: out }, 502);
    return json({ model: MODEL, data: tool.input, usage: out.usage });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
