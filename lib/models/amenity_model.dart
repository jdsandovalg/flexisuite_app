import 'package:flutter/material.dart';

class Amenity {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final int? capacity;
  final int includedHours;
  final double pricePerBase;
  final double? pricePerExtraHour;
  final String? locationId;
  final String amenityType;
  final String feeId;
  final TimeOfDay? availableFromTime;
  final TimeOfDay? availableToTime;

  Amenity({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    this.capacity,
    required this.includedHours,
    required this.pricePerBase,
    this.pricePerExtraHour,
    this.locationId,
    required this.amenityType,
    required this.feeId,
    this.availableFromTime,
    this.availableToTime,
  });

  static TimeOfDay? _parseTime(String? timeString) {
    if (timeString == null) return null;
    try {
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }
  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      id: json['amenity_id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      capacity: json['capacity'] as int?,
      includedHours: json['included_hours'] as int,
      // Convertimos los valores numéricos de forma segura
      pricePerBase: (json['price_per_base'] as num?)?.toDouble() ?? 0.0,
      pricePerExtraHour: (json['price_per_extra_hour'] as num?)?.toDouble(),
      locationId: json['location_id'] as String?,
      amenityType: json['amenity_type'] as String? ?? 'otro',
      feeId: json['fee_id'] as String,
      availableFromTime: _parseTime(json['available_from_time'] as String?),
      availableToTime: _parseTime(json['available_to_time'] as String?),
    );
  }

  String get formattedPrice {
    final priceString = pricePerBase.toStringAsFixed(2);
    return 'Desde Q$priceString';
  }

  String? get formattedUnavailableHours {
    if (availableFromTime == null || availableToTime == null) {
      return null;
    }
    final from = '${availableFromTime!.hour.toString().padLeft(2, '0')}:${availableFromTime!.minute.toString().padLeft(2, '0')}';
    final to = '${availableToTime!.hour.toString().padLeft(2, '0')}:${availableToTime!.minute.toString().padLeft(2, '0')}';
    return 'Disponible de $from a $to';
  }
}
