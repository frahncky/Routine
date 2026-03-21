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
      expect(service.obterLimiteDoPlano(PlanRules.gratis), 3);
      expect(service.obterLimiteDoPlano(PlanRules.basico), 20);
      expect(service.obterLimiteDoPlano(PlanRules.premium), greaterThan(1000));
      expect(service.obterLimiteDoPlano('desconhecido'), 3);
    });

    test('obterLimitePara uses user plan', () {
      expect(service.obterLimitePara(buildUser(PlanRules.gratis)), 3);
      expect(service.obterLimitePara(buildUser(PlanRules.basico)), 20);
      expect(
        service.obterLimitePara(buildUser(PlanRules.premium)),
        greaterThan(1000),
      );
    });

    test('planoTemLimite is false only for premium', () {
      expect(service.planoTemLimite(PlanRules.gratis), isTrue);
      expect(service.planoTemLimite(PlanRules.basico), isTrue);
      expect(service.planoTemLimite(PlanRules.premium), isFalse);
    });

    test('podeAdicionarAtividade respects boundaries', () {
      expect(
        service.podeAdicionarAtividade(
          plano: PlanRules.gratis,
          totalAtividades: 2,
        ),
        isTrue,
      );
      expect(
        service.podeAdicionarAtividade(
          plano: PlanRules.gratis,
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
          plano: PlanRules.premium,
          totalAtividades: 999999,
        ),
        isTrue,
      );
    });

    test('atividadesRestantes never returns negative values', () {
      expect(
        service.atividadesRestantes(
          plano: PlanRules.gratis,
          totalAtividades: 1,
        ),
        2,
      );
      expect(
        service.atividadesRestantes(
          plano: PlanRules.gratis,
          totalAtividades: 100,
        ),
        0,
      );
      expect(
        service.atividadesRestantes(
          plano: PlanRules.premium,
          totalAtividades: 5000,
        ),
        greaterThan(1000000),
      );
    });
  });

  group('PlanoService metadata and plan change', () {
    test('listarPlanosDisponiveis returns a read-only copy', () {
      final planos = service.listarPlanosDisponiveis();
      expect(planos, [PlanRules.gratis, PlanRules.basico, PlanRules.premium]);
      expect(() => planos.add('novo'), throwsUnsupportedError);
    });

    test('mudarPlano normalizes aliases', () async {
      final atual = buildUser(PlanRules.gratis);
      final atualizado = await service.mudarPlano(atual, 'Family');
      expect(atualizado.plano, PlanRules.premium);
      expect(atualizado.id, atual.id);
      expect(atualizado.email, atual.email);
    });

    test('descricaoPlano maps each plan', () {
      expect(service.descricaoPlano(PlanRules.gratis), contains('anúncios'));
      expect(service.descricaoPlano(PlanRules.basico), contains('Sem anúncios'));
      expect(
        service.descricaoPlano(PlanRules.premium),
        contains('colaborativa completa'),
      );
    });
  });
}
