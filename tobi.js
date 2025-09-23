import OpenAI from "openai";
import 'dotenv/config';

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

export async function askTobi(prompt) {
  const response = await client.chat.completions.create({
    model: "gpt-5-mini",
    messages: [{ role: "user", content: prompt }]
  });

  return response.choices[0].message.content;
}

// Prueba rápida
(async () => {
  const r = await askTobi("Hola Tobi, dame un ejemplo de formulario Flutter para token 1 a 1");
  console.log(r);
})();
