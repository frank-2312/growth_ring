import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../services/photo_store.dart';

/// 一张方形照片。删掉的是应用目录里的副本，相册里的原图还在，
/// 所以缩略图上的 × 不做二次确认——重新加回来很快。
class PhotoSquare extends StatelessWidget {
  const PhotoSquare({
    super.key,
    required this.file,
    required this.size,
    this.onTap,
    this.onRemove,
  });

  final File file;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: radius,
            child: GestureDetector(
              onTap: onTap,
              child: Image.file(
                file,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // 缩略图按小尺寸解码，一屏十几张也不至于把内存吃穿
                cacheWidth: (size * 3).round(),
                errorBuilder: (context, _, _) => Container(
                  width: size,
                  height: size,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: size * 0.32,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 2,
              top: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 日记配图条：可编辑时末尾多一个「加一张」，只读时就是一个横向图集。
class PhotoStrip extends StatefulWidget {
  const PhotoStrip({
    super.key,
    required this.dateKey,
    required this.photos,
    required this.onChanged,
    this.editable = true,
    this.size = 86,
  });

  final String dateKey;
  final List<String> photos;

  /// 增删之后把整份列表交回去，由调用方决定怎么存
  final ValueChanged<List<String>> onChanged;
  final bool editable;
  final double size;

  @override
  State<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<PhotoStrip> {
  bool _busy = false;

  bool get _readOnlyEmpty => !widget.editable && widget.photos.isEmpty;

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // 只读相册，不碰相机：少一个权限、少一截文案解释
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;

      final added = <String>[];
      for (final file in picked) {
        added.add(await PhotoStore.import(file, widget.dateKey));
      }
      if (!mounted) return;
      widget.onChanged([...widget.photos, ...added]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没能加上图片：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(String name) {
    PhotoStore.remove(widget.dateKey, name);
    widget.onChanged([
      for (final p in widget.photos)
        if (p != name) p,
    ]);
  }

  void _open(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(
          dateKey: widget.dateKey,
          photos: widget.photos,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_readOnlyEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;

    return SizedBox(
      height: widget.size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.photos.length + (widget.editable ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == widget.photos.length) {
            return _AddTile(
              size: widget.size,
              busy: _busy,
              soft: soft,
              onTap: _add,
            );
          }
          final name = widget.photos[i];
          return PhotoSquare(
            file: PhotoStore.fileOf(widget.dateKey, name),
            size: widget.size,
            onTap: () => _open(i),
            onRemove: widget.editable ? () => _remove(name) : null,
          );
        },
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.busy,
    required this.soft,
    required this.onTap,
  });

  final double size;
  final bool busy;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 20, color: soft),
                  const SizedBox(height: 5),
                  Text(
                    '加一张',
                    style: TextStyle(fontSize: 10, color: soft),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 全屏看图。左右翻，双指放大，点空白关掉。
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.dateKey,
    required this.photos,
    this.initialIndex = 0,
  });

  final String dateKey;
  final List<String> photos;
  final int initialIndex;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.photos.length > 1
              ? '${_index + 1} / ${widget.photos.length}'
              : '',
          style: const TextStyle(fontSize: 13),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final file = PhotoStore.fileOf(widget.dateKey, widget.photos[i]);
          return InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (context, _, _) => const Text(
                  '这张图找不到了',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
