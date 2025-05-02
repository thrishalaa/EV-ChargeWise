import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/station_service.dart';
import 'services/route_service.dart';
import 'services/booking_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This is where you'd put your actual backend URL
  static const String apiBaseUrl = 'http://192.168.200.165:8000';

  const MyApp({super.key}); // Change this to your actual backend URL

  @override
  Widget build(BuildContext context) {
    // Create base API service
    final apiService = ApiService();

    // Create derived services
    final authService = AuthService(apiService: apiService);
    final stationService = StationService(apiService: apiService);
    final routeService = RouteService(apiService: apiService);
    final bookingService = BookingService(apiService: apiService);

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<AuthService>.value(value: authService),
        Provider<StationService>.value(value: stationService),
        Provider<RouteService>.value(value: routeService),
        Provider<BookingService>.value(value: bookingService),
      ],
      child: MaterialApp(
        title: 'EV ChargeWise',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        // Define named routes
        routes: {
          '/':
              (context) => FutureBuilder<bool>(
                future: authService.isLoggedIn(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return snapshot.data == true ? HomeScreen() : LoginScreen();
                },
              ),
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegisterScreen(),
          '/home': (context) => HomeScreen(),
          '/map': (context) => MapScreen(),
          '/bookings': (context) => BookingsScreen(),
          '/profile': (context) => ProfileScreen(),
        },
        initialRoute: '/',
      ),
    );
  }
}
