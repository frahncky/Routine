# Docs Públicos (Play Console)

Este diretório contém as páginas web exigidas pelo Google Play Console.

## Arquivos publicados

- `docs/politica-privacidade.html`
- `docs/exclusao-conta.html`

Todo o resto (`PLAY_STORE_PUBLISH_GUIDE.md`, este `README.md`, a pasta `play/`) é
**excluído do site público** por `docs/_config.yml`. Confira isso depois de publicar.

## O que conferir antes de publicar

1. E-mail de suporte nas duas páginas (`deviasuporte@gmail.com`) — precisa ser uma caixa real e monitorada.
2. Data de atualização no topo de cada página.
3. Que a lista de dados coletados bate com o app atual (sem acesso à agenda de contatos do dispositivo).

## Publicar no GitHub Pages

1. Commit e push destes arquivos para `main`.
2. No GitHub (`frahncky/Routine`), abra `Settings > Pages`.
3. Em `Source`, selecione:
   - Branch: `main`
   - Folder: `/docs`
4. Salve e aguarde o link público.

URLs resultantes:

- `https://frahncky.github.io/Routine/politica-privacidade.html`
- `https://frahncky.github.io/Routine/exclusao-conta.html`

## Alternativa: Firebase Hosting

`firebase init hosting` com `public: docs/public` (uma pasta só com as duas páginas)
gera `https://routine-8a97a.web.app/politica-privacidade.html`.

## Onde usar no Play Console

- `Ficha da Play Store > Política de Privacidade` → URL da política
- `Conteúdo do app > Segurança dos dados > Exclusão de conta` → URL de exclusão
