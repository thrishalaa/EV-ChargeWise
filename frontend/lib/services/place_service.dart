import 'dart:convert';
import 'package:http/http.dart' as http;

class Place {
  final String displayName;
  final double latitude;
  final double longitude;

  Place({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      displayName: json['display_name'],
      latitude: double.parse(json['lat']),
      longitude: double.parse(json['lon']),
    );
  }
}

class PlaceService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<Place>> searchPlaces(String query) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
      },
    );

    final response = await http.get(
      uri,
      headers: {'User-Agent': 'EVChargeWiseApp/1.0 (your_email@example.com)'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Place.fromJson(item)).toList();
    } else {
      // Throw detailed error with status code and response body for better diagnostics
      throw Exception(
        'Failed to fetch place suggestions. Status code: ${response.statusCode}, Body: ${response.body}',
      );
    }
  }
}
