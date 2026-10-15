type LegalPageKind = "privacy" | "support";

function escapeHTML(value: string): string {
  return value.replace(/[&<>"']/g, character => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[character]!);
}

function configuredContact() {
  const controller = (process.env.NIDO_PRIVACY_CONTROLLER ?? "David Prados Mancilla").trim();
  const email = (process.env.NIDO_SUPPORT_EMAIL ?? "pradosman@gmail.com").trim();
  const emailPattern = /^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$/i;
  const hasControlCharacter = controller && [...controller].some(character => {
    const code = character.charCodeAt(0);
    return code < 32 || (code >= 127 && code <= 159);
  });
  if (!controller || controller.length > 160 || hasControlCharacter) return null;
  if (/(?:\b(?:placeholder|example|your\s+(?:name|company)|tu\s+(?:nombre|empresa)|nombre\s+(?:de\s+(?:la\s+)?empresa|del\s+responsable)|pendiente|tbd|change\s+me)\b|nido\s*<\s*equipo\s*>)/i.test(controller)) return null;
  if (!email || email.length > 254 || !emailPattern.test(email)) return null;
  const domain = email.slice(email.lastIndexOf("@") + 1).toLowerCase();
  if (/(?:^|\.)(?:example|test|invalid|localhost)(?:\.|$)/.test(domain)) return null;
  return { controller, email };
}

function pageDocument(title: string, content: string): string {
  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHTML(title)} · Nido</title>
  <style>body{font:16px/1.6 system-ui,sans-serif;max-width:46rem;margin:3rem auto;padding:0 1.25rem;color:#252521}h1,h2{line-height:1.2}a{color:#245d52}</style>
</head>
<body>
${content}
</body>
</html>`;
}

function unavailable(): Response {
  return new Response("<!doctype html><html lang=\"es\"><meta charset=\"utf-8\"><title>Información no disponible · Nido</title><body><h1>Información no disponible</h1><p>Esta página no está configurada todavía. Inténtalo más tarde.</p></body></html>", {
    status: 503,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" },
  });
}

function privacyPage(controller: string, email: string): Response {
  const safeController = escapeHTML(controller);
  const safeEmail = escapeHTML(email);
  const encodedEmail = encodeURIComponent(email).replaceAll("%40", "@");
  const content = `<main>
  <h1>Política de privacidad de Nido</h1>
  <p>Esta página explica qué información se usa en Nido para registrar y compartir cuidados familiares.</p>
  <h2>Información que introduces</h2>
  <p>Nido guarda los nombres de las personas cuidadoras y del bebé, su fecha de nacimiento y las actividades que registras, incluidas notas de salud. También se usan identificadores de cuenta y de sesión para iniciar sesión y gestionar el hogar compartido.</p>
  <h2>Cómo se usa y quién puede verla</h2>
  <p>La información se envía a la API autogestionada de Nido para que las personas cuidadoras autorizadas del mismo hogar puedan consultar y actualizar sus registros. El inicio de sesión se realiza con Apple; Apple procesa la autenticación de acuerdo con sus propios términos y políticas.</p>
  <p>Nido no incluye publicidad ni seguimiento publicitario. Esta descripción no supone que no haya tratamiento técnico necesario para prestar el servicio.</p>
  <h2>Conservación y eliminación</h2>
  <p>Si la persona propietaria elimina su cuenta, se elimina el hogar con sus registros y las cuentas vinculadas. Si una persona integrante elimina su cuenta, se elimina su identidad de acceso. Los registros de cuidados compartidos y sus datos de autoría pueden permanecer en el hogar.</p>
  <h2>Acceso y exportación</h2>
  <p>Las personas cuidadoras autorizadas pueden consultar los registros compartidos en la aplicación. La exportación de datos se inicia desde las opciones disponibles en Nido.</p>
  <h2>Responsable y contacto</h2>
  <p>Responsable: ${safeController}. Para consultas sobre privacidad o soporte, escribe a <a href="mailto:${encodedEmail}">${safeEmail}</a>.</p>
  <p>Consulta también la <a href="/api/nido/legal/support">página de soporte</a>.</p>
</main>`;
  return new Response(pageDocument("Privacidad", content), {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" },
  });
}

function supportPage(controller: string, email: string): Response {
  const safeController = escapeHTML(controller);
  const safeEmail = escapeHTML(email);
  const encodedEmail = encodeURIComponent(email).replaceAll("%40", "@");
  const content = `<main>
  <h1>Soporte de Nido</h1>
  <p>Si necesitas ayuda con tu cuenta, el hogar compartido o tus datos, contacta con el equipo responsable de Nido.</p>
  <p><a href="mailto:${encodedEmail}">${safeEmail}</a></p>
  <p>Responsable: ${safeController}.</p>
  <p>Nido no ofrece atención médica ni es un servicio para emergencias médicas. En una emergencia, contacta con los servicios de emergencia de tu zona.</p>
  <p><a href="/api/nido/legal/privacy">Política de privacidad</a></p>
</main>`;
  return new Response(pageDocument("Soporte", content), {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" },
  });
}

export function legalPageResponse(kind: LegalPageKind): Response {
  const contact = configuredContact();
  if (!contact) return unavailable();
  return kind === "privacy"
    ? privacyPage(contact.controller, contact.email)
    : supportPage(contact.controller, contact.email);
}
