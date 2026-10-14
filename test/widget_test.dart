import 'package:flutter_test/flutter_test.dart';

import 'package:cultivos_molina/models/models.dart';

void main() {
  group('Variedad', () {
    test('fromString reconoce cada variedad', () {
      for (final v in Variedad.values) {
        expect(VariedadExt.fromString(v.name), v);
      }
    });

    test('fromString usa batavia por defecto', () {
      expect(VariedadExt.fromString('desconocida'), Variedad.batavia);
    });
  });

  group('CausaPerdida', () {
    test('fromString usa manipulacion por defecto', () {
      expect(CausaExt.fromString('otra'), CausaPerdida.manipulacion);
    });
  });

  group('LoteModel', () {
    test('dos instancias con el mismo id son iguales', () {
      const a = LoteModel(id: 'l1', nombre: 'Lote 1', areaM2: 100, activo: true);
      const b = LoteModel(id: 'l1', nombre: 'Lote 1 editado', areaM2: 200, activo: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('VentaModel', () {
    test('toMap calcula el total como cantidad x precio', () {
      final venta = VentaModel(
        id: '',
        usuarioId: 'u1',
        variedad: Variedad.romana,
        cliente: 'Cliente',
        cantidadKg: 10,
        precioKg: 2500,
        total: 0,
        fecha: DateTime(2026, 1, 1),
      );
      expect(venta.toMap()['total'], 25000);
    });
  });
}
