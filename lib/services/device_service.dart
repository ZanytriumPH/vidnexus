import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'models/common_dto.dart';

/// 设备注册 Service，与后端 /api/v1/devices 路由对齐（new.md 新增）。
class DeviceService {
  const DeviceService();

  Dio get _dio => ApiClient.instance;

  /// 注册 FCM 设备 token。
  Future<ApiResponse<DeviceRegisterResponseData>> registerDevice({
    required String deviceToken,
    required String platform,
    required String appVersion,
    required String deviceId,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.devices,
      data: DeviceRegisterRequest(
        deviceToken: deviceToken,
        platform: platform,
        appVersion: appVersion,
        deviceId: deviceId,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      DeviceRegisterResponseData.fromJson,
    );
  }

  /// 反注册设备 token。
  Future<ApiResponse<Map<String, dynamic>>> unregisterDevice(
    String deviceTokenId,
  ) async {
    final resp = await _dio.delete(ApiEndpoints.device(deviceTokenId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      null,
    );
  }

  /// 列出已注册设备。
  Future<ApiResponse<List<DeviceRegisterResponseData>>> listDevices() async {
    final resp = await _dio.get(ApiEndpoints.devices);
    final json = resp.data as Map<String, dynamic>;
    final dataList = (json['data'] as List<dynamic>?)
            ?.map(
              (e) =>
                  DeviceRegisterResponseData.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [];
    return ApiResponse<List<DeviceRegisterResponseData>>(
      status: json['status'] as String? ?? 'success',
      data: dataList,
    );
  }
}

/// POST /api/v1/devices 请求体。
class DeviceRegisterRequest {
  const DeviceRegisterRequest({
    required this.deviceToken,
    required this.platform,
    required this.appVersion,
    required this.deviceId,
  });

  final String deviceToken; // FCM token, min=1,max=512
  final String platform; // android / ios / web
  final String appVersion; // <=32
  final String deviceId; // min=1,max=128

  Map<String, dynamic> toJson() => {
        'device_token': deviceToken,
        'platform': platform,
        'app_version': appVersion,
        'device_id': deviceId,
      };
}

/// Device 注册响应 data。
class DeviceRegisterResponseData {
  const DeviceRegisterResponseData({
    required this.deviceTokenId,
    required this.platform,
    required this.deviceId,
    this.appVersion,
    this.registeredAt,
  });

  final String deviceTokenId;
  final String platform;
  final String deviceId;
  final String? appVersion;
  final String? registeredAt;

  factory DeviceRegisterResponseData.fromJson(Map<String, dynamic> json) {
    return DeviceRegisterResponseData(
      deviceTokenId: json['device_token_id'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      appVersion: json['app_version'] as String?,
      registeredAt: json['registered_at'] as String?,
    );
  }
}
