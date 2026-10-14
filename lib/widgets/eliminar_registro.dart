import 'package:flutter/material.dart';

// Botón de papelera para que el operario borre un registro propio
// cuando se equivocó. Pide confirmación antes de eliminar.
class EliminarRegistroButton extends StatelessWidget {
  final String descripcion;
  final Future<void> Function() onEliminar;

  const EliminarRegistroButton({
    super.key,
    required this.descripcion,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
      tooltip: 'Eliminar registro',
      visualDensity: VisualDensity.compact,
      onPressed: () => _confirmar(context),
    );
  }

  Future<void> _confirmar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Seguro que quieres eliminar este registro?\n\n$descripcion\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB22222)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await onEliminar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Registro eliminado'), backgroundColor: Color(0xFF2D5A3D)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
