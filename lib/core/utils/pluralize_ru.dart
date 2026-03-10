/// Russian pluralization utility.
///
/// Returns the correct Russian plural form for a given [count].
///
/// Example:
/// ```dart
/// pluralizeRu(1, 'участник', 'участника', 'участников'); // '1 участник'
/// pluralizeRu(2, 'участник', 'участника', 'участников'); // '2 участника'
/// pluralizeRu(5, 'участник', 'участника', 'участников'); // '5 участников'
/// pluralizeRu(21, 'участник', 'участника', 'участников'); // '21 участник'
/// ```
String pluralizeRu(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return '$n $many';
  if (mod10 == 1) return '$n $one';
  if (mod10 >= 2 && mod10 <= 4) return '$n $few';
  return '$n $many';
}
