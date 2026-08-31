# Play Assets

Coloque aqui os arquivos finais para envio no Play Console.

## Arquivos principais

- icon-512.png — 512x512, PNG 24-bit sem alpha. Gerado de `assets/images/app_icon_v2.png`.
- feature-graphic-1024x500.png — 1024x500, PNG sem alpha. Rasterizado de `../docs/play/feature-graphic-routine-1024x500.svg`
  (o Play NÃO aceita SVG). Para regerar: abrir o SVG num navegador em 1024x500 e exportar PNG.

## Phone (mínimo 2 para publicar)

| Arquivo | Estado |
|---|---|
| phone/01-home-atividades-do-dia.png | ✅ atual (1200x2400, pós-redesign, 2026-08-30) |
| phone/02-cadastro-de-atividade.png | ✅ atual (1200x2400) |
| phone/04-historico-de-atividades.png | ✅ atual (1200x2400 — tela "Progresso") |
| phone/03-lembretes-e-notificacoes.png | ⛔ removido — gerar de novo (era pré-redesign) |
| phone/05-configuracoes-e-perfil.png | ⛔ removido — gerar de novo |
| phone/06-planos-e-recursos.png | ⛔ removido — era pré-redesign **e com preços/planos errados** |

As três atuais já são suficientes para publicar. Para as outras três, rodar o gerador
(`integration_test/play_store_screenshots_test.dart`, já corrigido para o novo layout)
num emulador/aparelho mais rápido — ele produz as 6 numa passada — e normalizar com
`normalize_screenshots.ps1`.

## Tablet 7 / Tablet 10 (opcionais)

Os PNGs em `tablet7/` e `tablet10/` são **pré-redesign** — não subir como estão.
Screenshots de tablet são opcionais no Play; se for declarar suporte a tablet,
rodar o mesmo gerador num emulador de tablet e mover a saída de `staging/phone/`.

## Regras rapidas

- Icone: 512x512 (PNG 24-bit, sem transparencia)
- Feature graphic: 1024x500 (PNG/JPG, sem transparencia, sem SVG)
- Screenshots: sem dados pessoais reais
- Screenshots de celular: proporcao do lado maior / lado menor **nao pode passar de 2:1**.
  Uma captura 1080x2400 (2.22:1) e RECUSADA. Normalize com padding lateral ate 2:1
  (ex.: 1080x2400 -> 1200x2400) replicando a cor da borda, ou capture em 1080x1920.
- Gerador oficial dos 6 screenshots de celular: `integration_test/play_store_screenshots_test.dart`
  (escreve em `staging/phone/`; promova para `phone/` depois de conferir).
