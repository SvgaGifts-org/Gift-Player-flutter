import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'live_room.dart';
import 'studio.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Brand.bg,
    ),
  );
  runApp(const GiftDemoApp());
}

class GiftDemoApp extends StatelessWidget {
  const GiftDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.pink,
      brightness: Brightness.dark,
      primary: Brand.pink,
      secondary: Brand.orange,
      surface: Brand.surface,
    );
    return MaterialApp(
      title: 'Gift Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: Brand.bg,
        useMaterial3: true,
        sliderTheme: const SliderThemeData(
          trackHeight: 3,
          activeTrackColor: Brand.pink,
          thumbColor: Colors.white,
        ),
        chipTheme: ChipThemeData(
          selectedColor: Brand.pink,
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          side: BorderSide.none,
          shape: const StadiumBorder(),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// Two tabs: the live room (the queue, as viewers see it) and the studio (one gift, as a developer inspects it).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: IndexedStack(
      index: _tab,
      children: const [LiveRoomPage(), StudioPage()],
    ),
    bottomNavigationBar: NavigationBar(
      height: 64,
      backgroundColor: Brand.bg.withValues(alpha: 0.96),
      indicatorColor: Brand.pink.withValues(alpha: 0.22),
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.live_tv_outlined),
          selectedIcon: Icon(Icons.live_tv_rounded, color: Brand.pink),
          label: 'Live room',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune_rounded, color: Brand.pink),
          label: 'Studio',
        ),
      ],
    ),
  );
}
