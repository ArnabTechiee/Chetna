// main.dart - COMPLETE WITH ALL NAVIGATION
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Import all views
import 'views/overview_view.dart';
import 'views/analytics_view.dart';
import 'views/maps_view.dart';
import 'views/reports_view.dart';
import 'providers/dashboard_provider.dart';
import 'providers/auth_provider.dart';
import 'views/auth/login_view.dart';
import 'views/auth/register_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Initializing Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }

  runApp(const ChetnaDashboard());
}

class ChetnaDashboard extends StatelessWidget {
  const ChetnaDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'Chetna AI Medical Dashboard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0A4DA2),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFF),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthChecker(),
          '/login': (context) => const MedicalLoginView(),
          '/register': (context) => const MedicalRegisterView(),
          '/dashboard': (context) => const MainLayout(),
        },
      ),
    );
  }
}

// Main Layout with Navigation
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    OverviewView(),
    AnalyticsView(),
    MapsView(),
    ReportsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              _buildNavItem(0, Icons.dashboard_outlined, 'Overview'),
              _buildNavItem(1, Icons.analytics_outlined, 'Analytics'),
              _buildNavItem(2, Icons.map_outlined, 'Maps'),
              _buildNavItem(3, Icons.assignment_outlined, 'Reports'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0A4DA2).withOpacity(0.1)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFF0A4DA2)
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? const Color(0xFF0A4DA2)
                      : const Color(0xFF94A3B8),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Auth Checker
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading initially
        if (authProvider.isLoading) {
          return _buildSplashScreen();
        }

        // Check if authenticated
        if (authProvider.isAuthenticated) {
          print('✅ User is authenticated, showing dashboard');
          return const MainLayout();
        }

        print('🔒 User not authenticated, showing login');
        return const MedicalLoginView();
      },
    );
  }

  Widget _buildSplashScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety_outlined,
                size: 80, color: Color(0xFF0A4DA2)),
            SizedBox(height: 20),
            Text(
              'CHETNA AI',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4DA2),
              ),
            ),
            SizedBox(height: 10),
            Text('Medical Monitoring System'),
            SizedBox(height: 30),
            CircularProgressIndicator(color: Color(0xFF0A4DA2)),
          ],
        ),
      ),
    );
  }
}
