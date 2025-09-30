class AppValidators {
  AppValidators._();

  static final _nameRegExp = RegExp(r'^[A-Za-zÀ-ž\s-]{2,}$');
  static final _phoneRegExp = RegExp(r'^[0-9+()\s-]{6,}$');

  static String? validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Zadejte prosím jméno';
    }
    if (!_nameRegExp.hasMatch(value.trim())) {
      return 'Jméno nesmí obsahovat čísla';
    }
    return null;
  }

  static String? validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Zadejte prosím příjmení';
    }
    if (!_nameRegExp.hasMatch(value.trim())) {
      return 'Příjmení musí obsahovat pouze písmena';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Zadejte prosím e-mail';
    }
      const emailPattern =
          r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$';
    final regExp = RegExp(emailPattern, caseSensitive: false);
    if (!regExp.hasMatch(value.trim())) {
      return 'E-mail musí obsahovat @ a platnou doménu';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Zadejte heslo';
    }
    if (value.length < 8) {
      return 'Heslo musí mít alespoň 8 znaků';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Zadejte telefonní číslo';
    }
    if (!_phoneRegExp.hasMatch(value.trim())) {
      return 'Telefonní číslo není ve správném formátu';
    }
    return null;
  }

  static String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Povinné pole';
    }
    return null;
  }
}
