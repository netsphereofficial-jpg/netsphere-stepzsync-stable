class Participant {
  final int userId;
  final String userName;
  final double distance;
  final double calories;
  final double avgSpeed;
  final int rank;
  final double remainingDistance;

  Participant({
    required this.userId,
    required this.userName,
    required this.distance,
    required this.calories,
    required this.avgSpeed,
    required this.rank,
    required this.remainingDistance,
  });

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      userId: map['userId'] as int,
      userName: map['userName'] ?? '',
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      avgSpeed: (map['avgSpeed'] as num?)?.toDouble() ?? 0.0,
      rank: map['rank'] as int,
      remainingDistance: (map['remainingDistance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'distance': distance,
      'calories': calories,
      'avgSpeed': avgSpeed,
      'rank': rank,
      'remainingDistance': remainingDistance,
    };
  }
}
