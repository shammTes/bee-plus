// Small strict JSON helpers: a wrong type throws a FormatException naming the field, so the parse test finds bad content.

typedef Json = Map<String, dynamic>;

class J {
  final Json m;
  final String where;
  J(Object? o, this.where) : m = o is Map<String, dynamic> ? o : throw FormatException('$where: expected an object, got ${o.runtimeType}');

  bool has(String k) => m.containsKey(k) && m[k] != null;

  T _req<T>(String k) {
    final v = m[k];
    if (v is T) return v;
    throw FormatException('$where.$k: expected $T, got ${v.runtimeType}');
  }

  String str(String k) => _req<String>(k);
  String? strOr(String k) {
    final v = m[k];
    if (v == null) return null;
    if (v is String) return v;
    throw FormatException('$where.$k: expected String?, got ${v.runtimeType}');
  }

  int integer(String k) => _req<num>(k).toInt();
  int? intOr(String k) {
    final v = m[k];
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String && int.tryParse(v) != null) return int.parse(v);
    throw FormatException('$where.$k: expected int?, got ${v.runtimeType}');
  }

  double number(String k) => _req<num>(k).toDouble();
  double? numOr(String k) {
    final v = m[k];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    throw FormatException('$where.$k: expected num?, got ${v.runtimeType}');
  }

  bool boolean(String k, [bool? def]) {
    final v = m[k];
    if (v == null && def != null) return def;
    if (v is bool) return v;
    throw FormatException('$where.$k: expected bool, got ${v.runtimeType}');
  }

  List<dynamic> list(String k, {bool optional = false}) {
    final v = m[k];
    if (v == null && optional) return const [];
    if (v is List) return v;
    throw FormatException('$where.$k: expected List, got ${v.runtimeType}');
  }

  List<String> strs(String k, {bool optional = false}) => [
    for (final (i, x) in list(k, optional: optional).indexed) x is String ? x : throw FormatException('$where.$k[$i]: expected String, got ${x.runtimeType}'),
  ];

  /// A field that is either one string or a list of strings (e.g. graph "s", model "task").
  List<String> strOrStrs(String k) {
    final v = m[k];
    if (v == null) return const [];
    if (v is String) return [v];
    return strs(k);
  }

  List<T> objs<T>(String k, T Function(J j) f, {bool optional = false}) => [for (final (i, x) in list(k, optional: optional).indexed) f(J(x, '$where.$k[$i]'))];

  Map<String, String> strMap(String k, {bool optional = false}) {
    final v = m[k];
    if (v == null && optional) return const {};
    if (v is! Map) throw FormatException('$where.$k: expected Map, got ${v.runtimeType}');
    return {for (final e in v.entries) e.key as String: e.value is String ? e.value as String : throw FormatException('$where.$k.${e.key}: expected String')};
  }

  J obj(String k) => J(m[k], '$where.$k');
  J? objOr(String k) => m[k] == null ? null : J(m[k], '$where.$k');
}
