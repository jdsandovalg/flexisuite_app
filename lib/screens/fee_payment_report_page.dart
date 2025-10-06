import 'dart:typed_data';
import 'package:flexisuite_shared/flexisuite_shared.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import 'package:file_picker/file_picker.dart';

class FeePaymentReportPage extends StatefulWidget {
  const FeePaymentReportPage({Key? key}) : super(key: key);

  @override
  _FeePaymentReportPageState createState() => _FeePaymentReportPageState();
}

class _FeePaymentReportPageState extends State<FeePaymentReportPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _feeCharges = [];
  
  // Estado para el filtro de cuotas
  int _selectedFilterIndex = 0; // 0: Pendientes, 1: Historial

  @override
  void initState() {
    super.initState();
    _fetchFeeCharges();
  }

  Future<void> _fetchFeeCharges() async {
    final user = AppState.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'mark_and_list_fee_charges_resident',
        params: {
          'p_user_id': user.id,
          'p_organization_id': user.organizationId, // Añadimos el ID de la organización
        },
      );

      if (mounted) {
        final charges = List<Map<String, dynamic>>.from(response);
        // Agrupar y ordenar: pendientes primero, luego pagadas. Ambas de la más vieja a la más nueva.
        charges.sort((a, b) {
          final statusA = a['status'] == 'pending' ? 0 : 1;
          final statusB = b['status'] == 'pending' ? 0 : 1;
          if (statusA != statusB) return statusA.compareTo(statusB);
          return DateTime.parse(a['charge_date']).compareTo(DateTime.parse(b['charge_date']));
        });
        setState(() {
          _feeCharges = charges;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching fee charges: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar las cuotas: $error')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showReportPaymentDialog(Map<String, dynamic> charge) {
    showDialog(
      context: context,
      builder: (context) => ReportPaymentDialog(
        isEditing: charge['payment_image'] != null, // Indica si estamos editando un reporte existente
        charge: charge,
        onReported: () {
          _fetchFeeCharges(); // Refrescar la lista después de reportar
        },
      ),
    );
  }

  void _showPaymentImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(8),
        content: Image.network(
          imageUrl,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Text('No se pudo cargar la imagen.'),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar'))],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Mantenemos el fondo del Scaffold transparente
      body: AppBackground(
        child: Stack( // Usamos un Stack para superponer el título y el botón de atrás
          children: [
            // El contenido principal de la pantalla
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          // Dejamos un espacio en la parte superior para el título y el botón
                          const SizedBox(height: 80), 
                          FilterStrip(
                            options: const ['Pendientes', 'Historial'],
                            selectedIndex: _selectedFilterIndex,
                            onSelected: (index) {
                              setState(() {
                                _selectedFilterIndex = index;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: _buildFeeGrid()),
                        ],
                      ),
              ),
            ),
            // Título y botón de atrás superpuestos
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Text(
                      'Estado de Cuenta y Pagos',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 48), // Espacio para balancear el IconButton
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeGrid() {
    final filteredCharges = _selectedFilterIndex == 0
        ? _feeCharges.where((c) => c['status'] == 'pending').toList()
        : _feeCharges.where((c) => c['status'] != 'pending').toList();

    if (filteredCharges.isEmpty) {
      return Center(
        child: Text(_selectedFilterIndex == 0
            ? 'No tienes cuotas pendientes.'
            : 'No hay historial de cuotas.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 2 ? 2.5 : 2.0,
          ),
          itemCount: filteredCharges.length,
          itemBuilder: (context, index) {
            final charge = filteredCharges[index];
            return _buildFeeCard(charge);
          },
        );
      },
    );
  }

  Widget _buildFeeCard(Map<String, dynamic> charge) {
    final status = charge['status'] as String? ?? 'pending';
    final feeName = charge['fee_name'] as String? ?? 'Cuota';
    final amount = (charge['amount'] as num? ?? 0.0).toStringAsFixed(2);
    final chargeDate = charge['charge_date'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(charge['charge_date']))
        : 'N/A';
    final hasPaymentReport = charge['payment_image'] != null;
    final paymentImageUrl = charge['payment_image'] as String?;

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '$feeName - Q$amount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const Divider(height: 16),
          Text('Fecha de cargo: $chargeDate'),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasPaymentReport) ...[
                if (paymentImageUrl != null)
                  TextButton.icon(
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Ver'),
                    onPressed: () => _showPaymentImage(paymentImageUrl),
                  ),
                ElevatedButton.icon(
                  // Desactivar el botón si el estado es 'paid'
                  onPressed: status == 'paid' ? null : () => _showReportPaymentDialog(charge),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
              ] else if (status == 'pending')
                ElevatedButton(
                  onPressed: () => _showReportPaymentDialog(charge),
                  child: const Text('Reportar Pago'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'paid':
        color = Colors.green.withOpacity(0.2);
        label = 'Pagado';
        break;
      case 'overdue':
        color = Colors.red.withOpacity(0.2);
        label = 'Vencido';
        break;
      case 'pending':
      default:
        color = Colors.orange.withOpacity(0.2);
        label = 'Pendiente';
        break;
    }
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class ReportPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> charge;
  final VoidCallback onReported;
  final bool isEditing;

  const ReportPaymentDialog({
    Key? key,
    required this.charge,
    required this.onReported,
    this.isEditing = false,
  }) : super(key: key);

  @override
  _ReportPaymentDialogState createState() => _ReportPaymentDialogState();
}

class _ReportPaymentDialogState extends State<ReportPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  DateTime? _paymentDate;
  Uint8List? _paymentImageBytes;
  String? _paymentImageName;
  String? _selectedBankId;
  List<Map<String, dynamic>> _banks = [];
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.first.bytes != null) {
        setState(() {
          _paymentImageBytes = result.files.first.bytes!;
          _paymentImageName = result.files.first.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar la imagen: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Si estamos editando, no necesitamos la fecha ni los bancos.
    if (!widget.isEditing) {
      _paymentDate = DateTime.now(); // Establecer la fecha de hoy por defecto
      _fetchBanks();
    } else {
      _notesController.text = widget.charge['notes'] ?? '';
    }
  }

  Future<void> _fetchBanks() async {
    final user = AppState.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client.rpc(
        'get_banks_for_organization',
        params: {'p_organization_id': user.organizationId},
      );
      if (mounted) {
        setState(() {
          _banks = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error fetching banks: $e');
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paymentImageBytes == null) { // Siempre se requiere una imagen al editar o crear.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe adjuntar una imagen del comprobante.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = AppState.currentUser!;
      final chargeId = widget.charge['charge_id'];
      String? imageUrl;

      // Si se seleccionó una nueva imagen, súbela.
      if (_paymentImageBytes != null && _paymentImageName != null) {
        // 1. Si estamos editando, primero borra la imagen anterior.
        final oldImageUrl = widget.charge['payment_image'] as String?;
        if (widget.isEditing && oldImageUrl != null && oldImageUrl.isNotEmpty) {
          try {
            // Forma más robusta de extraer la ruta del archivo desde la URL pública
            const bucketName = 'payment_proofs';
            final uri = Uri.parse(oldImageUrl);
            final pathIndex = uri.pathSegments.lastIndexOf(bucketName);
            if (pathIndex != -1 && pathIndex + 1 < uri.pathSegments.length) {
              final filePathToRemove = uri.pathSegments.sublist(pathIndex + 1).join('/');
              await Supabase.instance.client.storage.from(bucketName).remove([filePathToRemove]);
            }
          } catch (e) {
            print("Advertencia: No se pudo borrar la imagen anterior. Puede que no existiera. Error: $e");
          }
        }

        // 2. Sube la nueva imagen.
        final fileExt = _paymentImageName!.split('.').last;
        final filePath = 'payment_proofs/${user.id}/${chargeId}.$fileExt';
      
      try {
        await Supabase.instance.client.storage.from('payment_proofs').uploadBinary(
              filePath,
              _paymentImageBytes!,
              fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExt'),
            );
      } on StorageException catch (e) {
        // Captura errores específicos de Storage, como "Bucket not found".
        if (e.message.contains('security policies')) {
          throw Exception('Error de seguridad: No tienes permiso para subir este archivo. Revisa las políticas del bucket.');
        } else {
          throw Exception('Error de almacenamiento: ${e.message}. Asegúrate de que el bucket "payment_proofs" exista.');
        }
      }

        imageUrl = Supabase.instance.client.storage.from('payment_proofs').getPublicUrl(filePath);
      } else {
        // Si no se subió una nueva imagen, mantenemos la existente.
        imageUrl = widget.charge['payment_image'] as String?;
      }

      // 3. Llamar a la función RPC para actualizar/crear el reporte de pago.
      await Supabase.instance.client.rpc(
        'report_fee_payment', // Usamos la nueva función RPC
        params: {
          'p_charge_id': chargeId,
          'p_payment_date': widget.isEditing ? widget.charge['payment_date'] : _paymentDate!.toIso8601String(),
          'p_payment_image': imageUrl,
          'p_notes': _notesController.text,
          'p_bank_id': widget.isEditing ? widget.charge['bank_id'] : _selectedBankId,
        }
      );

      if (mounted) {
        Navigator.of(context).pop(); // Cerrar el diálogo
        widget.onReported(); // Notificar a la página principal para que refresque
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu comprobante fue enviado. Administración validará tu pago.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      print('Error submitting report: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error al enviar el reporte: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reemplazamos AlertDialog por un Dialog personalizado para aplicar el tema.
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassCard(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Editar Reporte de Pago' : 'Reportar Pago',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                // Solo mostrar campos de fecha y banco si NO estamos editando
                if (!widget.isEditing) ...[
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Pago',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text: _paymentDate == null
                          ? ''
                          : DateFormat('dd/MM/yyyy').format(_paymentDate!),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(), // No se puede seleccionar una fecha futura
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _paymentDate = pickedDate;
                        });
                      }
                    },
                    validator: (value) => _paymentDate == null ? 'La fecha es obligatoria' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true, // Evita el desbordamiento de texto largo.
                    value: _selectedBankId,
                    decoration: const InputDecoration(labelText: 'Banco Destino', border: OutlineInputBorder()),
                    items: _banks.map((bank) {
                      final bankName = bank['bank_name'] ?? 'N/A';
                      final accountNumber = bank['account_number'] ?? 'N/A';
                      return DropdownMenuItem(
                        value: bank['bank_id'] as String,
                        child: Text('$bankName - $accountNumber', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBankId = val),
                    validator: (v) => v == null ? 'Debe seleccionar un banco' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.attach_file),
                      label: Text(widget.isEditing ? 'Cambiar Imagen' : 'Adjuntar Imagen'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _paymentImageName ?? 'Ningún archivo seleccionado',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (Opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(widget.isEditing ? 'Actualizar' : 'Enviar'),
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
}