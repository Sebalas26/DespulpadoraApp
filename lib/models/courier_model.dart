/// Modelo que representa al mensajero/domiciliario autenticado
class CourierModel {
  final String id;
  final String nombre;
  final String placaVehiculo;
  final String telefono;
  final String email;
  final String? token;
  final bool isOnline;

  CourierModel({
    required this.id,
    required this.nombre,
    required this.placaVehiculo,
    required this.telefono,
    required this.email,
    this.token,
    this.isOnline = false,
  });

  factory CourierModel.fromJson(Map<String, dynamic> json) {
    return CourierModel(
      id: json['id'] ?? json['courierId'] ?? '',
      nombre: json['nombre'] ?? json['courierName'] ?? json['name'] ?? '',
      placaVehiculo: json['placaVehiculo'] ?? json['placa_vehiculo'] ?? json['vehiclePlate'] ?? '',
      telefono: json['telefono'] ?? json['phone'] ?? '',
      email: json['email'] ?? '',
      token: json['token'],
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'placaVehiculo': placaVehiculo,
      'telefono': telefono,
      'email': email,
      'token': token,
      'isOnline': isOnline,
    };
  }

  CourierModel copyWith({
    String? id,
    String? nombre,
    String? placaVehiculo,
    String? telefono,
    String? email,
    String? token,
    bool? isOnline,
  }) {
    return CourierModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      placaVehiculo: placaVehiculo ?? this.placaVehiculo,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      token: token ?? this.token,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
