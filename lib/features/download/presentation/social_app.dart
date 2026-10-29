import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialApp {
  final String name;
  final FaIconData icon;
  final Color color;
  final String url;

  const SocialApp({
    required this.name,
    required this.icon,
    required this.color,
    required this.url,
  });

  static const all = <SocialApp>[
    SocialApp(
      name: 'YouTube',
      icon: FontAwesomeIcons.youtube,
      color: Color(0xFFFF0000),
      url: 'https://www.youtube.com',
    ),
    SocialApp(
      name: 'Facebook',
      icon: FontAwesomeIcons.facebook,
      color: Color(0xFF1877F2),
      url: 'https://www.facebook.com',
    ),
    SocialApp(
      name: 'Instagram',
      icon: FontAwesomeIcons.instagram,
      color: Color(0xFFE1306C),
      url: 'https://www.instagram.com',
    ),
    SocialApp(
      name: 'TikTok',
      icon: FontAwesomeIcons.tiktok,
      color: Color(0xFF000000),
      url: 'https://www.tiktok.com',
    ),
    SocialApp(
      name: 'X',
      icon: FontAwesomeIcons.xTwitter,
      color: Color(0xFF000000),
      url: 'https://x.com',
    ),
  ];
}
