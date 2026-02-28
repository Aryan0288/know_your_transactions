import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home/view/page_home.dart';
import 'package:firebase_core/firebase_core.dart';

import 'features/login_signup/view/page_enter_otp.dart';
import 'learning_page.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      // home: SignUpPage(),
      home: HomePage(),
      // home: EnterOtpPage(),
    );
  }
}





/*

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Finance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E8B57),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
        fontFamily: 'Roboto',
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF2E8B57),
          selectionColor: Color(0xFF2E8B57),
          selectionHandleColor: Color(0xFF2E8B57),
        ),
      ),
      home: const MainScreen(),
      routes: {
        '/add_expense': (context) => const AddExpensePage(),
      },
    );
  }
}

/// ✅ FIXED: Correct Riverpod provider
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    final pages = [
      const HomePage(),
      const DummyPage(title: 'Statistics'),
      const SizedBox(), // FAB placeholder
      const DummyPage(title: 'Wallet'),
      const DummyPage(title: 'Profile'),
    ];

    return Scaffold(
      body: pages[currentIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E8B57),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
        onPressed: () {
          navigatorKey.currentState?.pushNamed('/add_expense');
        },
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _BottomNavItem(index: 0, icon: Icons.home),
            _BottomNavItem(index: 1, icon: Icons.bar_chart),
            SizedBox(width: 48),
            _BottomNavItem(index: 3, icon: Icons.wallet),
            _BottomNavItem(index: 4, icon: Icons.person),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends ConsumerWidget {
  final int index;
  final IconData icon;

  const _BottomNavItem({
    super.key,
    required this.index,
    required this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final isSelected = currentIndex == index;
    final color = isSelected ? const Color(0xFF2E8B57) : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(
        child: Text(
          'Welcome to Finance Tracker!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E8B57),
          ),
        ),
      ),
    );
  }
}

class AddExpensePage extends StatelessWidget {
  const AddExpensePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: 'Food',
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: const [
                'Food',
                'Transport',
                'Entertainment',
                'Utilities',
                'Shopping',
                'Other',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E8B57),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense Saved!')),
                );
                Navigator.pop(context);
              },
              child: const Text('Save Expense', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'This is the $title page.',
          style: const TextStyle(fontSize: 24, color: Colors.grey),
        ),
      ),
    );
  }
}
*/
