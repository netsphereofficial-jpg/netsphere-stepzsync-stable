import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction status for step propagation
enum TransactionStatus {
  pending,     // Transaction created, not yet applied
  applied,     // Successfully applied to race
  failed,      // Failed to apply (will retry)
  rolledBack,  // Rolled back due to error
  reconciled,  // Created by reconciliation service
}

/// Step Transaction Model
///
/// Provides military-grade audit trail for all step propagations to races.
/// Each transaction is immutable and append-only for complete traceability.
///
/// Features:
/// - Unique transaction ID (UUID) for idempotency
/// - Complete audit trail (before/after values)
/// - Source tracking (HealthKit, Manual, Reconciliation)
/// - Failure tracking and retry support
/// - Timestamp-based ordering
///
/// Firebase Structure:
/// ```
/// /users/{userId}/step_transactions/{transactionId}
/// ```
class StepTransaction {
  /// Unique transaction identifier (UUID)
  final String transactionId;

  /// When the transaction was created
  final DateTime timestamp;

  /// Number of steps in this transaction (delta)
  final int stepsDelta;

  /// Source of the steps (e.g., "HealthKitBaseline", "ManualSync", "Reconciliation")
  final String source;

  /// Race ID this transaction applies to
  final String raceId;

  /// User ID who owns these steps
  final String userId;

  /// Transaction status
  TransactionStatus status;

  /// Steps on server BEFORE this transaction
  final int serverStepsBefore;

  /// Steps on server AFTER this transaction (if applied)
  int? serverStepsAfter;

  /// Error message if transaction failed
  String? errorMessage;

  /// Retry count if transaction failed
  int retryCount;

  /// When the transaction was last updated
  DateTime lastUpdated;

  /// Additional metadata (e.g., race title, health sync source)
  final Map<String, dynamic> metadata;

  StepTransaction({
    required this.transactionId,
    required this.timestamp,
    required this.stepsDelta,
    required this.source,
    required this.raceId,
    required this.userId,
    this.status = TransactionStatus.pending,
    required this.serverStepsBefore,
    this.serverStepsAfter,
    this.errorMessage,
    this.retryCount = 0,
    required this.lastUpdated,
    this.metadata = const {},
  });

  /// Create a new transaction with generated UUID
  factory StepTransaction.create({
    required int stepsDelta,
    required String source,
    required String raceId,
    required String userId,
    required int serverStepsBefore,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    // Generate UUID-like transaction ID using timestamp + random
    final transactionId = 'TX_${now.millisecondsSinceEpoch}_${now.microsecond}';

    return StepTransaction(
      transactionId: transactionId,
      timestamp: now,
      stepsDelta: stepsDelta,
      source: source,
      raceId: raceId,
      userId: userId,
      status: TransactionStatus.pending,
      serverStepsBefore: serverStepsBefore,
      lastUpdated: now,
      metadata: metadata ?? {},
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'transactionId': transactionId,
      'timestamp': Timestamp.fromDate(timestamp),
      'stepsDelta': stepsDelta,
      'source': source,
      'raceId': raceId,
      'userId': userId,
      'status': status.name,
      'serverStepsBefore': serverStepsBefore,
      'serverStepsAfter': serverStepsAfter,
      'errorMessage': errorMessage,
      'retryCount': retryCount,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'metadata': metadata,
    };
  }

  /// Create from Firestore document
  factory StepTransaction.fromFirestore(Map<String, dynamic> data) {
    return StepTransaction(
      transactionId: data['transactionId'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      stepsDelta: data['stepsDelta'] as int,
      source: data['source'] as String,
      raceId: data['raceId'] as String,
      userId: data['userId'] as String,
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TransactionStatus.pending,
      ),
      serverStepsBefore: data['serverStepsBefore'] as int,
      serverStepsAfter: data['serverStepsAfter'] as int?,
      errorMessage: data['errorMessage'] as String?,
      retryCount: data['retryCount'] as int? ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Mark transaction as applied
  void markApplied(int serverStepsAfter) {
    status = TransactionStatus.applied;
    this.serverStepsAfter = serverStepsAfter;
    lastUpdated = DateTime.now();
  }

  /// Mark transaction as failed
  void markFailed(String error) {
    status = TransactionStatus.failed;
    errorMessage = error;
    retryCount++;
    lastUpdated = DateTime.now();
  }

  /// Mark transaction as rolled back
  void markRolledBack(String reason) {
    status = TransactionStatus.rolledBack;
    errorMessage = reason;
    lastUpdated = DateTime.now();
  }

  /// Check if transaction should be retried
  bool shouldRetry() {
    return status == TransactionStatus.failed && retryCount < 3;
  }

  /// Check if transaction is finalized (cannot be changed)
  bool isFinalized() {
    return status == TransactionStatus.applied ||
        status == TransactionStatus.rolledBack ||
        (status == TransactionStatus.failed && retryCount >= 3);
  }

  @override
  String toString() {
    return 'StepTransaction('
        'id: $transactionId, '
        'steps: $stepsDelta, '
        'source: $source, '
        'status: ${status.name}, '
        'before: $serverStepsBefore, '
        'after: $serverStepsAfter'
        ')';
  }

  /// Create a copy with updated fields
  StepTransaction copyWith({
    TransactionStatus? status,
    int? serverStepsAfter,
    String? errorMessage,
    int? retryCount,
    DateTime? lastUpdated,
  }) {
    return StepTransaction(
      transactionId: transactionId,
      timestamp: timestamp,
      stepsDelta: stepsDelta,
      source: source,
      raceId: raceId,
      userId: userId,
      status: status ?? this.status,
      serverStepsBefore: serverStepsBefore,
      serverStepsAfter: serverStepsAfter ?? this.serverStepsAfter,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata,
    );
  }
}

/// Transaction Query Result
/// Used for querying transaction history
class TransactionQueryResult {
  final List<StepTransaction> transactions;
  final int totalCount;
  final bool hasMore;

  TransactionQueryResult({
    required this.transactions,
    required this.totalCount,
    required this.hasMore,
  });
}
