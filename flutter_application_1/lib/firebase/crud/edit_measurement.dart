import 'package:flutter/material.dart';
import 'measurement.dart';

class EditMeasurementDialog extends StatefulWidget {
  final Measurement measurement;
  final Function(Measurement) onSave;

  const EditMeasurementDialog({
    super.key,
    required this.measurement,
    required this.onSave,
  });

  @override
  State<EditMeasurementDialog> createState() => _EditMeasurementDialogState();
}

class _EditMeasurementDialogState extends State<EditMeasurementDialog> {
  late TextEditingController _kwhController;
  late TextEditingController _teganganController;
  late TextEditingController _arusController;
  late TextEditingController _perangkatController;
  late String _status;

  @override
  void initState() {
    super.initState();
    _kwhController = TextEditingController(text: widget.measurement.kwh.toString());
    _teganganController = TextEditingController(text: widget.measurement.tegangan.toString());
    _arusController = TextEditingController(text: widget.measurement.arus.toString());
    _perangkatController = TextEditingController(text: widget.measurement.perangkat);
    _status = widget.measurement.status;
  }

  @override
  void dispose() {
    _kwhController.dispose();
    _teganganController.dispose();
    _arusController.dispose();
    _perangkatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Pengukuran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _kwhController,
              decoration: const InputDecoration(labelText: 'kWh'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _teganganController,
              decoration: const InputDecoration(labelText: 'Tegangan (V)'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _arusController,
              decoration: const InputDecoration(labelText: 'Arus (A)'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _perangkatController,
              decoration: const InputDecoration(labelText: 'Perangkat'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'warning', child: Text('Peringatan')),
                DropdownMenuItem(value: 'error', child: Text('Error')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () {
            final updated = widget.measurement.copyWith(
              kwh: double.tryParse(_kwhController.text) ?? widget.measurement.kwh,
              tegangan: double.tryParse(_teganganController.text) ?? widget.measurement.tegangan,
              arus: double.tryParse(_arusController.text) ?? widget.measurement.arus,
              perangkat: _perangkatController.text,
              status: _status,
              // tanggal bisa di-update jika mau, tapi biasanya tidak
            );
            widget.onSave(updated);
            Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}