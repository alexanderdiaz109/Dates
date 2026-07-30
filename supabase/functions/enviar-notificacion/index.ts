// Supabase Edge Function: enviar-notificacion
//
// Reemplaza el envío de push notifications que antes hacía el cliente Flutter
// directamente con la clave privada de la cuenta de servicio de Firebase Admin
// (lib/core/firebase_credentials.dart). Esa clave daba acceso de administrador
// al proyecto de Firebase y viajaba embebida dentro del APK — cualquiera podía
// extraerla descompilando la app. Aquí vive solo en el servidor, como secreto.
//
// Body esperado:
//   { "modo": "token", "token": "<fcm_token>", "titulo": "...", "cuerpo": "..." }
//   { "modo": "todos", "titulo": "...", "cuerpo": "..." }  (envía a toda la tabla `dispositivos`)
//   { "modo": "pareja", "usuarioId": "...", "titulo": "...", "cuerpo": "..." }
//
// Despliegue:
//   supabase functions deploy enviar-notificacion
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT='<contenido completo del JSON de la cuenta de servicio>'

import { GoogleAuth } from "npm:google-auth-library@9";
import { createClient } from "npm:@supabase/supabase-js@2";

const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface Payload {
  modo: "token" | "todos" | "pareja";
  token?: string;
  usuarioId?: string;
  titulo: string;
  cuerpo: string;
}

function construirPayloadFcm(token: string, titulo: string, cuerpo: string) {
  return {
    message: {
      token,
      notification: { title: titulo, body: cuerpo },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channel_id: "latidos",
          icon: "ic_notificacion",
          color: "#FF6A88",
        },
      },
    },
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Método no permitido" }), { status: 405 });
  }

  if (!FIREBASE_SERVICE_ACCOUNT) {
    return new Response(
      JSON.stringify({ error: "Falta el secreto FIREBASE_SERVICE_ACCOUNT en el proyecto de Supabase" }),
      { status: 500 },
    );
  }

  let body: Payload;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Body inválido, se esperaba JSON" }), { status: 400 });
  }

  const { modo, token, usuarioId, titulo, cuerpo } = body;
  if (!titulo || !cuerpo) {
    return new Response(JSON.stringify({ error: "Faltan 'titulo' y/o 'cuerpo'" }), { status: 400 });
  }
  if (modo === "token" && !token) {
    return new Response(JSON.stringify({ error: "modo 'token' requiere 'token'" }), { status: 400 });
  }
  if (modo === "pareja" && !usuarioId) {
    return new Response(JSON.stringify({ error: "modo 'pareja' requiere 'usuarioId'" }), { status: 400 });
  }

  try {
    const credentials = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    const auth = new GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    const client = await auth.getClient();
    const { token: accessToken } = await client.getAccessToken();
    const url = `https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`;

    const enviarA = async (destino: string) => {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: JSON.stringify(construirPayloadFcm(destino, titulo, cuerpo)),
      });
      if (!res.ok) {
        const errorBody = await res.text();
        console.error(`❌ FCM rechazó el envío a ${destino}:`, errorBody);
      }
      return res.ok;
    };

    let tokens: string[];
    if (modo === "token") {
      tokens = [token!];
    } else if (modo === "pareja") {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

      const { data: usuario, error: errUsuario } = await supabase
        .from("usuarios")
        .select("pareja_id")
        .eq("id", usuarioId)
        .maybeSingle();
      if (errUsuario || !usuario?.pareja_id) {
        throw new Error("Usuario sin pareja vinculada, no se puede resolver destinatario");
      }

      const { data, error } = await supabase
        .from("dispositivos")
        .select("fcm_token")
        .eq("pareja_id", usuario.pareja_id)
        .neq("usuario_id", usuarioId);
      if (error) throw error;
      tokens = (data ?? []).map((d: { fcm_token: string }) => d.fcm_token);
    } else {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      const { data, error } = await supabase.from("dispositivos").select("fcm_token");
      if (error) throw error;
      tokens = (data ?? []).map((d: { fcm_token: string }) => d.fcm_token);
    }

    const resultados = await Promise.all(tokens.map(enviarA));
    const enviados = resultados.filter(Boolean).length;

    return new Response(JSON.stringify({ enviados, total: tokens.length }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("Error enviando notificación:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
