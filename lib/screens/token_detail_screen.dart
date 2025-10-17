import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';
import '../models/app_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class TokenDetailScreen extends StatelessWidget {
  final Map<String, dynamic> tokenData;

  const TokenDetailScreen({super.key, required this.tokenData});

  Future<void> _shareToken(BuildContext context) async {
    try {
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

      final logoBytes = await rootBundle.load('web/favicon.png');
      final codec = await ui.instantiateImageCodec(logoBytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final logoImage = frame.image;

      final qrPainter = QrPainter(
        data: tokenCode,
        version: QrVersions.auto,
        embeddedImage: logoImage,
        embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(60, 60)),
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      final picData = await qrPainter.toImageData(400, format: ui.ImageByteFormat.png);
      final bytes = picData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/qr_token_share.png';
      final File imageFile = File(imagePath);
      await imageFile.writeAsBytes(bytes);

      // Solución para el error en iPad: especificamos el origen del popover.
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: text,
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al preparar datos para compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Leemos el parámetro desde el estado global de la aplicación.
    final bool allowQrCodeDisplay = AppState.organizationParameters['ALLOW_QR_CODE_DISPLAY'] ?? false;

    final guestName = tokenData['guest_name'] ?? tokenData['event_name'] ?? 'N/A';
    final tokenCode = tokenData['token_code'] ?? 'N/A';
    final startDate = tokenData['formatted_start_date'] ?? 'N/A';
    final endDate = tokenData['formatted_end_date'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(guestName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(guestName, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Válido de $startDate a $endDate', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  QrImageView(
                    data: tokenCode,
                    version: QrVersions.auto,
                    size: 250.0,
                    embeddedImage: const AssetImage('web/favicon.png'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(50, 50)),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    tokenCode,
                    style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,                    
                    child: Builder( // Usamos un Builder para obtener el contexto específico del botón.
                      builder: (buttonContext) {
                        return ElevatedButton(
                          // El botón solo se habilita si la visualización de QR está permitida.
                          onPressed: allowQrCodeDisplay
                              ? () => _shareToken(buttonContext)
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min, // Para que la fila ocupe solo el espacio necesario
                            children: const [
                              Icon(Icons.share),
                              SizedBox(width: 8), // Espacio entre el icono y el texto
                              Text('Compartir Token'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
