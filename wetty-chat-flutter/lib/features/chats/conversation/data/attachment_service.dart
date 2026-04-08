import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api/client/api_json.dart';
import '../../../../core/api/models/attachments_api_models.dart';
import '../../../../core/network/api_config.dart';

class UploadUrlResponse {
  final String attachmentId;
  final String uploadUrl;
  final Map<String, String> uploadHeaders;

  const UploadUrlResponse({
    required this.attachmentId,
    required this.uploadUrl,
    this.uploadHeaders = const {},
  });
}

class AttachmentService {
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(seconds: 120);

  final Map<String, String> _authHeaders;

  AttachmentService(this._authHeaders);

  Future<UploadUrlResponse> requestUploadUrl({
    required String filename,
    required String contentType,
    required int size,
    int? width,
    int? height,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/attachments/upload-url');
    final payload = UploadUrlRequestDto(
      filename: filename,
      contentType: contentType,
      size: size,
      width: width,
      height: height,
    );

    final response = await http
        .post(
          uri,
          headers: apiJsonHeaders(_authHeaders),
          body: jsonEncode(payload.toJson()),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 201) {
      throw Exception(
        'Failed to get upload URL: ${response.statusCode} ${response.body}',
      );
    }
    final dto = UploadUrlResponseDto.fromJson(decodeJsonObject(response.body));
    return UploadUrlResponse(
      attachmentId: dto.attachmentId,
      uploadUrl: dto.uploadUrl,
      uploadHeaders: dto.uploadHeaders,
    );
  }

  Future<void> uploadFileToS3({
    required String uploadUrl,
    required PlatformFile file,
    required Map<String, String> uploadHeaders,
  }) async {
    await Future<void>(() async {
      final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
      request.headers.addAll(uploadHeaders);
      request.contentLength = file.size;

      final stream = file.readStream ?? file.xFile.openRead();
      await stream.pipe(request.sink);

      final response = await request.send().timeout(_uploadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception('Failed to upload file: ${response.statusCode} $body');
      }
    }).timeout(_uploadTimeout);
  }
}
