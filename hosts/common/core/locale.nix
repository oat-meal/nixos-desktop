# Locale and timezone configuration

{ lib, ... }:

{
  # en_DK: English language with ISO 8601 dates (YYYY-MM-DD) and metric units
  i18n.defaultLocale = lib.mkDefault "en_DK.UTF-8";
  # System timezone matches user's local time (Mountain)
  # Avoids mismatch between system services and user shell
  time.timeZone = lib.mkDefault "America/Denver";
}
