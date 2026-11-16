import 'package:flutter/material.dart';

import '../data/repositorios.dart';
import 'centros_screen.dart';
import 'favoritos_screen.dart';
import 'perfil_screen.dart';
import 'recordatorios_screen.dart';

/// Pantalla principal (protegida): solo se llega aquí con sesión iniciada.
/// Barra inferior con 4 pestañas.
class ShellScreen extends StatefulWidget {
  final UsuarioActual usuario;

  const ShellScreen({super.key, required this.usuario});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _indice = 0;

  // Cada vez que se elige una pestaña se reconstruye para traer datos frescos.
  Widget get _pestana {
    switch (_indice) {
      case 1:
        return const FavoritosScreen();
      case 2:
        return const RecordatoriosScreen();
      case 3:
        return PerfilScreen(usuario: widget.usuario);
      case 0:
      default:
        return const CentrosScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyedSubtree(key: ValueKey(_indice), child: _pestana),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.local_hospital_outlined),
              selectedIcon: Icon(Icons.local_hospital),
              label: 'Centros'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Favoritos'),
          NavigationDestination(
              icon: Icon(Icons.alarm_outlined),
              selectedIcon: Icon(Icons.alarm),
              label: 'Recordar'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}
