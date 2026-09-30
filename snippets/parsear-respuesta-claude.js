// Parseo seguro de la respuesta de Claude (nodo Code de n8n, modo «Run Once for All Items»).
//
// La salida de un modelo es una ENTRADA NO FIABLE:
//   - puede traer texto alrededor del JSON;
//   - puede traer un JSON mal formado o con campos inesperados;
//   - la llamada HTTP puede haber fallado (el nodo anterior continúa con un error).
// En ningún caso se rompe el flujo: el contacto ya está guardado y se completa con valores seguros.

const VIABILIDADES = ['alta', 'media', 'baja'];
const POR_DEFECTO = {
  viabilidad: 'pendiente',
  tipo_caso: 'Sin clasificar',
  resumen_corto: '',
  prioridad: 3,
  p1: '',
  p2: '',
  p3: '',
};

/** Extrae el primer objeto JSON equilibrado del texto (respetando cadenas y escapes). */
function extraerJson(texto) {
  const inicio = texto.indexOf('{');
  if (inicio < 0) return null;
  let profundidad = 0;
  let enCadena = false;
  let escape = false;
  for (let i = inicio; i < texto.length; i++) {
    const c = texto[i];
    if (enCadena) {
      if (escape) escape = false;
      else if (c === '\\') escape = true;
      else if (c === '"') enCadena = false;
      continue;
    }
    if (c === '"') enCadena = true;
    else if (c === '{') profundidad++;
    else if (c === '}' && --profundidad === 0) return texto.slice(inicio, i + 1);
  }
  return null;
}

const texto = (s, max) => (typeof s === 'string' ? s.trim().slice(0, max) : '');

function validar(bruto) {
  const a = { ...POR_DEFECTO };
  if (!bruto || typeof bruto !== 'object') return a;
  const v = String(bruto.viabilidad || '').toLowerCase().trim();
  a.viabilidad = VIABILIDADES.includes(v) ? v : 'pendiente';
  a.tipo_caso = texto(bruto.tipo_caso, 255) || POR_DEFECTO.tipo_caso;
  a.resumen_corto = texto(bruto.resumen_corto, 1000);
  const p = Number.parseInt(bruto.prioridad, 10);
  a.prioridad = Number.isFinite(p) ? Math.min(5, Math.max(1, p)) : 3;
  a.p1 = texto(bruto.p1, 1500);
  a.p2 = texto(bruto.p2, 1500);
  a.p3 = texto(bruto.p3, 1500);
  return a;
}

/** El texto del modelo va a un correo HTML: se escapa siempre. */
const escaparHtml = (s) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

// --- n8n ------------------------------------------------------------------------------------------

const respuesta = $input.first().json;
const contenido = Array.isArray(respuesta.content) ? respuesta.content : [];
const bloqueTexto = contenido.find((b) => b && b.type === 'text');
let analisis = { ...POR_DEFECTO };

if (bloqueTexto && typeof bloqueTexto.text === 'string') {
  const json = extraerJson(bloqueTexto.text);
  if (json) {
    try {
      analisis = validar(JSON.parse(json));
    } catch (e) {
      analisis = { ...POR_DEFECTO };
    }
  }
}

const contacto = $('Guardar contacto').first().json;
const parrafos = [analisis.p1, analisis.p2, analisis.p3].filter(Boolean);

return [
  {
    json: {
      id: contacto.id,
      nombre: contacto.nombre,
      email: contacto.email,
      telefono: contacto.telefono,
      servicio: contacto.servicio,
      horario: contacto.horario_preferido,
      mensaje: contacto.mensaje || 'Sin mensaje adicional',
      viabilidad: analisis.viabilidad,
      tipo_caso: analisis.tipo_caso,
      resumen: analisis.resumen_corto,
      prioridad: analisis.prioridad,
      correo_texto: parrafos.join('\n\n'),
      correo_html: parrafos.map((p) => '<p style="margin:0 0 16px;line-height:1.6">' + escaparHtml(p) + '</p>').join(''),
      analisis_ok: analisis.viabilidad !== 'pendiente',
    },
  },
];
