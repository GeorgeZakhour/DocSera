import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_service.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_state.dart';
import 'package:docsera/models/document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDocumentsService extends Mock implements DocumentsService {}

void main() {
  late DocumentsCubit documentsCubit;
  late MockDocumentsService mockService;

  setUp(() {
    mockService = MockDocumentsService();
    documentsCubit = DocumentsCubit(service: mockService);
  });

  tearDown(() {
    documentsCubit.close();
  });

  group('DocumentsCubit', () {
    const userId = 'user-123';
    final mockDoc = UserDocument(
      id: 'doc-1',
      userId: userId,
      name: 'Test Doc',
      type: 'image',
      fileType: 'image',
      previewUrl: 'http://example.com/preview.jpg',
      pages: ['http://example.com/page1.jpg'],
      uploadedAt: DateTime.now(),
      uploadedById: userId,
      patientId: userId, // Added required field
    );

    test('initial state is DocumentsLoading', () {
      expect(documentsCubit.state, isA<DocumentsLoading>());
    });

    blocTest<DocumentsCubit, DocumentsState>(
      'emits [DocumentsLoaded] when listenToDocuments is called',
      build: () {
        when(() => mockService.subscribeToDocuments(any(), any()))
            .thenReturn(null);
        when(() => mockService.fetchDocuments(userId))
            .thenAnswer((_) async => [mockDoc]);
        return documentsCubit;
      },
      act: (cubit) => cubit.listenToDocuments(explicitUserId: userId),
      expect: () => [
        isA<DocumentsLoading>(),
        isA<DocumentsLoaded>()
            .having((state) => state.documents.length, 'length', 1),
      ],
    );

    blocTest<DocumentsCubit, DocumentsState>(
      'calls deleteDocument and reload documents',
      build: () {
        when(() => mockService.deleteDocument(any(), any()))
            .thenAnswer((_) async => {});
        when(() => mockService.deleteFiles(any()))
             .thenAnswer((_) async => {});
        
        // Setup re-fetch logic
        when(() => mockService.subscribeToDocuments(any(), any()))
            .thenReturn(null);
        when(() => mockService.fetchDocuments(userId))
            .thenAnswer((_) async => []); // Empty after delete

        return documentsCubit;
      },
      act: (cubit) => cubit.deleteDocument(
          document: mockDoc, 
          explicitUserId: userId
      ),
      verify: (cubit) {
        verify(() => mockService.deleteDocument(mockDoc.id!, userId)).called(1);
        verify(() => mockService.deleteFiles(mockDoc.pages)).called(1);
      },
      expect: () => [
         isA<DocumentsLoading>(),
         isA<DocumentsLoaded>().having((s) => s.documents.isEmpty, 'is empty', true),
      ]
    );

  });
}
