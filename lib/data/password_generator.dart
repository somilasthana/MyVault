import 'dart:math';

enum PasswordStyle { all, easyRead, easySay }

enum PasswordStrength { poor, average, excellent }

const passwordLengthMin = 8;
const passwordLengthMax = 32;

String generatePassword({
  required int length,
  required PasswordStyle style,
  Random? random,
}) {
  final count = length.clamp(passwordLengthMin, passwordLengthMax);
  final rng = random ?? Random.secure();
  final pools = _pools(style);
  final alphabet = pools.join();
  final chars = <String>[
    for (final pool in pools) pool[rng.nextInt(pool.length)],
  ];
  while (chars.length < count) {
    chars.add(alphabet[rng.nextInt(alphabet.length)]);
  }
  chars.shuffle(rng);
  return chars.join();
}

PasswordStrength ratePassword(String password) {
  final kinds = _kindCount(password);
  if (password.length < passwordLengthMin || kinds <= 1) {
    return PasswordStrength.poor;
  }
  if (password.length >= 12 && kinds >= 3) return PasswordStrength.excellent;
  return PasswordStrength.average;
}

String strengthLabel(PasswordStrength strength) {
  return switch (strength) {
    PasswordStrength.poor => 'Poor',
    PasswordStrength.average => 'Average',
    PasswordStrength.excellent => 'Excellent',
  };
}

int _kindCount(String password) {
  var kinds = 0;
  if (RegExp('[a-z]').hasMatch(password)) kinds += 1;
  if (RegExp('[A-Z]').hasMatch(password)) kinds += 1;
  if (RegExp(r'\d').hasMatch(password)) kinds += 1;
  if (RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) kinds += 1;
  return kinds;
}

List<String> _pools(PasswordStyle style) {
  const lower = 'abcdefghijklmnopqrstuvwxyz';
  const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const digits = '0123456789';
  const symbols = r'!@#$%^&*()-_=+[]{};:,.?';
  return switch (style) {
    PasswordStyle.easySay => [lower, upper],
    PasswordStyle.easyRead => [
      'abcdefghijkmnpqrstuvwxyz',
      'ABCDEFGHJKLMNPQRSTUVWXYZ',
      '23456789',
      symbols,
    ],
    PasswordStyle.all => [lower, upper, digits, symbols],
  };
}
