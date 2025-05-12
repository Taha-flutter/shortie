import 'package:get/get.dart';
import 'package:shortie/pages/go_live_page/controller/go_live_controller.dart';

class GoLiveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GoLiveController>(() => GoLiveController());
  }
}
