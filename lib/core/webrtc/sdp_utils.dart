/// Small SDP readers for the talk channel diagnostics (V2.1 §2).
library;

/// The `m=<kind>` sections of [sdp] (each from its `m=` line to the next).
List<String> _sections(String sdp, String kind) {
  final lines = sdp.split(RegExp(r'\r?\n'));
  final out = <String>[];
  StringBuffer? current;
  for (final line in lines) {
    if (line.startsWith('m=')) {
      if (current != null) out.add(current.toString());
      current = line.startsWith('m=$kind ') ? (StringBuffer()..writeln(line)) : null;
    } else {
      current?.writeln(line);
    }
  }
  if (current != null) out.add(current.toString());
  return out;
}

/// Direction of the first [kind] section: sendrecv, sendonly, recvonly or
/// inactive (sendrecv if the section has no direction line), or null when
/// there is no such section.
String? sdpDirection(String? sdp, {String kind = 'audio'}) {
  if (sdp == null) return null;
  final sections = _sections(sdp, kind);
  if (sections.isEmpty) return null;
  final m = RegExp(r'^a=(sendrecv|sendonly|recvonly|inactive)\s*$', multiLine: true)
      .firstMatch(sections.first);
  return m?.group(1) ?? 'sendrecv';
}

/// `a=mid:` of the first [kind] section, or null.
String? sdpMid(String? sdp, {String kind = 'audio'}) {
  if (sdp == null) return null;
  final sections = _sections(sdp, kind);
  if (sections.isEmpty) return null;
  return RegExp(r'^a=mid:(\S+)', multiLine: true).firstMatch(sections.first)?.group(1);
}
