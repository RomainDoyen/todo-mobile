import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

class TaskPhoto {
  const TaskPhoto({required this.id, required this.path});

  final String id;
  final String path;
}

Future<List<String>> pickTaskImages(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: screenBottomInset(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galerie'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Appareil photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return const [];
  final picker = ImagePicker();
  if (source == ImageSource.camera) {
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return const [];
    return _copyPickerFiles([file]);
  }
  final files = await picker.pickMultiImage(imageQuality: 85);
  return _copyPickerFiles(files);
}

/// Gallery paths can be temporary content URIs. Copy the bytes before they disappear.
Future<List<String>> _copyPickerFiles(List<XFile> files) async {
  if (files.isEmpty) return const [];
  final dir = await getTemporaryDirectory();
  final saved = <String>[];
  for (final file in files) {
    final bytes = await file.readAsBytes();
    var ext = p.extension(file.name).toLowerCase();
    if (!RegExp(r'^\.(jpe?g|png|webp|gif|heic|heif)$').hasMatch(ext)) ext = '.jpg';
    final dest = File(
      p.join(dir.path, 'pick_${DateTime.now().microsecondsSinceEpoch}_${saved.length}$ext'),
    );
    await dest.writeAsBytes(bytes, flush: true);
    saved.add(dest.path);
  }
  return saved;
}

class TaskImageGallery extends StatelessWidget {
  const TaskImageGallery({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.fillWidth = false,
  });

  final List<TaskPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<TaskPhoto> onRemove;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.image_outlined, size: 14, color: muted),
            const SizedBox(width: 6),
            const Text('Images', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (photos.isNotEmpty)
              Text('${photos.length}', style: const TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        if (!fillWidth)
          _Tiles(photos: photos, size: 84, dark: dark, onAdd: onAdd, onOpen: (photo) => _open(context, photo), onRemove: onRemove)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              const columns = 3;
              final size = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return _Tiles(
                photos: photos,
                size: size,
                dark: dark,
                onAdd: onAdd,
                onOpen: (photo) => _open(context, photo),
                onRemove: onRemove,
              );
            },
          ),
      ],
    );
  }

  void _open(BuildContext context, TaskPhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Image'),
          ),
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                child: Image.file(File(photo.path), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.photos,
    required this.size,
    required this.dark,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
  });

  final List<TaskPhoto> photos;
  final double size;
  final bool dark;
  final VoidCallback onAdd;
  final ValueChanged<TaskPhoto> onOpen;
  final ValueChanged<TaskPhoto> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final photo in photos)
          _Thumb(
            photo: photo,
            size: size,
            onOpen: () => onOpen(photo),
            onRemove: () => onRemove(photo),
          ),
        Material(
          color: fieldFill(Theme.of(context).brightness),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: hairline(Theme.of(context).brightness)),
          ),
          child: InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(Icons.add_photo_alternate_outlined, color: dark ? accentDark : accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo, required this.size, required this.onOpen, required this.onRemove});

  final TaskPhoto photo;
  final double size;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: const Color(0xFF151E31),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpen,
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: muted),
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
