import 'package:flutter/material.dart';

/// Drop-in icon aliases replacing `lucide_icons` (incompatible with newer
/// Flutter SDKs due to `IconData` being `final`).
/// All icons map to Flutter's built-in `Icons` class.
class LucideIcons {
  LucideIcons._();

  // navigation / ui
  static const IconData arrowLeft        = Icons.arrow_back;
  static const IconData arrowRight       = Icons.arrow_forward;
  static const IconData chevronRight     = Icons.chevron_right;
  static const IconData chevronDown      = Icons.keyboard_arrow_down;
  static const IconData chevronUp        = Icons.keyboard_arrow_up;
  static const IconData x               = Icons.close;
  static const IconData check           = Icons.check;
  static const IconData plus            = Icons.add;
  static const IconData refresh         = Icons.refresh;
  static const IconData refreshCw       = Icons.refresh;
  static const IconData filter          = Icons.filter_list;
  static const IconData search          = Icons.search;
  static const IconData download        = Icons.download;
  static const IconData maximize        = Icons.fullscreen;

  // auth / account
  static const IconData scanFace        = Icons.face_retouching_natural;
  static const IconData mail            = Icons.mail_outline;
  static const IconData lock            = Icons.lock_outline;
  static const IconData eye             = Icons.visibility_outlined;
  static const IconData eyeOff          = Icons.visibility_off_outlined;
  static const IconData pencil          = Icons.edit_outlined;
  static const IconData logOut          = Icons.logout;

  // people / attendance
  static const IconData user            = Icons.person_outline;
  static const IconData users           = Icons.group_outlined;
  static const IconData userCheck       = Icons.how_to_reg_outlined;
  static const IconData userX           = Icons.person_off_outlined;
  static const IconData camera          = Icons.camera_alt_outlined;

  // device / ble
  static const IconData bluetooth       = Icons.bluetooth;
  static const IconData bluetoothOff    = Icons.bluetooth_disabled;
  static const IconData cpu             = Icons.memory;
  static const IconData wifi            = Icons.wifi;
  static const IconData wifiOff         = Icons.wifi_off;
  static const IconData unplug          = Icons.power_off_outlined;

  // video
  static const IconData video           = Icons.videocam_outlined;
  static const IconData videoOff        = Icons.videocam_off_outlined;
  static const IconData play            = Icons.play_arrow;

  // alerts / status
  static const IconData bell            = Icons.notifications_outlined;
  static const IconData bellOff         = Icons.notifications_off_outlined;
  static const IconData alertCircle     = Icons.error_outline;
  static const IconData alertTriangle   = Icons.warning_amber_outlined;
  static const IconData checkCircle2    = Icons.check_circle_outline;
  static const IconData checkCircle     = Icons.check_circle_outline;
  static const IconData circleAlert     = Icons.error_outline;
  static const IconData circleCheck     = Icons.check_circle_outline;
  static const IconData shieldAlert     = Icons.security;
  static const IconData clock           = Icons.access_time;
  static const IconData zap             = Icons.bolt;
  static const IconData fileText        = Icons.description_outlined;

  // calendar
  static const IconData calendar        = Icons.calendar_today;
  static const IconData calendarRange   = Icons.date_range;

  // misc
  static const IconData settings        = Icons.settings_outlined;
  static const IconData phone           = Icons.phone_outlined;
  static const IconData layoutDashboard = Icons.dashboard_outlined;
  static const IconData home            = Icons.home_outlined;
  static const IconData unlock          = Icons.lock_open_outlined;
  static const IconData info            = Icons.info_outline;
  static const IconData plugZap         = Icons.power_outlined;
  static const IconData trash2          = Icons.delete_outline;
  static const IconData server          = Icons.dns_outlined;
  static const IconData userPlus        = Icons.person_add_outlined;

  // id / organisation
  static const IconData idCard          = Icons.badge_outlined;
  static const IconData building2       = Icons.business_outlined;
  static const IconData layoutGrid      = Icons.grid_view_outlined;
  static const IconData hash            = Icons.tag;

  // messaging
  static const IconData messageCircle   = Icons.chat_bubble_outline;
  static const IconData message         = Icons.chat_outlined;
}
