/// BlueSnap icon set — a single source of truth mapping app concepts to the
/// professional Iconsax family (bundled offline, so it fits the zero-internet
/// promise). Outline for idle, `*Bold` for active/selected states. Using named
/// concepts here keeps icon usage consistent and swappable app-wide.
library;

import 'package:iconsax_flutter/iconsax_flutter.dart';

class AppIcons {
  AppIcons._();

  // ── Bottom navigation ─────────────────────────────────
  static const home = Iconsax.home_2;
  static const homeBold = Iconsax.home_2_copy;
  static const search = Iconsax.search_normal_1;
  static const searchBold = Iconsax.search_normal_1_copy;
  static const messages = Iconsax.messages_2;
  static const messagesBold = Iconsax.messages_2_copy;
  static const profile = Iconsax.user;
  static const profileBold = Iconsax.profile_circle_copy;

  // ── Feed actions ──────────────────────────────────────
  static const like = Iconsax.heart;
  static const likeBold = Iconsax.heart_copy;
  static const comment = Iconsax.message;
  static const repost = Iconsax.repeat;
  static const share = Iconsax.send_2;
  static const bookmark = Iconsax.archive_1;
  static const bookmarkBold = Iconsax.archive_1_copy;
  static const more = Iconsax.more;

  // ── Header / actions ──────────────────────────────────
  static const create = Iconsax.add_square;
  static const activity = Iconsax.heart;
  static const dm = Iconsax.send_2;
  static const menu = Iconsax.menu_1;
  static const back = Iconsax.arrow_left_2;
  static const close = Iconsax.close_circle;
  static const settings = Iconsax.setting_2;
  static const diagnostics = Iconsax.d_cube_scan;
  static const info = Iconsax.info_circle;
  static const edit = Iconsax.edit_2;
  static const addUser = Iconsax.user_add;
  static const shareExternal = Iconsax.share;

  // ── Chat / compose ────────────────────────────────────
  static const camera = Iconsax.camera;
  static const gallery = Iconsax.gallery;
  static const mic = Iconsax.microphone_2;
  static const file = Iconsax.document_text;
  static const location = Iconsax.location;
  static const call = Iconsax.call;
  static const video = Iconsax.video;
  static const attach = Iconsax.add_circle;
  static const send = Iconsax.send_1;
  static const verified = Iconsax.shield_tick;
  static const block = Iconsax.slash;
  static const muteOff = Iconsax.notification;
  static const muteOn = Iconsax.notification_bing;

  // ── Profile tabs ──────────────────────────────────────
  static const grid = Iconsax.grid_3;
  static const drafts = Iconsax.document;
  static const trash = Iconsax.trash;
  static const story = Iconsax.add;

  // ── Misc ──────────────────────────────────────────────
  static const play = Iconsax.play_circle;
  static const lock = Iconsax.lock_1;
  static const bluetooth = Iconsax.driver; // presence/nearby glyph
  static const people = Iconsax.people;
  static const empty = Iconsax.gallery;
}
