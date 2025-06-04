import 'package:docsera/models/document.dart';
import 'package:equatable/equatable.dart';

/// ✅ **Base class for all Documents states**
abstract class DocumentsState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// 🔄 **Loading Documents**
class DocumentsLoading extends DocumentsState {}

/// ✅ **User is NOT logged in**
class DocumentsNotLogged extends DocumentsState {}

/// ✅ **Documents loaded successfully**
class DocumentsLoaded extends DocumentsState {
  final List<UserDocument> documents;

  DocumentsLoaded(this.documents);
}

/// ⚠️ **Error loading Documents**
class DocumentsError extends DocumentsState {
  final String message;

  DocumentsError(this.message);

  @override
  List<Object?> get props => [message];
}
