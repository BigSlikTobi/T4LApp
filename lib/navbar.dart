import 'package:flutter/material.dart';

class Navbar extends StatefulWidget {
  final Function(int)? onIndexChanged;
  const Navbar({super.key, this.onIndexChanged});

  @override
  _NavbarState createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onIndexChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'News'),
        BottomNavigationBarItem(icon: Icon(Icons.sports), label: 'Drills'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Teams'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Schedule',
        ),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Color(0xFF1A472A),
      unselectedItemColor: Colors.grey,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
    );
  }
}
