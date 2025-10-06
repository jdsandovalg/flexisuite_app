class UserModel {
  final String id;
  final String name;
  final String role;
  final String organizationId;
  final String organizationName; // New field
  final String? locationId; // New field for user's location

  UserModel({required this.id, required this.name, required this.role, required this.organizationId, required this.organizationName, this.locationId});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: '${json['first_name'] as String? ?? ''} ${json['last_name'] as String? ?? ''}'.trim(),
      role: json['role'] as String? ?? 'Rol desconocido',
      organizationId: json['organization_id'] as String? ?? '',
      organizationName: json['organization_name'] as String? ?? '', // New field
      locationId: json['location_id'] as String?, // New field
    );
  }
}

class AppState {
  static UserModel? currentUser;
  // Mapa para almacenar parámetros de la organización (ej: {'ALLOW_QR_CODE_DISPLAY': false})
  static Map<String, dynamic> organizationParameters = {};
  // Lista para almacenar las características del plan del usuario.
  static List<Map<String, dynamic>> userFeatures = [];
  // Zona horaria de la organización (ej: 'America/Guatemala')
  static String organizationTimeZone = 'UTC'; // Valor por defecto
}