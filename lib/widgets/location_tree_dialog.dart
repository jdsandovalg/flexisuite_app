import 'package:flutter/material.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';

class LocationTreeDialog extends StatefulWidget {
  final List<LocationNode> locationTree;
  final bool allowParentSelection;

  const LocationTreeDialog({
    super.key,
    required this.locationTree,
    this.allowParentSelection = false, // Por defecto, no se pueden seleccionar nodos padres.
  });

  @override
  State<LocationTreeDialog> createState() => _LocationTreeDialogState();
}

class _LocationTreeDialogState extends State<LocationTreeDialog> {
  List<LocationNode> _filteredTree = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredTree = widget.locationTree;
    _searchController.addListener(_filterTree);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTree);
    _searchController.dispose();
    super.dispose();
  }

  void _filterTree() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredTree = widget.locationTree);
      return;
    }

    // --- INICIO: Lógica de búsqueda mejorada ---
    // Función recursiva que filtra el árbol manteniendo la jerarquía.
    List<LocationNode> recursiveFilter(List<LocationNode> nodes) {
      List<LocationNode> filteredList = [];
      for (var node in nodes) {
        // Primero, filtramos los hijos del nodo actual.
        List<LocationNode> filteredChildren = recursiveFilter(node.children);

        // Un nodo se mantiene si:
        // 1. Su propio nombre coincide con la búsqueda.
        // 2. O si tiene hijos que coinciden con la búsqueda.
        if (node.name.toLowerCase().contains(query) || filteredChildren.isNotEmpty) {
          // Creamos una copia del nodo con sus hijos ya filtrados.
          filteredList.add(
            LocationNode(data: node.data, children: filteredChildren),
          );
        }
      }
      return filteredList;
    }

    setState(() => _filteredTree = recursiveFilter(widget.locationTree));
    // --- FIN: Lógica de búsqueda mejorada ---
  }

  List<LocationNode> _flattenTree(List<LocationNode> nodes) {
    final List<LocationNode> flatList = [];
    for (var node in nodes) {
      flatList.add(node);
      if (node.children.isNotEmpty) {
        flatList.addAll(_flattenTree(node.children));
      }
    }
    return flatList;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar Ubicación'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar ubicación...',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: _filteredTree.map((node) => _buildNode(node, 0)).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildNode(LocationNode node, int level) {
    // Añadimos un padding a la izquierda que aumenta con cada nivel de profundidad.
    final padding = EdgeInsets.only(left: 16.0 * level);

    if (node.children.isEmpty) {
      // Nodos hoja (sin hijos): son seleccionables.
      return ListTile(
        contentPadding: padding,
        title: Text(node.name),
        onTap: () => Navigator.of(context).pop(node), // Devuelve el nodo seleccionado
      );
    }
    // Nodos padre (con hijos): también son seleccionables.
    return ExpansionTile(
      tilePadding: padding,
      // Hacemos que el título sea un ListTile para poder añadirle un onTap.
      title: ListTile(
        contentPadding: EdgeInsets.zero, // El padding ya lo controla el ExpansionTile.
        title: Text(node.name),
        onTap: widget.allowParentSelection
            ? () => Navigator.of(context).pop(node) // Permite seleccionar el nodo padre si está habilitado.
            : null, // Si no, el onTap es nulo y no hace nada.
      ),
      // El icono de expansión/colapso seguirá funcionando de forma independiente.
      children: node.children.map((child) => _buildNode(child, level + 1)).toList(),
    );
  }
}