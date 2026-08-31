# 🚀 Guia Oficial de Publicação na Google Play Store — Routine

Este documento contém todas as instruções, respostas de formulários e configurações necessárias para submeter o aplicativo **Routine** na Google Play Store e obter aprovação sem pendências.

---

## 📌 1. Informações Básicas do Aplicativo

* **Nome do App:** Routine
* **Identificador de Pacote (Application ID):** `com.routine.app` *(Certifique-se de que este ID pertence à sua conta no Play Console)*
* **Versão:** `1.0.2+3` (Código de versão: `3`) — definida em `pubspec.yaml` (`version:`). O `versionCode` **precisa ser maior** que qualquer build já enviado a qualquer faixa (interna, fechada, produção). Se o código `2` já subiu em algum momento, use `3` ou superior.
* **Arquivo Release pronto para envio:** `build/app/outputs/bundle/release/app-release.aab` (gerado por `flutter build appbundle --release`, assinado com a chave de `android/key.properties`).
* **Categoria do App:** `Produtividade` (categoria primária única — não escolha duas). "Estilo de vida" pode ser citada apenas como tag secundária, se desejar.
* **Classificação de Conteúdo:** resultado esperado do questionário **IARC** no Play Console. O app não tem anúncios, violência, conteúdo sexual nem conteúdo gerado por usuário exibido publicamente, então a expectativa é **Livre / Everyone**. Ainda assim, é obrigatório **responder o questionário** — o selo não é pré-definido.

---

## 🔒 2. Questionário de Segurança dos Dados (Data Safety Form)

No Google Play Console, acesse **Conteúdo do app > Segurança dos dados** e responda conforme o quadro abaixo:

### Perguntas Gerais
1. **O app coleta ou compartilha algum dos tipos de dados de usuários necessários?**
   👉 **Sim**
2. **Todos os dados de usuários coletados pelo app são criptografados em trânsito?**
   👉 **Sim** (comunicação HTTPS/TLS via Firebase)
3. **O app oferece uma forma para os usuários solicitarem a exclusão dos dados?**
   👉 **Sim** (no próprio app em Configurações > Excluir Conta e via página web)

---

### Tipos de Dados Coletados e Finalidades

| Tipo de Dado | Coletado? | Compartilhado? | Efêmero? | Obrigatório ou Opcional? | Finalidade |
|---|---|---|---|---|---|
| **Nome** (Informações Pessoais) | Sim | Não | Não | Opcional | Funcionalidade do app, personalização de perfil, e **nome de contatos/participantes** adicionados manualmente para a agenda colaborativa |
| **Endereço de e-mail** | Sim | Não | Não | Obrigatório | Gerenciamento de conta / Autenticação (Firebase Auth), e **e-mail de contatos/participantes** digitado pelo usuário para enviar convites de atividade |
| **ID de Usuário / Conta** | Sim | Não | Não | Obrigatório | Gerenciamento de conta / Identificação |
| **Fotos / Imagens** | Sim | Não | Não | Opcional | Foto de perfil do usuário (armazenada localmente ou no Firebase Storage) |
| **Logs de falhas (Crashlytics)** | Sim | Não | Não | Obrigatório | Análise de estabilidade e correção de erros |
| **Diagnósticos de desempenho** | Sim | Não | Não | Obrigatório | Desempenho e monitoramento |
| **Ações no app / Analytics** | Sim | Não | Não | Obrigatório | Firebase Analytics — métricas de uso agregadas para melhorar o produto |
| **IDs do dispositivo (FCM Token)** | Sim | Não | Não | Obrigatório | Notificações push de lembretes e convites |
| **Informações da agenda** (atividades, datas, horários, status, participantes) | Sim | Não | Não | Opcional | Funcionalidade principal do app; sincronização/backup em nuvem apenas nos planos Avançado e Colaborativo |

> ⚠️ **Não declarar "Contatos".** O app **não lê a agenda de contatos do dispositivo** — a permissão `READ_CONTACTS` e a biblioteca `flutter_contacts` foram removidas. Os contatos/participantes da agenda colaborativa são **digitados manualmente** (nome + e-mail) dentro do app e já estão cobertos pelas linhas **Nome** e **Endereço de e-mail** acima.

---

## ⏰ 3. Declaração de Permissão de Alarmes Exatos (`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`)

**Estado no manifesto** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

* Em **Android 12 (API 31–32)** o app usa `SCHEDULE_EXACT_ALARM` (limitado por `maxSdkVersion="32"`).
* Em **Android 13+ (API 33+)** o app usa `USE_EXACT_ALARM`, que é concedida automaticamente a apps cuja funcionalidade central é alarme/agenda/lembrete — caso do Routine.
* No código, `lib/notifications/notifications.dart` só usa `AndroidScheduleMode.exactAllowWhileIdle` quando a permissão está disponível; caso contrário faz *fallback* para `inexactAllowWhileIdle`.

No Play Console, na seção de **Acesso especial a apps / Permissões sensíveis (Alarmes e Lembretes)**:

* **Pergunta:** Qual é o caso de uso principal do app para solicitar alarmes exatos?
* **Seleção:** *Lembretes de tarefas, calendários ou gerenciamento de rotinas.*
* **Texto de Justificativa para colar no formulário:**
> "O aplicativo Routine é um gerenciador de rotinas e hábitos diários onde a precisão de horário é fundamental para a experiência do usuário. O app agenda notificações e alarmes pontuais antes do início exato de cada atividade cadastrada (ex: medicamentos, reuniões, treinos e rotinas de estudo). O uso de alarmes exatos é estritamente necessário para garantir que o usuário seja notificado no minuto programado, mesmo quando o dispositivo estiver em modo de economia de energia ou ociosidade (Doze mode)."

---

## 💳 4. Configuração das Assinaturas (Google Play Billing)

No Google Play Console, vá em **Monetizar > Produtos > Assinaturas** e crie os 3 produtos com os **Product IDs exatos abaixo**. Estes IDs são os que o app consulta em `lib/features/assinatura/subscription_service.dart` (`productIdsByPlan`) e que o Cloud Function valida em `functions/src/plans.ts` (`PRODUCT_ID_TO_PLAN`). **Qualquer divergência faz `queryProductDetails` retornar vazio (`productNotFound`) e nenhuma compra é concluída.**

| Plano (nome exibido) | Product ID (SKU) no Play Console | Preço mensal | Tipo | Descrição |
|---|---|---|---|---|
| **Básico** | `routine_basico_monthly` | **R$ 4,90/mês** | Assinatura Mensal | Agenda pessoal, até 20 atividades, dados salvos no celular |
| **Avançado** | `routine_plus_monthly` | **R$ 14,90/mês** | Assinatura Mensal | Atividades ilimitadas + backup na nuvem + recuperação em novo dispositivo |
| **Colaborativo** | `routine_premium_monthly` | **R$ 24,90/mês** | Assinatura Mensal | Tudo do Avançado + agenda colaborativa, convites, participantes e contatos compartilhados |

> ⚠️ **Não renomeie os slugs.** O ID do Avançado usa `plus` e o do Colaborativo usa `premium` (nomes históricos) — **não** troque para `avancado`/`colaborativo`. O plano **Gratuito** (`R$ 0`, até 7 atividades) **não** é um produto de billing; não crie SKU para ele.

> ⚠️ **Preços devem bater com o app.** As telas de planos (`lib/features/assinatura/assinatura_screen.dart`) exibem os preços **fixos no código** (`R$ 4,90/mês`, `R$ 14,90/mês`, `R$ 24,90/mês`). O preço cadastrado no Play Console precisa ser idêntico, senão há divergência entre o preço anunciado e o cobrado (risco de reprovação por "informação enganosa"). Se mudar o preço, atualize **os dois lados**.

> ⚠️ **Importante:** Após criar as assinaturas, ative o **plano base mensal** de cada uma com preço em BRL (e USD, se for vender fora do Brasil) antes de promover o build de teste fechado.

---

## ☁️ 5. Deploy do Backend (Cloud Functions & Firestore)

Para que as assinaturas sejam validadas e concedidas automaticamente:

1. **Vincular a Conta de Serviço do Firebase na Play Console:**
   - No Play Console > **Configurações > Acesso à API**, vincule o projeto `routine-8a97a`.
   - Conceda permissão de **Ver dados financeiros** e **Gerenciar pedidos e assinaturas** à conta de serviço de runtime do Firebase Functions (`routine-8a97a@appspot.gserviceaccount.com`).

2. **Executar o Deploy das Funções:**
   ```bash
   cd F:\DevIA\approutine\functions
   npm install
   npm run build
   cd ..
   firebase deploy --only functions,firestore:rules
   ```

3. **Funções esperadas no projeto** (`functions/src/index.ts`):
   `validatePurchase`, `recheckSubscriptions`, `notifyInvites`, `cleanupUser`.
   - `cleanupUser` é um gatilho `auth.user().onDelete` (**1ª geração** — `firebase-functions/v1`). Ele apaga em cascata `users/{email}` + subcoleções de backup + `activity_invites` quando a conta é excluída (pelo app, pelo Console ou por pedido web). O `pubspec`/cliente também faz uma limpeza best-effort em `delete_account.dart`, mas o gatilho é a garantia. Confirme no deploy que a função 1ª geração subiu sem erro (o Firebase ainda suporta gatilhos Auth de 1ª geração, mas exige a API Cloud Functions v1 habilitada no projeto).

---

## 🌐 6. URLs Obrigatórias para a Ficha da Loja

As páginas legais estão em `docs/politica-privacidade.html` e `docs/exclusao-conta.html`.
Publicação via **GitHub Pages** (já descrita em `docs/README.md`):

1. `Settings > Pages` no repositório `frahncky/Routine`.
2. `Source`: branch `main`, pasta `/docs`.
3. O arquivo `docs/_config.yml` exclui da publicação o guia interno (`PLAY_STORE_PUBLISH_GUIDE.md`), o `README.md` e a pasta `play/` — **confira que só as duas páginas HTML ficam públicas**.

* **URL da Política de Privacidade:**
  `https://frahncky.github.io/Routine/politica-privacidade.html`
* **URL de Solicitação de Exclusão de Conta:**
  `https://frahncky.github.io/Routine/exclusao-conta.html`

> Alternativa: Firebase Hosting apontando para uma pasta só com as duas páginas
> (`firebase init hosting` → `public: docs/public`) resultando em
> `https://routine-8a97a.web.app/politica-privacidade.html`.

No Play Console:

* `Ficha da Play Store > Política de Privacidade` → URL da política
* `Conteúdo do app > Segurança dos dados > Exclusão de conta` → URL de exclusão

---

## 🔑 7. Acesso do App para Revisão (App Access)

O app tem tela de login, mas **não é obrigatório** entrar para usar as funções principais:
há um **modo visitante** (perfil "Visitante", plano Gratuito local — `lib/providers/app_providers.dart`,
`lib/main_tabs.dart`). Na seção **Conteúdo do app > Acesso ao app** do Play Console:

* Marque **"Todas as funcionalidades ficam disponíveis sem restrições de acesso especiais"**, OU
* Se preferir demonstrar um plano pago, forneça credenciais de uma conta de teste + um cartão de teste
  do License Testing (Play Console > Configurações > Testes de licença) para o revisor validar assinatura.

Recursos colaborativos (aba "Colaborativo") ficam bloqueados fora do plano Colaborativo — descreva isso
no campo de instruções para o revisor para evitar reprovação por "função inacessível".

---

## 👥 8. Requisito de 20 Testadores (Teste Fechado — Contas Pessoais)

Se sua conta de desenvolvedor do Google Play foi criada após **Novembro de 2023**, a Google exige:
1. Criar uma **Faixa de Teste Fechado (Closed Testing)**.
2. Cadastrar no mínimo **20 testadores** (lista de e-mails do Google).
3. Garantir que os 20 testadores instalem o app e permaneçam inscritos por pelo menos **14 dias ininterruptos**.
4. Responder ao formulário de perguntas sobre o feedback recebido dos testadores no Play Console para solicitar acesso à faixa de **Produção**.

---

## 📦 9. Como Subir a Nova Versão

Sempre que gerar uma nova versão para envio:

1. Incrementar o `version` em `pubspec.yaml` (ex: `1.0.2+3` → `1.0.3+4`). O número após o `+` (versionCode) **sempre** aumenta.
2. Gerar o bundle de produção:
   ```bash
   flutter build appbundle --release
   ```
3. Conferir a assinatura: o `key.properties` precisa existir e apontar para o `.jks` correto, senão o Gradle cai para *debug signing* e o Play recusa o AAB.
4. Fazer o upload do arquivo:
   `build\app\outputs\bundle\release\app-release.aab`

---

## 🖼️ 10. Assets Gráficos da Ficha (play-assets/)

| Asset | Requisito Play | Arquivo no repo | Status |
|---|---|---|---|
| Ícone | 512×512, PNG, sem transparência, ≤ 1 MB | `play-assets/icon-512.png` | ✅ gerado de `assets/images/app_icon_v2.png` (24-bit, 127 KB) |
| Feature graphic | 1024×500, PNG/JPG, **sem SVG** | `play-assets/feature-graphic-1024x500.png` | ✅ rasterizado de `docs/play/feature-graphic-routine-1024x500.svg` |
| Screenshots de celular | 2–8 imagens, lado 320–3840 px, **proporção ≤ 2:1**, PNG 24-bit sem alpha | `play-assets/phone/01,02,04` | ✅ 3 atuais (1200×2400, pós-redesign) — já dá para publicar. `03/05/06` foram removidos (pré-redesign; o `06` tinha planos/preços errados) — gerar de novo |
| Screenshots de tablet 7"/10" | opcionais | `play-assets/tablet7/*`, `play-assets/tablet10/*` | ⚠️ pré-redesign — não subir; gerar de novo só se declarar suporte a tablet |

Para regenerar os screenshots de celular (emulador Android sem login):

```powershell
flutter drive -d <emulatorId> `
  --driver=test_driver/play_store_screenshots_driver.dart `
  --target=integration_test/play_store_screenshots_test.dart `
  --dart-define=PLAY_STORE_SCREENSHOTS=true
```

Saída em `play-assets/staging/phone/`; depois promova para `play-assets/phone/` e normalize a proporção
(padding lateral até 2:1 — ver `play-assets/README.md`).
