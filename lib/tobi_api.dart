import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TobiAPI {
  final String? apiKey = dotenv.env['OPENAI_API_KEY'];

  // Función para enviar un prompt a Tobi y obtener la respuesta
  Future<String> askTobi(String prompt) async {
    if (apiKey == null) {
      throw Exception("API Key no encontrada. Revisá tu archivo .env");
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "gpt-5-mini",
          "messages": [
            {"role": "user", "content": prompt}
          ]
        }));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Error en OpenAI: ${response.body}');
    }
  }
}
