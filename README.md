# Routine

App Flutter de planejamento de rotinas pessoais e colaborativas, com backend Firebase.

## Stack

- **Flutter + Riverpod** para estado (`lib/providers/app_providers.dart`).
- **SQLite local** (`sqflite`, `lib/helper/database_helper.dart`) como fonte de verdade dos dados no dispositivo.
- **Firestore** para autenticação social, convites/colaboração em tempo real e backup em nuvem (planos pagos).
- **Cloud Functions** (`functions/`, TypeScript) para validação de compras (Google Play / App Store) — é o único caminho que pode conceder um plano pago; o cliente nunca grava isso direto no Firestore.

## Planos de assinatura

| Plano | Atividades | Backup em nuvem | Agenda colaborativa |
|---|---|---|---|
| Gratuito | até 3 | não | não |
| Básico | até 20 | não | não |
| Avançado | ilimitadas | sim | não |
| Colaborativo | ilimitadas | sim | sim (contatos, grupos, convites) |

Regras de acesso por plano em `lib/features/assinatura/plan_rules.dart` / `plan_access.dart`.

## Funcionalidades

- Cadastro de atividades com repetição semanal e exceções pontuais (editar/excluir só uma ocorrência).
- Sequência ("streak") de hábito para atividades recorrentes, calculada a partir do histórico de conclusão por ocorrência.
- Convites e participantes em atividades (plano Colaborativo).
- Backup em nuvem com restauração em novo dispositivo (planos Avançado/Colaborativo).
- Compras in-app com validação server-side (Cloud Functions) antes de liberar um plano pago.

## Desenvolvimento

- `flutter analyze` e `flutter test` antes de qualquer PR.
- Agentes especializados do Claude Code em `.claude/agents/` (product-planner, flutter-ui-designer, flutter-dev, cloud-functions-dev, flutter-qa) documentam as convenções do projeto.
- Setup do backend de Cloud Functions: veja `functions/README.md`.
