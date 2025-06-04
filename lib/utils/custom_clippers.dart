import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'dart:math' as math;
import 'package:svg_path_parser/svg_path_parser.dart';


/// **🔹 Custom Clipper for the Top Section**
class CustomTopBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// **🔹 Custom Clipper for Organic Circle Shapes**
class OrganicCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.2, size.width * 0.75, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.6, size.height * 0.9, size.width * 0.3, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.5, size.width * 0.2, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.4, 0, size.width * 0.5, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// **🔹 Custom Clipper for the Background Circle in Professional Section**
class CustomBackgroundCircle extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.moveTo(size.width * 0.4, 0);
    path.quadraticBezierTo(size.width * 0.8, size.height * 0.2, size.width * 0.7, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.6, size.height * 0.9, size.width * 0.3, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.5, size.width * 0.15, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.3, 0, size.width * 0.4, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}



/// **🔹 Perfectly Smooth Background Shape**
class ProfessionalBackgroundClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();

    path.moveTo(size.width * 0.2, size.height * 0.05);
    path.quadraticBezierTo(size.width * 0.6, -size.height * 0.1, size.width * 0.9, size.height * 0.25);
    path.quadraticBezierTo(size.width * 1.1, size.height * 0.6, size.width * 0.8, size.height * 0.85);
    path.quadraticBezierTo(size.width * 0.5, size.height * 1.1, size.width * 0.2, size.height * 0.85);
    path.quadraticBezierTo(-size.width * 0.1, size.height * 0.5, size.width * 0.2, size.height * 0.05);

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

/// **🔹 Ultra Smooth, Randomly Wavy Image Clipper**
class ProfessionalImageClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();

    path.moveTo(size.width * 0.3, 0);
    path.quadraticBezierTo(size.width * 0.8, -10, size.width * 0.95, size.height * 0.3);
    path.quadraticBezierTo(size.width, size.height * 0.6, size.width * 0.7, size.height * 0.95);
    path.quadraticBezierTo(size.width * 0.4, size.height * 1.05, size.width * 0.1, size.height * 0.8);
    path.quadraticBezierTo(-size.width * 0.05, size.height * 0.5, size.width * 0.3, 0);

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}


/// A generic clipper that takes any raw SVG path data (the big "d" string).
class SvgPathClipper extends CustomClipper<Path> {
  final String svgPathData;

  SvgPathClipper(this.svgPathData);

    @override
    Path getClip(Size size) {
      final Path originalPath = parseSvgPathData(svgPathData);
      final Rect bounds = originalPath.getBounds();
      print('DEBUG: shape bounds = $bounds, container size = $size');

      final double widthScale = size.width / bounds.width;
      final double heightScale = size.height / bounds.height;
      final double scale = math.min(widthScale, heightScale);

      final double scaledW = bounds.width * scale;
      final double scaledH = bounds.height * scale;
      final double dx = (size.width - scaledW) / 2.0;
      final double dy = (size.height - scaledH) / 2.0;

      final Matrix4 matrix = Matrix4.identity()
        ..translate(-bounds.left, -bounds.top)
        ..scale(scale, scale)
        ..translate(dx / scale, dy / scale); // center

      return originalPath.transform(matrix.storage);
    }


  @override
  bool shouldReclip(SvgPathClipper oldClipper) {
    return oldClipper.svgPathData != svgPathData;
  }
}
