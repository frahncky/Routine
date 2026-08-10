import 'package:flutter_test/flutter_test.dart';
import 'package:routine/features/assinatura/plan_rules.dart';

void main() {
  group('PlanRules.normalize', () {
    test('returns gratuito for null, empty, and unknown values', () {
      expect(PlanRules.normalize(null), PlanRules.gratuito);
      expect(PlanRules.normalize(''), PlanRules.gratuito);
      expect(PlanRules.normalize('   '), PlanRules.gratuito);
      expect(PlanRules.normalize('qualquer-coisa'), PlanRules.gratuito);
    });

    test('maps legacy free plan names to gratuito', () {
      expect(PlanRules.normalize('gratis'), PlanRules.gratuito);
      expect(PlanRules.normalize('gratuita'), PlanRules.gratuito);
      expect(PlanRules.normalize('gratuito'), PlanRules.gratuito);
      expect(PlanRules.normalize('free'), PlanRules.gratuito);
    });

    test('maps legacy plus/premium aliases to avancado/colaborativo', () {
      expect(PlanRules.normalize('basico'), PlanRules.basico);
      expect(PlanRules.normalize('individual'), PlanRules.basico);
      expect(PlanRules.normalize('plus'), PlanRules.avancado);
      expect(PlanRules.normalize('avancado'), PlanRules.avancado);
      expect(PlanRules.normalize('intermediario'), PlanRules.avancado);
      expect(PlanRules.normalize('intermediate'), PlanRules.avancado);
      expect(PlanRules.normalize('premium'), PlanRules.colaborativo);
      expect(PlanRules.normalize('colaborativo'), PlanRules.colaborativo);
      expect(PlanRules.normalize('familia'), PlanRules.colaborativo);
      expect(PlanRules.normalize('vip'), PlanRules.colaborativo);
      expect(PlanRules.normalize('pro'), PlanRules.colaborativo);
    });

    test('normalizes accented and mojibake plan labels', () {
      expect(PlanRules.normalize('Básico'), PlanRules.basico);
      expect(PlanRules.normalize('BÃ¡sico'), PlanRules.basico);
      expect(
        PlanRules.normalize('BÃƒÂ¡sico'),
        PlanRules.basico,
      );
      expect(PlanRules.normalize('Avançado'), PlanRules.avancado);
      expect(PlanRules.normalize('Intermediário'), PlanRules.avancado);
      expect(PlanRules.normalize('Colaborativo!'), PlanRules.colaborativo);
      expect(PlanRules.normalize('Família'), PlanRules.colaborativo);
      expect(PlanRules.normalize('FamÃ­lia'), PlanRules.colaborativo);
      expect(
        PlanRules.normalize('FamÃƒÂ­lia'),
        PlanRules.colaborativo,
      );
      expect(PlanRules.normalize('Premium!'), PlanRules.colaborativo);
    });
  });

  group('PlanRules validity', () {
    test('accepts known aliases and rejects unknown labels', () {
      expect(PlanRules.isValid('gratis'), isTrue);
      expect(PlanRules.isValid('individual'), isTrue);
      expect(PlanRules.isValid('plus'), isTrue);
      expect(PlanRules.isValid('family'), isTrue);
      expect(PlanRules.isValid(''), isFalse);
      expect(PlanRules.isValid('   '), isFalse);
      expect(PlanRules.isValid('desconhecido'), isFalse);
    });

    test('displayName returns human-readable names', () {
      expect(PlanRules.displayName(PlanRules.gratuito), 'Gratuito');
      expect(PlanRules.displayName(PlanRules.basico), 'Básico');
      expect(PlanRules.displayName(PlanRules.avancado), 'Avançado');
      expect(PlanRules.displayName(PlanRules.colaborativo), 'Colaborativo');
    });
  });

  group('PlanRules permissions', () {
    test('personal agenda only is true for gratuito, basico and avancado',
        () {
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.gratuito), isTrue);
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.basico), isTrue);
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.avancado), isTrue);
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.colaborativo), isFalse);
    });

    test('full access is true only for colaborativo', () {
      expect(PlanRules.hasFullAccess(PlanRules.gratuito), isFalse);
      expect(PlanRules.hasFullAccess(PlanRules.basico), isFalse);
      expect(PlanRules.hasFullAccess(PlanRules.avancado), isFalse);
      expect(PlanRules.hasFullAccess(PlanRules.colaborativo), isTrue);
    });

    test('cloud backup is true only for avancado and colaborativo', () {
      expect(PlanRules.hasCloudBackup(PlanRules.gratuito), isFalse);
      expect(PlanRules.hasCloudBackup(PlanRules.basico), isFalse);
      expect(PlanRules.hasCloudBackup(PlanRules.avancado), isTrue);
      expect(PlanRules.hasCloudBackup(PlanRules.colaborativo), isTrue);
    });
  });
}
