import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import '../../services/auth_service.dart';
import '../../models/models.dart';

// ─── EVENTS ───────────────────────────────────────────────────
abstract class AuthEvent extends Equatable {
  @override List<Object?> get props => [];
}
class AuthStarted extends AuthEvent {}
class AuthLoginRequested extends AuthEvent {
  final String email, password;
  AuthLoginRequested(this.email, this.password);
  @override List<Object?> get props => [email, password];
}
class AuthLogoutRequested extends AuthEvent {}

// ─── STATES ───────────────────────────────────────────────────
abstract class AuthState extends Equatable {
  @override List<Object?> get props => [];
}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final UsuarioModel usuario;
  AuthAuthenticated(this.usuario);
  @override List<Object?> get props => [usuario];
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override List<Object?> get props => [message];
}

// ─── BLOC ─────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;

  AuthBloc({required this.authService}) : super(AuthLoading()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  // Escucha la sesión de Firebase mientras el bloc esté vivo
  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) {
    return emit.forEach<AuthState>(
      authService.authStateChanges.asyncMap(_resolverUsuario),
      onData: (state) => state,
      onError: (_, __) => AuthUnauthenticated(),
    );
  }

  Future<AuthState> _resolverUsuario(User? user) async {
    if (user == null) return AuthUnauthenticated();
    final usuario = await authService.getUsuario(user.uid);
    if (usuario != null && usuario.activo) return AuthAuthenticated(usuario);
    await authService.signOut();
    return AuthUnauthenticated();
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final usuario = await authService.signIn(event.email, event.password);
      if (usuario == null) {
        await authService.signOut();
        emit(AuthError('Usuario no registrado en el sistema'));
      } else if (!usuario.activo) {
        await authService.signOut();
        emit(AuthError('Cuenta deshabilitada'));
      } else {
        emit(AuthAuthenticated(usuario));
      }
    } on Exception catch (e) {
      emit(AuthError(_mapError(e.toString())));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await authService.signOut();
    emit(AuthUnauthenticated());
  }

  String _mapError(String e) {
    if (e.contains('invalid-credential')) return 'Correo o contraseña incorrectos';
    if (e.contains('user-not-found'))    return 'Correo no registrado';
    if (e.contains('wrong-password'))    return 'Contraseña incorrecta';
    if (e.contains('invalid-email'))     return 'Correo inválido';
    if (e.contains('user-disabled'))     return 'Cuenta deshabilitada';
    if (e.contains('too-many-requests')) return 'Demasiados intentos. Espera un momento';
    return 'Error al iniciar sesión. Intenta de nuevo';
  }
}
