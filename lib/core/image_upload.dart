import 'api_client.dart';
import 'picked_image.dart';

const maxUploadImageBytes = 5 * 1024 * 1024; // khớp giới hạn của BE

/// Tải ảnh người dùng chọn lên Storage qua BE, trả URL công khai theo đúng thứ tự.
Future<List<String>> uploadPickedImages(
  ApiClient api,
  List<PickedImage> images, {
  required String purpose,
}) async {
  for (final img in images) {
    if (img.bytes.length > maxUploadImageBytes) {
      throw const ApiException('FILE_TOO_LARGE', 'Mỗi ảnh tối đa 5 MB.');
    }
  }
  final result = await api.uploadImages([
    for (final img in images) (bytes: img.bytes, filename: img.name),
  ], purpose: purpose);
  final urls = result['urls'];
  if (urls is! List ||
      urls.length != images.length ||
      urls.any((u) => u is! String)) {
    throw const ApiException(
      'INVALID_RESPONSE',
      'Máy chủ chưa trả đường dẫn ảnh hợp lệ.',
    );
  }
  return urls.cast<String>();
}
