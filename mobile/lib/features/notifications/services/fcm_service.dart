import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref);
});

class FcmService {
  FcmService(this._ref);

  final Ref _ref;

  bool _initialized = false;
  bool _tokenRefreshListening = false;
  bool _messageListening = false;
  bool _openedMessageListening = false;
  String? _registeredToken;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize(GoRouter router) async {
    if (!_isSupported || _initialized) {
      return;
    }

    _initialized = true;
    await _requestPermission();
    _listenTokenRefresh();
    _listenForegroundMessages();
    _listenOpenedMessages(router);
    await _handleInitialMessage(router);
  }

  Future<void> registerForCurrentUser() async {
    if (!_isSupported) {
      return;
    }

    try {
      await _requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty || token == _registeredToken) {
        return;
      }

      await _ref.read(notificationsRepositoryProvider).registerDevice(token);
      _registeredToken = token;
    } catch (_) {
      // FCM must never block the app experience.
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_isSupported) {
      return;
    }

    try {
      final token =
          _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await _ref.read(notificationsRepositoryProvider).unregisterDevice(token);
      if (_registeredToken == token) {
        _registeredToken = null;
      }
    } catch (_) {
      // Logout must remain possible even if FCM is temporarily unavailable.
    }
  }

  Future<void> _requestPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // Refusal or platform errors are non-blocking.
    }
  }

  void _listenTokenRefresh() {
    if (_tokenRefreshListening) {
      return;
    }

    _tokenRefreshListening = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (token.isEmpty || token == _registeredToken || !_hasCurrentUser()) {
        return;
      }

      try {
        await _ref.read(notificationsRepositoryProvider).registerDevice(token);
        _registeredToken = token;
      } catch (_) {
        // Token refresh will be retried by the next app/auth lifecycle event.
      }
    });
  }

  void _listenForegroundMessages() {
    if (_messageListening) {
      return;
    }

    _messageListening = true;
    FirebaseMessaging.onMessage.listen((_) {
      _ref.invalidate(notificationsProvider);
    });
  }

  void _listenOpenedMessages(GoRouter router) {
    if (_openedMessageListening) {
      return;
    }

    _openedMessageListening = true;
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openMessage(router, message);
    });
  }

  Future<void> _handleInitialMessage(GoRouter router) async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message == null) {
        return;
      }

      Future<void>.delayed(const Duration(milliseconds: 350), () {
        _openMessage(router, message);
      });
    } catch (_) {
      // Opening the app from a notification must remain safe.
    }
  }

  void _openMessage(GoRouter router, RemoteMessage message) {
    final route = _routeFromMessage(message);
    router.go(route);
    _ref.invalidate(notificationsProvider);
  }

  String _routeFromMessage(RemoteMessage message) {
    final data = message.data;
    final route = data['route']?.toString().trim();
    if (_isAllowedRoute(route)) {
      return route!;
    }

    final orderId = data['order_id']?.toString().trim();
    if (orderId != null && int.tryParse(orderId) != null) {
      return '/orders/$orderId';
    }

    final productId = data['product_id']?.toString().trim();
    if (productId != null && int.tryParse(productId) != null) {
      return '/product/$productId';
    }

    return '/notifications';
  }

  bool _isAllowedRoute(String? route) {
    if (route == null || route.isEmpty || !route.startsWith('/')) {
      return false;
    }
    if (route.startsWith('//') || route.contains('://')) {
      return false;
    }

    return route == '/notifications' ||
        route == '/orders' ||
        route.startsWith('/orders/') ||
        route.startsWith('/product/');
  }

  bool _hasCurrentUser() {
    return _ref.read(currentUserProvider).valueOrNull != null;
  }
}
