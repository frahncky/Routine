# Cloud Functions — validação de compras

Este diretório existe para fechar uma lacuna que existia no app: o cliente
grava um documento `pending` em `purchase_validations` ao concluir uma
compra na loja, mas nada validava o recibo nem liberava o plano pago em
`users/{email}.typeAccount`. As Firestore rules bloqueiam o cliente de se
auto-promover a um plano pago — só estas Cloud Functions, rodando com
credenciais admin, podem fazer isso.

## O que tem aqui

- **`validatePurchase`** — dispara quando `purchase_validations/{id}` é
  criado/atualizado com `status: 'pending'`. Verifica o recibo direto com a
  Google Play Developer API ou o endpoint `verifyReceipt` da Apple e, se
  válido, atualiza `users/{email}.typeAccount` para o plano comprado.
- **`recheckSubscriptions`** — roda 1x/dia, reverifica assinaturas ativas e
  rebaixa para `gratuito` quem cancelou/teve o pagamento recusado/expirou.
  Sem isso, `validatePurchase` só libera o plano na hora da compra e nunca
  mais saberia que a assinatura parou de ser paga.

## Pré-requisitos antes do deploy

1. **Plano Blaze no projeto Firebase** (`routine-8a97a`). Cloud Functions
   2ª geração e chamadas de rede de saída (para a Apple) exigem faturamento
   habilitado, mesmo dentro da faixa gratuita.
2. **Firebase CLI instalado e logado**: `npm install -g firebase-tools` e
   `firebase login`.

## Configurar acesso ao Google Play

A função usa as credenciais padrão do ambiente (a conta de serviço de
runtime da própria Cloud Function) para chamar a Play Developer API — não
precisa gerenciar chave JSON.

1. Descubra o e-mail da conta de serviço de runtime (normalmente
   `routine-8a97a@appspot.gserviceaccount.com` para Cloud Functions 2ª
   geração; confirme em Google Cloud Console > IAM depois do primeiro
   deploy).
2. No [Google Play Console](https://play.google.com/console) > **Configurações
   > Acesso à API**, vincule o projeto Google Cloud do Firebase e conceda a
   essa conta de serviço as permissões:
   - **Ver dados financeiros**
   - **Gerenciar pedidos e assinaturas**
3. Confirme que `GOOGLE_PLAY_PACKAGE_NAME` (em `.env`, veja `.env.example`)
   bate com o `package_name` do app (`com.routine.app`).

## Configurar o segredo da App Store

1. Em [App Store Connect](https://appstoreconnect.apple.com) > seu app >
   **App Information**, gere/copie o **App-Specific Shared Secret**.
2. Configure como Cloud Functions secret (nunca commitar em `.env`):
   ```
   firebase functions:secrets:set APPLE_SHARED_SECRET
   ```

## Deploy

```bash
cd functions
npm install
cd ..
firebase deploy --only functions,firestore:rules
```

Sempre faça deploy das `firestore:rules` junto na primeira vez — elas foram
ajustadas para só permitir que o cliente grave `typeAccount: 'gratuito'`
diretamente; planos pagos só são gravados por estas functions.

## Testando

- **Google Play**: use uma [licença de teste](https://support.google.com/googleplay/android-developer/answer/6062777)
  ou uma faixa de teste interno, compre o produto no app e acompanhe os
  logs (`firebase functions:log` ou Cloud Console) para ver `validatePurchase`
  processar o `purchase_validations` e atualizar o `typeAccount`.
- **Apple**: use um [sandbox tester](https://developer.apple.com/apple-store-connect/) —
  o `verifyReceipt` detecta automaticamente recibo de sandbox (status 21007)
  e reconsulta o endpoint correto.
- Sem essas contas de loja configuradas, `validatePurchase` grava
  `status: 'rejected'` com o motivo (`reason`) em `purchase_validations` — é
  esperado até a configuração acima estar completa.

## Limitações conhecidas / próximos passos

- **`verifyReceipt` é o endpoint legado da Apple.** Funciona, mas a Apple
  recomenda migrar para a App Store Server API (JWT assinado com chave
  privada) em integrações novas. Trocamos pela simplicidade de setup inicial
  (só precisa do shared secret, sem gerenciar chave/keyId); migrar depois é
  isolado em `src/appStore.ts`.
- **`recheckSubscriptions` é por polling (1x/dia)**, não por webhook. Um
  cancelamento pode levar até 24h para refletir no app. Para reação em
  tempo real, o próximo passo seria assinar as *Real-time Developer
  Notifications* do Google Play (Pub/Sub) e as *App Store Server
  Notifications V2* da Apple.
- Nenhuma dessas functions foi exercitada contra uma compra real (exige
  credenciais de loja que não existem neste ambiente de desenvolvimento) —
  só o build/typecheck TypeScript foi validado. Teste com uma compra sandbox
  antes de liberar para produção.
