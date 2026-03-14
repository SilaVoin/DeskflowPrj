String pluralizeRu(int count, String one, String few, String many) {
  final mod10 = count % 10;
  final mod100 = count % 100;

  if (mod100 >= 11 && mod100 <= 19) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}
