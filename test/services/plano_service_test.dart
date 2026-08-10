import 'package:flutter_test/flutter_test.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/models/usuario.dart';
import 'package:routine/services/plano_service.dart';

void main() {
  final service = PlanoService();

  Usuario buildUser(String plano) {
    return Usuario(
      id: '1',
      nome: 'Usuario Teste',
      email: 'teste@routine.app',
      fotoUrl: '',
      plano: plano,
    );
  }

  group('PlanoService limits', () {
    test('obterLimiteDoPlano returns expected values', () {
      expect(service.obterLimiteDoPlano(PlanRules.gratuito), 3);
      expect(service.obterLimiteDoPlano(PlanRules.basico), 20);
      expect(
          service.obterLimiteDoPlano(PlanRules.avancado), greaterThan(1000));
      expect(service.obterLimiteDoPlano(PlanRules.colaborativo),
          greaterThan(1000));
      expect(service.obterLimiteDoPlano('desconhecido'), 3);
    });

    test('obterLimitePara uses user plan', () {
      expect(service.obterLimitePara(buildUser(PlanRules.gratuito)), 3);
      expect(service.obterLimitePara(buildUser(PlanRules.basico)), 20);
      expect(
        service.obterLimitePara(buildUser(PlanRules.avancado)),
        greaterThan(1000),
      );
      expect(
        service.obterLimitePara(buildUser(PlanRules.colaborativo)),
        greaterThan(1000),
      );
    });

    test('planoTemLimite is false only for avancado and colaborativo', () {
      expect(service.planoTemLimite(PlanRules.gratuito), isTrue);
      expect(service.planoTemLimite(PlanRules.basico), isTrue);
      expect(service.planoTemLimite(PlanRules.avancado), isFalse);
      expect(service.planoTemLimite(PlanRules.colaborativo), isFalse);
    });

    test('podeAdicionarAtividade respects boundaries', () {
      expect(
        service.podeAdicionarAtividade(
          plano: PlanRules.gratuito,
          totalAtividades: 2,
        ),
        isTrue,
      );
      expect(
        service.podeAdicionarAtividade(
          plano: PlanRules.gratuito,
          totalAtividades: 3,
        ),
        isFalse,
      );
      expect(
        service.podeAdicionarAtividade(
          plano: PlanRules.basico,
          totalAtividades: 19,
        ),
        isTrue,
      );
      expect(
        service.podeAdicionarAtividade(
          plano: PlanRules.basico,
          totalAtividades: 20,
        ),
        isFalse,
      );
      expect(
        service.podeAdicionarAtividade(
          plano: PlanRules.avancado,
          totalAtividades: 999999,
        ),
        isTrue,
      );
      expect(
        service.podeAdicionarAtividade(
          plano: PlanRules.colaborativo,
          totalAtividades: 999999,
        ),
        isTrue,
      );
    });

    test('atividadesRestantes never returns negative values', () {
      expect(
        service.atividadesRestantes(
          plano: PlanRules.gratuito,
          totalAtividades: 1,
        ),
        2,
      );
      expect(
        service.atividadesRestantes(
          plano: PlanRules.gratuito,
          totalAtividades: 100,
        ),
        0,
      );
      expect(
        service.atividadesRestantes(
          plano: PlanRules.basico,
          totalAtividades: 18,
        ),
        2,
      );
      expect(
        service.atividadesRestantes(
          plano: PlanRules.avancado,
          totalAtividades: 5000,
        ),
        greaterThan(1000000),
      );
      expect(
        service.atividadesRestantes(
          plano: PlanRules.colaborativo,
          totalAtividades: 5000,
        ),
        greaterThan(1000000),
      );
    });
  });

  group('PlanoService metadata and plan change', () {
    test('listarPlanosDisponiveis returns a read-only copy', () {
      final planos = service.listarPlanosDisponiveis();
      expect(
        planos,
        [
          PlanRules.gratuito,
          PlanRules.basico,
          PlanRules.avancado,
          PlanRules.colaborativo,
        ],
      );
      expect(() => planos.add('novo'), throwsUnsupportedError);
    });

    test('mudarPlano normalizes aliases', () async {
      final atual = buildUser(PlanRules.gratuito);
      final atualizado = await service.mudarPlano(atual, 'Family');
      expect(atualizado.plano, PlanRules.colaborativo);
      expect(atualizado.id, atual.id);
      expect(atualizado.email, atual.email);
    });

    test('mudarPlano keeps current plan when target is invalid', () async {
      final atual = buildUser(PlanRules.basico);
      final atualizado = await service.mudarPlano(atual, 'invalido');
      expect(atualizado.plano, PlanRules.basico);
    });

    test('descricaoPlano maps each plan', () {
      expect(
        service.descricaoPlano(PlanRules.gratuito),
        contains('salvos apenas no celular'),
      );
      expect(
        service.descricaoPlano(PlanRules.basico),
        contains('limite ampliado'),
      );
      expect(
        service.descricaoPlano(PlanRules.avancado),
        contains('backup em nuvem'),
      );
      expect(
        service.descricaoPlano(PlanRules.colaborativo),
        contains('agenda colaborativa'),
      );
    });
  });
}
