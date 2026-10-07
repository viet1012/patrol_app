part of '../camera_preview_box.dart';

/// Theo dõi stack route của navigator gốc để CameraPreviewBox biết route của
/// nó có đang bị một page route (màn mới) che hay không.
///
/// Popup route (dialog, dropdown, bottom sheet) không tính là che: camera vẫn
/// chạy. Gắn vào GoRouter qua `observers: [CameraPreviewRouteObserver.instance]`.
/// Chưa gắn thì chỉ còn suspend khi route đang pop (route.isActive == false).
class CameraPreviewRouteObserver extends NavigatorObserver {
  CameraPreviewRouteObserver._();

  static final CameraPreviewRouteObserver instance =
      CameraPreviewRouteObserver._();

  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  /// Tăng mỗi khi stack đổi. Listener chỉ đọc và lên lịch xử lý, không
  /// setState trực tiếp (sự kiện có thể đến trong lúc navigator đang build).
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  bool _isCoveredByPage(Route<dynamic> route) {
    final index = _routes.indexOf(route);
    if (index < 0) return false;
    return _routes.skip(index + 1).any((r) => r is PageRoute);
  }

  void _changed() => _revision.value++;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute != null) {
      if (index >= 0) {
        _routes[index] = newRoute;
      } else {
        _routes.add(newRoute);
      }
    } else if (index >= 0) {
      _routes.removeAt(index);
    }
    _changed();
  }
}
