import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'meeting_list_screen.dart';
import 'minutes_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenMeetings: () => setState(() => _index = 2),
            onOpenMinutes: () => setState(() => _index = 1),
          ),
          const MinutesScreen(),
          const MeetingListScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: '纪要',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '会议',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

