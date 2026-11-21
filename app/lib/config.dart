/// Configuración de compilación.
///
/// Se pasa al compilar:
///   flutter build apk --release \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ... \
///     --dart-define=APP_KIND=coach        (o "client")
///
/// La clave anon es pública por diseño (los permisos los fija RLS en la base de
/// datos). NUNCA se incluye aquí la service_role ni la clave de Anthropic.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// 'coach' = app de Tony (atleta + entrenador). 'client' = app de clientes.
  static const appKind = String.fromEnvironment('APP_KIND', defaultValue: 'coach');

  static bool get cloudConfigured => supabaseUrl.isNotEmpty && anonKey.isNotEmpty;
  static bool get isClientApp => appKind == 'client';

  /// Versión del texto de consentimiento (se guarda con cada alta).
  static const consentVersion = '2026-11-v1';

  /// Edad por debajo de la cual se exige consentimiento del tutor.
  /// PROVISIONAL: confirmar con la normativa aplicable (en España, 14 años para
  /// consentir tratamiento de datos; menores de 18 conviene dejar constancia).
  static const guardianUnderAge = 18;
  static const minimumAge = 12;
}
