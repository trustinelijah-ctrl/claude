// Mirrors HumanFood/Services/AIPrompts.swift — keep the two in sync.

export function verdictSystem(locale: string): string {
  return `You are the writing voice of Human Food, a calm, premium food-scanner app. You explain a product's score in plain, warm, confident language.

Philosophy: whole-food, plant-predominant eating as described by T. Colin Campbell (The China Study; Whole), Michael Pollan ("Eat food. Not too much. Mostly plants."), Michael Greger (How Not to Die) and the NOVA food-processing classification. Favour whole plants, legumes, whole grains, fruit, vegetables, nuts and seeds; keep ultra-processed foods, added sugar, salt, refined oils, processed meat and other animal foods limited.

Hard rules:
1. Never mention any brand, manufacturer, retailer or trademarked product name, including the scanned one. Say "this product".
2. Never state or imply that the product is toxic, poisonous, dangerous, unsafe, harmful, junk or fake, or that it causes any disease. Use measured phrases such as "worth limiting", "research suggests", "is associated with", "best enjoyed occasionally".
3. Present everything as Human Food's opinion based only on the data provided. Do not invent numbers, ingredients or facts. If data is missing, say so briefly.
4. No medical advice, diagnoses, or claims to treat or prevent disease.
5. The score is final. Never change or contradict it; match your tone to it.
6. Alternatives are generic food types (e.g. "Plain rolled oats with berries"), never brands, that fit the same occasion and would score higher under this philosophy.

Style: headline at most 60 characters, no exclamation marks, no emoji. Summary of 2–3 sentences. Up to 3 highlights and 3 considerations, each at most 90 characters. 2–3 alternatives. One practical tip of at most 120 characters. Write in the language for locale "${locale}".`;
}

export const labelSystem =
  `You transcribe food packaging photos into structured data for a nutrition app. Only report what is visible. Convert nutrition values to per 100 g (or per 100 ml for drinks) when the label gives a serving size; otherwise use null. Additives are lowercase E-numbers like "e330" (map named additives to their E-number when certain). Categories and allergens use Open Food Facts style tags such as "en:breakfast-cereals" and "en:milk". novaGroup is your best estimate of the NOVA processing group (1-4).`;

export const verdictSchema = {
  type: "OBJECT",
  properties: {
    headline: { type: "STRING" },
    summary: { type: "STRING" },
    highlights: { type: "ARRAY", items: { type: "STRING" } },
    considerations: { type: "ARRAY", items: { type: "STRING" } },
    alternatives: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: { title: { type: "STRING" }, reason: { type: "STRING" } },
        required: ["title", "reason"],
      },
    },
    tip: { type: "STRING" },
  },
  required: ["headline", "summary", "highlights", "considerations", "alternatives", "tip"],
};

const num = { type: "NUMBER", nullable: true };
const strings = { type: "ARRAY", items: { type: "STRING" } };

export const labelSchema = {
  type: "OBJECT",
  properties: {
    name: { type: "STRING" },
    brand: { type: "STRING", nullable: true },
    quantity: { type: "STRING", nullable: true },
    ingredientsText: { type: "STRING", nullable: true },
    ingredients: strings,
    nutrients: {
      type: "OBJECT",
      properties: {
        energyKcal: num, fat: num, saturatedFat: num, transFat: num, carbohydrates: num,
        sugars: num, addedSugars: num, fiber: num, protein: num, salt: num,
      },
    },
    novaGroup: { type: "INTEGER", nullable: true },
    additives: strings,
    categories: strings,
    allergens: strings,
    isBeverage: { type: "BOOLEAN" },
  },
  required: ["name", "ingredients", "nutrients", "additives", "categories", "allergens", "isBeverage"],
};

// Safe-language filter — mirrors HumanFood/Services/SafeLanguage.swift.
const replacements: Array<[RegExp, string]> = [
  [/\bnon-toxic\b/gi, "gentle"],
  [/\btoxins?\b/gi, "compounds of concern"],
  [/\btoxic\b/gi, "of concern"],
  [/\bpoisonous\b/gi, "of concern"],
  [/\bpoisons?\b/gi, "concerning ingredient"],
  [/\bdangerous\b/gi, "worth limiting"],
  [/\bharmful\b/gi, "less favourable"],
  [/\bunhealthy\b/gi, "less favourable"],
  [/\bunsafe\b/gi, "worth limiting"],
  [/\bjunk food\b/gi, "highly processed food"],
  [/\bjunk\b/gi, "highly processed"],
  [/\bcauses? cancer\b/gi, "has been studied in relation to cancer risk"],
  [/\bcancer-causing\b/gi, "studied in relation to cancer risk"],
  [/\bcarcinogenic\b/gi, "classified by some agencies as a possible risk"],
  [/\bfake food\b/gi, "highly processed food"],
  [/\bchemicals\b/gi, "additives"],
  [/\bdeadly\b/gi, "concerning"],
  [/\bkills?\b/gi, "may affect"],
  [/\bavoid at all costs\b/gi, "best kept rare"],
  [/\bnever eat\b/gi, "consider limiting"],
  [/\bterrible\b/gi, "less favourable"],
  [/\bdisgusting\b/gi, "less appealing"],
  [/\bgarbage\b/gi, "highly processed"],
];

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function clean(text: string, brand?: string | null): string {
  let out = text;
  for (const [pattern, replacement] of replacements) out = out.replace(pattern, replacement);
  for (const name of (brand ?? "").split(",").map((s) => s.trim()).filter((s) => s.length >= 3)) {
    out = out.replace(new RegExp(escapeRegExp(name), "gi"), "this product");
  }
  return out;
}
