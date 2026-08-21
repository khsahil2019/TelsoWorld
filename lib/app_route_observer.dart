import 'package:flutter/material.dart';

/// Shared with [MaterialApp.navigatorObservers] so [RouteAware] screens can
/// pause work (e.g. video) when another route is pushed on top.
final RouteObserver<PageRoute<dynamic>> telsoRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
