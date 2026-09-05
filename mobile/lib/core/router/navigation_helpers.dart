import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

String currentLocation(BuildContext context) {
  return GoRouterState.of(context).uri.toString();
}

String loginLocationFor(String redirect) {
  return Uri(
    path: '/login',
    queryParameters: {'redirect': redirect},
  ).toString();
}

void openLoginForCurrentLocation(BuildContext context) {
  context.push(loginLocationFor(currentLocation(context)));
}
