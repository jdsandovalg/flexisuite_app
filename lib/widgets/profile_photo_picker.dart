
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ProfilePhotoPicker extends StatefulWidget {
  final String? initialImageUrl;
  final Function(Uint8List, String) onPhotoPicked;

  const ProfilePhotoPicker({
    super.key,
    this.initialImageUrl,
    required this.onPhotoPicked,
  });

  @override
  State<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<ProfilePhotoPicker> {
  String? _imageUrl;
  Uint8List? _tempImageBytes;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImageUrl != oldWidget.initialImageUrl) {
      setState(() {
        _imageUrl = widget.initialImageUrl;
        _tempImageBytes = null; // Clear temp image when permanent URL is updated
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.first.bytes != null) {
        final fileBytes = result.files.first.bytes!;
        final fileName = result.files.first.name;
        setState(() {
          _tempImageBytes = fileBytes; // Update temp image
        });
        widget.onPhotoPicked(fileBytes, fileName);
      } else {
        print("Selección cancelada");
      }
    } catch (e) {
      print("Error al abrir selector: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: _tempImageBytes != null
              ? MemoryImage(_tempImageBytes!) // Use temp image if available
              : (_imageUrl != null && _imageUrl!.isNotEmpty
                  ? NetworkImage(_imageUrl!)
                  : null),
          child: (_tempImageBytes == null && (_imageUrl == null || _imageUrl!.isEmpty))
              ? const Icon(Icons.person, size: 60)
              : null,
        ),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

