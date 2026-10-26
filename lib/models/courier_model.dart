/// Modelo que representa al domiciliario autenticado en la aplicación móvil.
class CourierModel {
  /// Identificador único del domiciliario en el sistema.
  final String id;

  /// Nombre completo del domiciliario.
  final String nombre;

  /// Placa del vehículo asignado al domiciliario.
  final String placaVehiculo;

  /// Número telefónico de contacto del domiciliario.
  final String telefono;

  /// Correo electrónico del domiciliario.
  final String email;

  /// Token JWT de sesión para peticiones autenticadas.
  final String? token;

  /// Indica si el domiciliario se encuentra activo en turno.
  final bool isOnline;

  /// Crea una nueva instancia de [CourierModel].
  CourierModel({
    required this.id,
    required this.nombre,
    required this.placaVehiculo,
    required this.telefono,
    required this.email,
    this.token,
    this.isOnline = false,
  });

  /// Construye una instancia de [CourierModel] a partir de un mapa JSON del backend o almacenamiento local.
  factory CourierModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['courierId'] ?? json['id'];
    return CourierModel(
      id: rawId != null ? rawId.toString() : '',
      nombre: (json['fullName'] ??
              json['nombre'] ??
              json['courierName'] ??
              json['name'] ??
              json['username'] ??
              '')
          .toString(),
      placaVehiculo: (json['vehiclePlate'] ??
              json['placaVehiculo'] ??
              json['placa_vehiculo'] ??
              '')
          .toString(),
      telefono: (json['phone'] ?? json['telefono'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      token: (json['accessToken'] ?? json['token'])?.toString(),
      isOnline: (json['isOnline'] ?? json['is_online'] ?? false) == true,
    );
  }

  /// Convierte la instancia de [CourierModel] a un mapa JSON serializable.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courierId': id,
      'nombre': nombre,
      'fullName': nombre,
      'placaVehiculo': placaVehiculo,
      'vehiclePlate': placaVehiculo,
      'telefono': telefono,
      'phone': telefono,
      'email': email,
      'token': token,
      'accessToken': token,
      'isOnline': isOnline,
    };
  }

  /// Crea una copia de este [CourierModel] reemplazando los campos especificados.
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
