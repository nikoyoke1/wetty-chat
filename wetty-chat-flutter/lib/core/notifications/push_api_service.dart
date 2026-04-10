import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';

/// Raw HTTP calls for push subscription endpoints. No state.
class PushApiService {
  final Dio _dio;

  PushApiService(this._dio);

  /// Register an APNs device token with the backend.
  Future<void> subscribe({
    required String deviceToken,
    required String environment,
  }) async {
    await _dio.post<void>(
      '/push/subscribe',
      data: {
        'provider': 'apns',
        'deviceToken': deviceToken,
        'environment': environment,
      },
    );
  }

  /// Remove an APNs device token from the backend.
  Future<void> unsubscribe({
    required String deviceToken,
    required String environment,
  }) async {
    await _dio.post<void>(
      '/push/unsubscribe',
      data: {
        'provider': 'apns',
        'deviceToken': deviceToken,
        'environment': environment,
      },
    );
  }

  /// Check whether a specific device token is registered.
  Future<SubscriptionStatusResponse> getSubscriptionStatus({
    String? deviceToken,
    String? environment,
  }) async {
    final query = <String, String>{'provider': 'apns'};
    if (deviceToken != null) query['deviceToken'] = deviceToken;
    if (environment != null) query['environment'] = environment;
    final response = await _dio.get<Map<String, dynamic>>(
      '/push/subscription-status',
      queryParameters: query,
    );
    return SubscriptionStatusResponse.fromJson(response.data!);
  }
}

class SubscriptionStatusResponse {
  final bool hasActiveSubscription;
  final bool? hasMatchingSubscription;

  const SubscriptionStatusResponse({
    required this.hasActiveSubscription,
    this.hasMatchingSubscription,
  });

  factory SubscriptionStatusResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusResponse(
      hasActiveSubscription: json['hasActiveSubscription'] as bool,
      hasMatchingSubscription: json['hasMatchingSubscription'] as bool?,
    );
  }
}

final pushApiServiceProvider = Provider<PushApiService>((ref) {
  return PushApiService(ref.watch(dioProvider));
});
