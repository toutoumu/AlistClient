import 'package:flutter/material.dart';
import 'package:get/get.dart';

var routeStack = RxList<Route>();

class AppNavigatorObserver extends NavigatorObserver {
  //manage navigator.push
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    Future.delayed(const Duration(milliseconds: 200), () {
      routeStack.add(route);
    });
  }

  //manage navigator.pop
  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    Future.delayed(const Duration(milliseconds: 200), () {
      routeStack.remove(route);
    });
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    Future.delayed(const Duration(milliseconds: 200), () {
      routeStack.remove(route);
    });
  }

  //manage navigator.pushReplacement
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    Future.delayed(const Duration(milliseconds: 200), () {
      routeStack.clear();
      routeStack.addAll([newRoute!]);
    });
  }
}
