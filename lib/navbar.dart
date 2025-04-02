import 'package:flutter/material.dart';

class Navbar extends StatefulWidget {
  final Function(int)? onIndexChanged;
  const Navbar({super.key, this.onIndexChanged});
  @override
  NavbarState createState() => NavbarState();
}

class NavbarState extends State<Navbar> {
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
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Teams'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Color(0xFF1A472A),
      unselectedItemColor: Colors.grey,
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    );
  }
}
