# Prompt de análisis del contacto

> Reescrito de forma genérica. Los servicios concretos del despacho se sustituyen por `<SERVICIOS>`.

## Qué recibe

Los datos del contacto tal como llegan de la entrada:

| Campo | Ejemplo genérico |
|---|---|
| Nombre | `Ana` |
| Email | `ana@example.com` |
| Teléfono | `<TELEFONO>` |
| Servicio que le interesa | `<SERVICIO>` |
| Horario preferido | `Por la tarde` |
| Mensaje libre | `Texto que escribe la persona` |

En el alta manual desde la aplicación se envía una versión reducida (nombre, servicio y mensaje) y no se pide el correo al contacto.

## El prompt

```text
Eres el asistente de una asesoría. Tu tarea es valorar un contacto comercial.
Responde ÚNICAMENTE con un objeto JSON válido, sin texto antes ni después.

Formato:
{
  "viabilidad": "alta" | "media" | "baja",
  "tipo_caso": string,
  "resumen_corto": string,
  "prioridad": 1-5,
  "p1": string,
  "p2": string,
  "p3": string
}

Criterios de viabilidad:
- alta:  el caso encaja claramente con uno de nuestros servicios y el mensaje da datos
         suficientes para actuar.
- media: encaja con nuestros servicios, pero falta información o hay dudas razonables.
- baja:  no encaja con nuestros servicios, o el mensaje no permite valorar nada.

Prioridad: 5 = contactar hoy; 1 = sin urgencia.

p1, p2 y p3 son los tres párrafos del correo al contacto:
- p1: saludo y agradecimiento, con su nombre.
- p2: sobre su consulta de [SERVICIO]: qué podemos hacer o, si no es de lo nuestro,
      una alternativa orientativa. Sin prometer resultados.
- p3: le llamaremos en su horario preferido [HORARIO]. Despedida.

Nuestros servicios: <SERVICIOS>.

Datos del contacto:
Nombre: {nombre}
Email: {email}
Teléfono: {telefono}
Servicio: {servicio}
Horario: {horario}
Mensaje: {mensaje}
```

> Los criterios de viabilidad y la escala de prioridad están escritos de forma explícita para este caso de estudio. La idea es la misma que en el sistema: una clasificación cerrada en tres niveles y una prioridad del 1 al 5.

## Qué devuelve

```json
{
  "viabilidad": "media",
  "tipo_caso": "Consulta sobre <SERVICIO>",
  "resumen_corto": "Persona interesada en <SERVICIO>; falta documentación para valorar el caso.",
  "prioridad": 3,
  "p1": "Hola Ana, gracias por escribirnos.",
  "p2": "Sobre tu consulta de <SERVICIO>, ...",
  "p3": "Te llamaremos por la tarde, como nos indicas. Un saludo."
}
```

## Qué se hace con la respuesta

En la versión de este repositorio:

1. Se extrae **el primer bloque `{…}`** del texto, porque el modelo a veces añade texto alrededor.
2. Se parsea y se **validan** los campos: la viabilidad tiene que ser uno de los valores permitidos y la prioridad se limita a 1–5.
3. Si algo falla, se aplican valores seguros: `viabilidad: "pendiente"`, `tipo_caso: "Sin clasificar"`, `prioridad: 3` y ningún párrafo.
4. Con `viabilidad`, `tipo_caso`, `resumen` y `prioridad` se hace el `UPDATE` del contacto.
5. Los párrafos se **escapan** antes de meterlos en el HTML del correo.
6. `viabilidad` decide si se envía el WhatsApp. Su texto es una **plantilla aprobada**, no texto generado.

Código: [snippets/parsear-respuesta-claude.js](../snippets/parsear-respuesta-claude.js).

## Por qué así

- **Formato cerrado.** Tres niveles de viabilidad y una prioridad numérica se pueden filtrar, ordenar, contar en los informes y usar en una condición, cosa que no pasa con un texto libre.
- **El correo lo redacta el modelo, pero dentro de una plantilla.** La cabecera, la firma y el formato son fijos. El modelo solo escribe tres párrafos, y se le pide expresamente que no prometa resultados.
- **Un modelo pequeño.** La tarea es clasificar y redactar tres párrafos cortos. No hace falta un modelo grande, y la respuesta llega en segundos a bajo coste.
