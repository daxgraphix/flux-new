import 'dart:convert';

class RdsParser {
  // Decode Program Service (PS) name from RDS block
  static String decodePs(int blockA, int blockB, int blockC, int blockD) {
    // PS is 8 characters in blockB and blockC (4 chars each)
    final segment1 = blockB & 0xFFFF;
    final segment2 = (blockB >> 16) & 0xFFFF;
    final segment3 = blockC & 0xFFFF;
    final segment4 = (blockC >> 16) & 0xFFFF;

    return String.fromCharCodes([
      segment1,
      segment2,
      segment3,
      segment4,
    ]).replaceAll(RegExp(r'[^\x20-\x7E]'), ''); // Strip non-printable
  }

  // Decode Radio Text (RT) A/B blocks
  static String decodeRt(
    int blockA,
    int blockB,
    int blockC,
    int blockD, {
    bool isTypeA = true,
  }) {
    // RT is 64 characters for type A, 128 for type B
    final segments = [
      blockB & 0xFF,
      (blockB >> 8) & 0xFF,
      blockC & 0xFF,
      (blockC >> 8) & 0xFF,
    ];

    return String.fromCharCodes(
      segments,
    ).replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  // Decode hex string to ASCII
  static String hexToAscii(String hex) {
    if (hex.isEmpty) return '';
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      try {
        bytes.add(int.parse(hexByte, radix: 16));
      } catch (e) {
        bytes.add(0);
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  // Extract PS from RDS raw buffer (simplified)
  static String extractPsFromBuffer(List<int> buffer) {
    if (buffer.length < 8) return '';
    var ps = '';
    for (var i = 0; i < 8 && i < buffer.length; i++) {
      if (buffer[i] >= 32 && buffer[i] <= 126) {
        ps += String.fromCharCode(buffer[i]);
      }
    }
    return ps;
  }

  // Extract RT from RDS raw buffer (simplified)
  static String extractRtFromBuffer(List<int> buffer, {int offset = 8}) {
    if (buffer.length < offset) return '';
    var rt = '';
    for (var i = offset; i < buffer.length && i < offset + 64; i++) {
      if (buffer[i] >= 32 && buffer[i] <= 126) {
        rt += String.fromCharCode(buffer[i]);
      }
    }
    return rt;
  }
}
