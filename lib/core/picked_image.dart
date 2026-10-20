import 'dart:typed_data';

/// Ảnh người dùng vừa chọn từ máy, giữ trong bộ nhớ cho tới khi tải lên.
class PickedImage {
  final Uint8List bytes;
  final String name;
  const PickedImage(this.bytes, this.name);
}
