# Snippets

Todo está **reescrito desde cero** para el caso de estudio. No contiene ningún valor del sistema real: las URLs son de `example.com`, no hay credenciales y los identificadores de los nodos son UUID aleatorios nuevos.

| Fichero | Qué es |
|---|---|
| [flujo-principal.n8n.json](flujo-principal.n8n.json) | **Plantilla importable de n8n** del flujo principal: webhook → guardar → responder → Claude → parseo → guardar análisis → correos → WhatsApp condicional tras 2 minutos |
| [parsear-respuesta-claude.js](parsear-respuesta-claude.js) | Parseo seguro de la respuesta del modelo: extracción del JSON, validación, valores por defecto y escape HTML |
| [esquema.sql](esquema.sql) | Esquema genérico de PostgreSQL con los triggers de normalización |
| [informe-semanal.sql](informe-semanal.sql) | Métricas del informe semanal en una sola consulta, con desgloses en JSON |

## Cómo importar la plantilla

1. En n8n: **Workflows → Import from File** y elige `flujo-principal.n8n.json`.
2. Crea las credenciales y asígnalas a sus nodos:
   - PostgreSQL;
   - SMTP;
   - un *Header Auth* para Claude (`x-api-key`);
   - otro *Header Auth* para WhatsApp (`Authorization: Bearer …`).
3. Cambia las URLs de ejemplo por las reales:
   - en «Analizar con Claude», la de la API de Mensajes de Anthropic;
   - en «WhatsApp», la de la API de WhatsApp Business, con tu `PHONE_NUMBER_ID`.
4. Crea y aprueba en WhatsApp Business una plantilla llamada `confirmacion_contacto`, con un parámetro para el nombre.
5. Sustituye `<SERVICIOS>` en el nodo «Preparar prompt».
6. Crea las tablas con `esquema.sql`.

Los nodos de envío (correos y WhatsApp) están configurados para **continuar si fallan**: un aviso que no llega no deja el contacto a medias, porque ya está guardado y analizado.
