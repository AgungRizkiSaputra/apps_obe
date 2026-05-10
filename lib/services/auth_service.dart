import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {

  final supabase = Supabase.instance.client;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {

    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    return response;
  }
}