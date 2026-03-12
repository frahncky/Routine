import 'package:flutter/material.dart';
import 'package:routine/features/configuracoes/configuracoes_screen.dart';
import 'package:routine/features/contacts/contacts_screen.dart';
import 'package:routine/features/historico/historico_screen.dart';
import 'package:routine/features/home/home_screen.dart';
import 'package:routine/widgets/CurvedBottomNavBar.dart';

class MainTabs extends StatefulWidget {
  //final Function(Locale) onLocaleChanged;

   MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
     HomeScreen(),
     HistoricoScreen(),
    ContactsScreen(),
    ConfiguracoesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AnimatedCurvedBottomNavBar(
        icons: [
          Icons.home,
          Icons.history,
          Icons.view_agenda,
          Icons.settings,
        ],
        selectedIndex: _currentIndex,
        onItemTap: (index) {
          setState(() => _currentIndex = index);
        },
        labels: ['Início', 'Histórico', 'Contatos', 'Configurações'],
      ),
    );
  }
}
