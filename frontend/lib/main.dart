import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/station_service.dart';
import 'services/route_service.dart';
import 'services/booking_service.dart';
import 'services/payment_service.dart';
import 'services/admin_service.dart';
import 'services/super_admin_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_bookings_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_stations_screen.dart';
import 'screens/admin_management_screen.dart';
import 'screens/station_assignment_screen.dart';
import 'screens/superadmin_dashboard_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This is where you'd put your actual backend URL
  static const String apiBaseUrl = 'http://192.168.100.9:8000';

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
    final paymentService = PaymentService(baseUrl: apiBaseUrl);

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<AuthService>.value(value: authService),
        Provider<StationService>.value(value: stationService),
        Provider<RouteService>.value(value: routeService),
        Provider<BookingService>.value(value: bookingService),
        Provider<AdminService>(create: (_) => AdminService(apiService)),
        Provider<SuperAdminService>(
          create: (_) => SuperAdminService(apiService),
        ),
        ChangeNotifierProvider<PaymentService>.value(value: paymentService),
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
                future: authService.loadAuthInfo(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.data == true) {
                    final role = authService.userRole ?? 'user';
                    print(role);
                    print("HERE IS THE ROLE");
                    if (role == 'super_admin') {
                      return const SuperadminDashboardScreen();
                    } else if (role == 'admin') {
                      return const AdminDashboardScreen();
                    } else {
                      return const HomeScreen();
                    }
                  } else {
                    return const LoginScreen();
                  }
                },
              ),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/map': (context) => const MapScreen(),
          '/bookings': (context) => const BookingsScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/admin-stations': (context) => const AdminStationsScreen(),
          '/admin-bookings': (context) => const AdminBookingsScreen(),
          '/admin-dashboard': (context) => const AdminDashboardScreen(),
          '/admin-management': (context) => const AdminManagementScreen(),
          '/station-assignment': (context) => const StationAssignmentScreen(),
          '/superadmin-dashboard':
              (context) => const SuperadminDashboardScreen(),
        },
        initialRoute: '/',
      ),
    );
  }
}
