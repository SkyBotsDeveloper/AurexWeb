T? asOrNull<T>(dynamic value) => value is T ? value : null;

final RegExp _htmlNumericEntityPattern = RegExp(r'&#(x?[0-9A-Fa-f]+);');
const Map<String, String> _htmlNamedEntities = {
  '&quot;': '"',
  '&#34;': '"',
  '&apos;': "'",
  '&#39;': "'",
  '&#x27;': "'",
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': ' ',
};

String? readString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = _decodeHtmlEntities(value.toString()).trim();
  return text.isEmpty ? null : text;
}

String _decodeHtmlEntities(String value) {
  var decoded = value;
  for (final entry in _htmlNamedEntities.entries) {
    decoded = decoded.replaceAll(entry.key, entry.value);
  }
  return decoded.replaceAllMapped(_htmlNumericEntityPattern, (match) {
    final raw = match.group(1);
    if (raw == null) {
      return match.group(0) ?? '';
    }
    final isHex = raw.startsWith('x') || raw.startsWith('X');
    final codePoint = int.tryParse(
      isHex ? raw.substring(1) : raw,
      radix: isHex ? 16 : 10,
    );
    if (codePoint == null) {
      return match.group(0) ?? '';
    }
    return String.fromCharCode(codePoint);
  });
}

int? readInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

bool readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

Map<String, dynamic> readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> readMapList(dynamic value) {
  if (value is List) {
    return value.map(readMap).toList();
  }
  return const [];
}
