import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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
  StreamSubscription? _authSub;

  AuthBloc({required this.authService}) : super(AuthLoading()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  void _onStarted(AuthStarted event, Emitter<AuthState> emit) {
    _authSub?.cancel();
    _authSub = authService.authStateChanges.listen((user) async {
      if (user != null) {
        final usuario = await authService.getUsuario(user.uid);
        if (usuario != null && usuario.activo) {
          emit(AuthAuthenticated(usuario));
        } else {
          await authService.signOut();
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    });
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final usuario = await authService.signIn(event.email, event.password);
      if (usuario != null) {
        emit(AuthAuthenticated(usuario));
      } else {
        emit(AuthError('Usuario no encontrado'));
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
    if (e.contains('user-not-found'))    return 'Correo no registrado';
    if (e.contains('wrong-password'))    return 'Contraseña incorrecta';
    if (e.contains('invalid-email'))     return 'Correo inválido';
    if (e.contains('user-disabled'))     return 'Cuenta deshabilitada';
    if (e.contains('too-many-requests')) return 'Demasiados intentos. Espera un momento';
    return 'Error al iniciar sesión. Intenta de nuevo';
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
