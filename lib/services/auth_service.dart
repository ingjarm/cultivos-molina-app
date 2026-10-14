import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Dominio que se agrega cuando se inicia sesión solo con nombre de usuario
  static const dominioUsuarios = 'cultivosmolina.com';

  static String normalizarEmail(String usuarioOEmail) {
    final v = usuarioOEmail.trim().toLowerCase();
    return v.contains('@') ? v : '$v@$dominioUsuarios';
  }

  // Login (acepta "usuario1" o "usuario1@cultivosmolina.com")
  Future<UsuarioModel?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: normalizarEmail(email),
      password: password.trim(),
    );
    if (cred.user == null) return null;
    return await getUsuario(cred.user!.uid);
  }

  // Cerrar sesión
  Future<void> signOut() => _auth.signOut();

  // Recuperar contraseña
  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // Obtener datos del usuario desde Firestore
  Future<UsuarioModel?> getUsuario(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return null;
    return UsuarioModel.fromFirestore(doc);
  }

  // Crear usuario (solo Admin)
  Future<void> crearUsuario({
    required String email,
    required String password,
    required String nombre,
    required String rol,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await _db.collection('usuarios').doc(cred.user!.uid).set({
      'nombre': nombre,
      'email': email.trim(),
      'rol': rol,
      'activo': true,
      'creado_en': Timestamp.now(),
    });
  }
}
