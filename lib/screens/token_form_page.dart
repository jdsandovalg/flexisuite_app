import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:html' as html; // Import for web-specific download
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_state.dart';
import 'package:url_launcher/url_launcher.dart';

class TokenFormPage extends StatefulWidget {
  const TokenFormPage({Key? key}) : super(key: key);

  @override
  _TokenFormPageState createState() => _TokenFormPageState();
}

class _TokenFormPageState extends State<TokenFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Campos del formulario
  String _tokenType = 'Individual';
  String _name = '';
  String _cui = '';
  List<String> _services = [];
  int _validityHours = 6;
  TimeOfDay? _recurrentStart;
  TimeOfDay? _recurrentEnd;
  DateTime? _recurrentStartDate;
  DateTime? _recurrentEndDate;
  String? _selectedServiceCategory;

  List<dynamic> _tokens = []; // Lista de tokens creados
  bool _isLoading = true;

  // Servicios básicos actualizados
  final Map<String, List<String>> serviceCategories = {
    'Servicios de Telefonía': ['Tigo', 'Claro'], 
    'Servicios de Energía/Agua Municipal': ['Energuate', 'Empresa Eléctrica','Agua Municipal'],
  };

  @override
  void initState() {
    super.initState();
    _fetchTokens();
  }

  Future<void> _fetchTokens() async {
    final user = AppState.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client.rpc(
        'get_tokens_json',
        params: {'p_user_id': user.id},
      );

      if (response == null || response is! List) {
        setState(() {
          _tokens = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _tokens = response as List<dynamic>;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching tokens: $error');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los tokens: $error')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  void showQR(String token) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('QR del Token'),
        content: QrImageView(
          data: token,
          version: QrVersions.auto,
          size: 180.0,
          embeddedImage: const AssetImage('assets/logo.png'),
          embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(24, 24)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void copyToken(String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token copiado al portapapeles')));
  }

  Future<void> _shareToken(Map<String, dynamic> tokenData) async {
    try {
      setState(() => _isLoading = true); // Mostrar indicador de carga

      // 1. Construir el mensaje de texto
      final guestName = tokenData['guest_name'] ?? tokenData['event_name'] ?? 'N/A';
      final tokenCode = tokenData['token_code'] ?? 'N/A';
      final startDate = tokenData['formatted_start_date'] ?? 'N/A';
      final endDate = tokenData['formatted_end_date'] ?? 'N/A';

      final text = '''
Hola, te comparto los detalles de tu token de acceso:

*Invitado:* $guestName
*Token:* $tokenCode
*Válido desde:* $startDate
*Válido hasta:* $endDate
''';

      // 2. Generar y descargar la imagen del QR
      final logoBytes = await rootBundle.load('assets/logo.png');
      final codec = await ui.instantiateImageCodec(logoBytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final logoImage = frame.image;

      final qrPainter = QrPainter(
        data: tokenCode,
        version: QrVersions.auto,
        embeddedImage: logoImage,
        embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
      );

      final picData = await qrPainter.toImageData(200, format: ui.ImageByteFormat.png);
      final bytes = picData!.buffer.asUint8List();
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "qr_token.png")
        ..click();
      html.Url.revokeObjectUrl(url);

      // 3. Abrir WhatsApp con el texto pre-cargado
      final encodedMessage = Uri.encodeComponent(text);
      final whatsappUrl = Uri.parse('https://wa.me/?text=$encodedMessage');
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);

    } catch (e) {
      print('Error al preparar datos para compartir: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al preparar datos para compartir: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Ocultar indicador de carga
      }
    }
  }

  Future<void> saveToken() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final user = AppState.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Usuario no autenticado')));
        return;
      }

      final params = {
        'p_organization_id': user.organizationId,
        'p_user_id': user.id,
        'p_token_type': _tokenType,
        'p_guest_id': _tokenType == 'Servicios Básicos' ? _name : _cui,
        'p_guest_name': _name,
        'p_is_recurring': _tokenType == 'Recurrente',
        'p_daily_start': _recurrentStart != null ? '${_recurrentStart!.hour}:${_recurrentStart!.minute}' : null,
        'p_daily_end': _recurrentEnd != null ? '${_recurrentEnd!.hour}:${_recurrentEnd!.minute}' : null,
        'p_recurring_start_date': _recurrentStartDate?.toIso8601String(),
        'p_recurring_end_date': _recurrentEndDate?.toIso8601String(),
        'p_validity_hours': _tokenType == 'Individual' || _tokenType == 'Servicios Básicos' ? _validityHours : null,
        'p_max_accesses': 1,
        'p_event_name': _tokenType == 'Eventos' ? 'Nombre del Evento' : null,
      };

      try {
        await Supabase.instance.client.rpc('create_token_1a1', params: params);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token guardado exitosamente')));
        _fetchTokens(); // refresca la lista
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al guardar el token')));
        print('Error al guardar el token: $e');
      }
    }
  }

  ButtonStyle _getButtonStyle(bool isSelected) {
    return ElevatedButton.styleFrom(
      backgroundColor: isSelected ? Colors.blueAccent : Colors.grey[300],
      foregroundColor: isSelected ? Colors.white : Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  Widget _buildTokenTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['Individual', 'Servicios Básicos', 'Recurrente', 'Eventos'].map((type) {
        bool isSelected = _tokenType == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              onPressed: type == 'Eventos' ? null : () => setState(() => _tokenType = type),
              style: _getButtonStyle(isSelected),
              child: Text(type, textAlign: TextAlign.center),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildValiditySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [6, 12, 18, 24].map((hours) {
        bool isSelected = _validityHours == hours;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              onPressed: () => setState(() => _validityHours = hours),
              style: _getButtonStyle(isSelected),
              child: Text('$hours horas', textAlign: TextAlign.center),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServiceCategorySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: serviceCategories.keys.map((category) {
        bool isSelected = _selectedServiceCategory == category;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              onPressed: () => setState(() => _selectedServiceCategory = category),
              style: _getButtonStyle(isSelected),
              child: Text(category, textAlign: TextAlign.center),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServiceSelector(String category) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: serviceCategories[category]!.map((service) {
        bool isSelected = _services.contains(service);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _services = [service]; // Mutually exclusive
                });
              },
              style: _getButtonStyle(isSelected),
              child: Text(service, textAlign: TextAlign.center),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getCardColor(String? statusColor) {
    switch (statusColor) {
      case 'green':
        return Colors.green.shade50;
      case 'orange':
        return Colors.orange.shade50;
      case 'yellow':
        return Colors.yellow.shade50;
      case 'red':
        return Colors.red.shade50;
      case 'gray':
        return Colors.grey.shade50;
      default:
        return Colors.white; // Color por defecto si el status es nulo o no reconocido
    }
  }
  Widget _buildTokenGrid() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_tokens.isEmpty) return const Center(child: Text('No hay tokens creados'));

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
          ),
          itemCount: _tokens.length,
          itemBuilder: (context, index) {
            final token = _tokens[index];

            String createdAt = 'N/A';
            String startDate = 'N/A';
            String endDate = 'N/A';

            if (token['created_at'] != null) {
              createdAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(token['created_at']));
            }

            if (token['is_recurring'] == true) {
              startDate = token['recurring_start_date'] != null
                  ? DateFormat('dd/MM/yyyy').format(DateTime.parse(token['recurring_start_date'])) + ' ${token['daily_start'] ?? ''}'
                  : 'N/A';
              endDate = token['recurring_end_date'] != null
                  ? DateFormat('dd/MM/yyyy').format(DateTime.parse(token['recurring_end_date'])) + ' ${token['daily_end'] ?? ''}'
                  : 'N/A';

            } else {
              if (token['created_at'] != null) {
                final startDateTime = DateTime.parse(token['created_at'] as String);
                startDate = DateFormat('dd/MM/yyyy HH:mm').format(startDateTime);
                final validityHours = token['validity_hours'] as int? ?? 0;
                if (validityHours > 0) {
                  final endDateTime = startDateTime.add(Duration(hours: validityHours));
                  endDate = DateFormat('dd/MM/yyyy HH:mm').format(endDateTime);
                } else {
                  endDate = 'N/A';
                }
              }
            }

            // Guardar las fechas formateadas para usarlas en WhatsApp
            token['formatted_start_date'] = startDate;
            token['formatted_end_date'] = endDate;

            final cardColor = _getCardColor(token['status_color'] as String?);

            return Card(
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: QrImageView(
                        data: token['token_code'],
                        version: QrVersions.auto,
                        size: 180.0,
                        embeddedImage: const AssetImage('assets/logo.png'),
                        embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(24, 24)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      token['token_code'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      token['guest_name'] ?? token['event_name'] ?? 'N/A',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'CUI: ${token['guest_id'] ?? 'N/A'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      token['token_type'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Creado: $createdAt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Inicio: $startDate',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Fin: $endDate',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => copyToken(token['token_code']),
                        ),
                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.whatsapp),
                          onPressed: () => _shareToken(token),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Tokens de Ingreso')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTokenTypeSelector(),
                      const SizedBox(height: 20),
                      if (_tokenType == 'Individual') ...[
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Nombre del invitado',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                          onSaved: (val) => _name = val!,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'CUI (DPI)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                          onSaved: (val) => _cui = val!,
                        ),
                        const SizedBox(height: 10),
                        _buildValiditySelector(),
                      ],
                      if (_tokenType == 'Servicios Básicos') ...[
                        _buildServiceCategorySelector(),
                        if (_selectedServiceCategory != null) ...[
                          const SizedBox(height: 10),
                          _buildServiceSelector(_selectedServiceCategory!),
                        ],
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Nombre del contacto',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                          onSaved: (val) => _name = val!,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_tokenType == 'Recurrente') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Nombre del contacto',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                          onSaved: (val) => _name = val!,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'CUI (DPI)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                          onSaved: (val) => _cui = val!,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: InputDatePickerFormField(
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                fieldLabelText: 'Fecha inicio',
                                initialDate: _recurrentStartDate ?? DateTime.now(),
                                onDateSaved: (val) => _recurrentStartDate = val,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InputDatePickerFormField(
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                fieldLabelText: 'Fecha fin',
                                initialDate: _recurrentEndDate ?? DateTime.now(),
                                onDateSaved: (val) => _recurrentEndDate = val,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Hora inicio',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                                onTap: () async {
                                  TimeOfDay? time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (time != null) setState(() => _recurrentStart = time);
                                },
                                controller: TextEditingController(
                                    text: _recurrentStart?.format(context) ?? ''),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Hora fin',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                                onTap: () async {
                                  TimeOfDay? time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (time != null) setState(() => _recurrentEnd = time);
                                },
                                controller: TextEditingController(
                                    text: _recurrentEnd?.format(context) ?? ''),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: saveToken,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                          child: Text('Guardar Token', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                const Divider(height: 30),
                const Text(
                  'Tokens Creados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildTokenGrid(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
