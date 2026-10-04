import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import Seluruh Screen
import 'home_screen.dart';
import 'order_screen.dart';
import 'schedule_screen.dart';
import 'history_screen.dart';
import 'return_confirm_screen.dart';
import 'finance_screen.dart';
import 'car_list_screen.dart';
import 'maintenance_screen.dart';
import 'transaction_input_screen.dart'; // <- Screen Baru Input / Output

class MainNavigationWrapper extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const MainNavigationWrapper({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.themeMode == ThemeMode.dark;
    Color navBgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);

    final List<Widget> pages = [
      HomeScreen(
        onNavigate: (index) => setState(() => _selectedIndex = index),
        onToggleTheme: widget.toggleTheme,
      ),
      const OrderScreen(),
      const ScheduleScreen(),
      const HistoryScreen(),
      const ReturnConfirmScreen(),
      const FinanceScreen(),
      CarListScreen(onToggleTheme: widget.toggleTheme),
      const MaintenanceScreen(),
      const TransactionInputScreen(), // <- Index ke-8 untuk Input Transaksi
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: navBgColor,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: pages[_selectedIndex],
        
        // Tombol (+) Membuka Input Transaksi
        floatingActionButton: FloatingActionButton(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFF10B981),
          onPressed: () => setState(() => _selectedIndex = 8), // Pindah ke TransactionInputScreen
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.assignment, 'Order', 1),
              _buildNavItem(Icons.calendar_month, 'Jadwal', 2),
              const SizedBox(width: 48), // Spasi FAB (+)
              _buildNavItem(Icons.history, 'History', 3),
              _buildNavItem(Icons.time_to_leave, 'Pulang', 4),
              _buildNavItem(Icons.account_balance_wallet, 'Keuangan', 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFF10B981) : Colors.grey),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? const Color(0xFF10B981) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}