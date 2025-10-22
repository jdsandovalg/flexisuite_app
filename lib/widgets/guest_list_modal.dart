import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class GuestListModal extends StatefulWidget {
  final List<Map<String, String>> guests;
  final Function(List<Map<String, String>>) onConfirm;

  const GuestListModal({super.key, required this.guests, required this.onConfirm});

  @override
  State<GuestListModal> createState() => _GuestListModalState();
}

class _GuestListModalState extends State<GuestListModal> {
  late List<Map<String, String>> _localGuests;

  @override
  void initState() {
    super.initState();
    // Creamos una copia local para poder editarla sin afectar el estado original hasta confirmar.
    _localGuests = List<Map<String, String>>.from(widget.guests.map((g) => Map<String, String>.from(g)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AppBackground( // Envolvemos con el fondo de la app
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Añadimos padding
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Lista de Invitados', style: theme.textTheme.titleLarge),
                const Divider(height: 20),
                if (_localGuests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48.0),
                    child: Text('No hay invitados en la lista.'),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _localGuests.length,
                      itemBuilder: (context, index) {
                        final guest = _localGuests[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(guest['NombreCompleto'] ?? 'Sin Nombre'),
                          subtitle: Text('ID: ${guest['Identificacion'] ?? 'N/A'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showEditGuestDialog(index: index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() {
                                    _localGuests.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FloatingActionButton(
                      onPressed: () => _showEditGuestDialog(),
                      mini: true,
                      child: const Icon(Icons.add),
                    ),
                    IconButton(
                      onPressed: _pickAndParseCsv,
                      icon: const Icon(Icons.upload_file),
                      tooltip: 'Cargar desde CSV',
                    ),
                    const Spacer(), // Ocupa el espacio disponible en el medio
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        widget.onConfirm(_localGuests);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditGuestDialog({int? index}) {
    final isEditing = index != null;
    // Si estamos añadiendo un nuevo invitado, usamos los valores de ejemplo.
    final guest = isEditing
        ? _localGuests[index]
        : {'Identificacion': '000-00000-0000', 'NombreCompleto': 'Invitado ${_localGuests.length + 1}'};
    
    final idController = TextEditingController(text: guest['Identificacion']);
    final nameController = TextEditingController(text: guest['NombreCompleto']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Invitado' : 'Añadir Invitado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idController, decoration: const InputDecoration(labelText: 'Identificación')),
            const SizedBox(height: 8),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre Completo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final newGuest = {
                  'Identificacion': idController.text,
                  'NombreCompleto': nameController.text,
                };
                if (isEditing) {
                  _localGuests[index] = newGuest;
                } else {
                  _localGuests.add(newGuest);
                }
              });
              Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndParseCsv() async {
    try {
      // Abrimos el selector de archivos para que el usuario elija un CSV.
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // Asegura que los bytes del archivo se carguen en memoria.
      );

      if (result != null && result.files.first.bytes != null) {
        final bytes = result.files.first.bytes!;
        final csvString = utf8.decode(bytes);
        final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter(eol: '\n').convert(csvString);

        // Asumimos que la primera fila es el encabezado y la ignoramos.
        final guestsFromCsv = rowsAsListOfValues.skip(1).map((row) {
          return {
            'Identificacion': row[0].toString(),
            'NombreCompleto': row[1].toString(),
          };
        }).toList();

        setState(() {
          _localGuests.addAll(guestsFromCsv);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar el archivo CSV: $e')),
      );
      }
    }
  }
}
