import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.radius,
    required this.revision,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final String? avatarUrl;
  final double radius;
  final int revision;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final normalized = avatarUrl?.trim();
    if (normalized == null || normalized.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Icon(
          Icons.person,
          color: iconColor ?? Theme.of(context).colorScheme.primary,
          size: iconSize ?? radius,
        ),
      );
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      final separator = normalized.contains('?') ? '&' : '?';
      final cacheBustedUrl = '$normalized${separator}v=$revision';
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: NetworkImage(cacheBustedUrl),
      );
    }

    return _FileProfileAvatar(
      key: ValueKey('$normalized-$revision'),
      path: normalized,
      radius: radius,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      iconSize: iconSize,
    );
  }
}

class _FileProfileAvatar extends StatefulWidget {
  const _FileProfileAvatar({
    super.key,
    required this.path,
    required this.radius,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final String path;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  @override
  State<_FileProfileAvatar> createState() => _FileProfileAvatarState();
}

class _FileProfileAvatarState extends State<_FileProfileAvatar> {
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _readBytes();
  }

  Future<Uint8List?> _readBytes() async {
    final file = File(widget.path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            radius: widget.radius,
            backgroundColor: widget.backgroundColor,
            backgroundImage: MemoryImage(snapshot.data!),
          );
        }

        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.backgroundColor,
          child: Icon(
            Icons.person,
            color: widget.iconColor ?? Theme.of(context).colorScheme.primary,
            size: widget.iconSize ?? widget.radius,
          ),
        );
      },
    );
  }
}
