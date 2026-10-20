import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/picked_image.dart';
import '../theme.dart';

/// Mở thư viện ảnh và đọc các ảnh được chọn (tối đa [limit]). [pick] để test.
Future<List<PickedImage>> pickPhotos(
  int limit, {
  Future<List<XFile>> Function(int limit)? pick,
}) async {
  final files = await (pick?.call(limit) ??
      ImagePicker().pickMultiImage(
        limit: limit < 2 ? null : limit,
        maxWidth: 1600,
        imageQuality: 85,
      ));
  return [
    for (final f in files.take(limit))
      PickedImage(await f.readAsBytes(), f.name.isEmpty ? 'photo' : f.name),
  ];
}

/// Hàng ô chọn ảnh từ thư viện máy: bấm ô trống để thêm, bấm ảnh để bỏ.
class PhotoPicker extends StatelessWidget {
  final List<PickedImage> images;
  final int max;
  final ValueChanged<List<PickedImage>> onChanged;
  final Future<List<XFile>> Function(int limit)? pick; // chèn khi test

  const PhotoPicker({
    super.key,
    required this.images,
    required this.onChanged,
    this.max = 4,
    this.pick,
  });

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final room = max - images.length;
    try {
      final added = await pickPhotos(room, pick: pick);
      if (added.isEmpty) return;
      onChanged([...images, ...added]);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Không mở được thư viện ảnh. Vui lòng thử lại.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(max, (i) {
        final img = i < images.length ? images[i] : null;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == max - 1 ? 0 : 8),
            child: AspectRatio(
              aspectRatio: 1,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('photo-slot-$i'),
                  onTap: img != null
                      ? () => onChanged([...images]..removeAt(i))
                      : (i == images.length ? () => _add(context) : null),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: img != null
                          ? null
                          : Border.all(
                              color: const Color(0xFF9AA0A9), width: 1.5),
                    ),
                    child: img == null
                        ? const Icon(Icons.add, color: AppColors.muted)
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(img.bytes, fit: BoxFit.cover),
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 12, color: Colors.white)),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
