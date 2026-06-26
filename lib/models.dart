// All data models. Pure data — no storage logic (that's in repo.dart).

enum PunchType { shiftIn, shiftOut, lunchOut, lunchIn }

String punchLabel(PunchType t) {
  switch (t) {
    case PunchType.shiftIn:
      return 'Shift In';
    case PunchType.shiftOut:
      return 'Shift Out';
    case PunchType.lunchOut:
      return 'Lunch Out';
    case PunchType.lunchIn:
      return 'Lunch In';
  }
}

PunchType punchFromName(String n) =>
    PunchType.values.firstWhere((e) => e.name == n, orElse: () => PunchType.shiftIn);

// Admin / business owner account
class AppUser {
  final String id;
  final String businessName;
  final String businessType;
  final String ownerName;
  final String username;
  final String passHash;
  final bool multiLocation;
  final bool askOnScan;     // show action popup on scan
  final bool lunchTracking; // allow lunch in/out at all
  final int createdAt;

  AppUser({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.ownerName,
    required this.username,
    required this.passHash,
    required this.multiLocation,
    this.askOnScan = true,
    this.lunchTracking = true,
    required this.createdAt,
  });

  AppUser copyWith({bool? askOnScan, bool? lunchTracking, bool? multiLocation}) =>
      AppUser(
        id: id,
        businessName: businessName,
        businessType: businessType,
        ownerName: ownerName,
        username: username,
        passHash: passHash,
        multiLocation: multiLocation ?? this.multiLocation,
        askOnScan: askOnScan ?? this.askOnScan,
        lunchTracking: lunchTracking ?? this.lunchTracking,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessName': businessName,
        'businessType': businessType,
        'ownerName': ownerName,
        'username': username,
        'passHash': passHash,
        'multiLocation': multiLocation,
        'askOnScan': askOnScan,
        'lunchTracking': lunchTracking,
        'createdAt': createdAt,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        businessName: j['businessName'] ?? '',
        businessType: j['businessType'] ?? '',
        ownerName: j['ownerName'] ?? '',
        username: j['username'] ?? '',
        passHash: j['passHash'] ?? '',
        multiLocation: j['multiLocation'] ?? false,
        askOnScan: j['askOnScan'] ?? true,
        lunchTracking: j['lunchTracking'] ?? true,
        createdAt: j['createdAt'] ?? 0,
      );
}

class WorkLocation {
  final String id;
  final String ownerId;
  final String name;
  final double lat;
  final double lng;
  final double radius; // meters

  WorkLocation({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.lat,
    required this.lng,
    this.radius = 30,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius': radius,
      };

  factory WorkLocation.fromJson(Map<String, dynamic> j) => WorkLocation(
        id: j['id'],
        ownerId: j['ownerId'] ?? '',
        name: j['name'] ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        radius: (j['radius'] as num?)?.toDouble() ?? 30,
      );
}

class Employee {
  final String id;
  final String ownerId;
  final String name;
  final String empId;
  final String phone;
  final String department;
  final String designation;
  final String locationId; // assigned work location ('' = any)
  final double monthlySalary;
  final double perDaySalary;
  final String shiftStart; // "HH:mm"
  final String shiftEnd;
  final bool lunchEnabled;
  final String joinDate; // yyyy-MM-dd
  final bool active;
  final String photo; // base64
  final List<List<double>> templates;
  final int createdAt;

  Employee({
    required this.id,
    required this.ownerId,
    required this.name,
    this.empId = '',
    this.phone = '',
    this.department = '',
    this.designation = '',
    this.locationId = '',
    this.monthlySalary = 0,
    this.perDaySalary = 0,
    this.shiftStart = '09:00',
    this.shiftEnd = '18:00',
    this.lunchEnabled = false,
    this.joinDate = '',
    this.active = true,
    this.photo = '',
    this.templates = const [],
    required this.createdAt,
  });

  Employee copyWith({
    String? name,
    String? empId,
    String? phone,
    String? department,
    String? designation,
    String? locationId,
    double? monthlySalary,
    double? perDaySalary,
    String? shiftStart,
    String? shiftEnd,
    bool? lunchEnabled,
    String? joinDate,
    bool? active,
    String? photo,
    List<List<double>>? templates,
  }) =>
      Employee(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        empId: empId ?? this.empId,
        phone: phone ?? this.phone,
        department: department ?? this.department,
        designation: designation ?? this.designation,
        locationId: locationId ?? this.locationId,
        monthlySalary: monthlySalary ?? this.monthlySalary,
        perDaySalary: perDaySalary ?? this.perDaySalary,
        shiftStart: shiftStart ?? this.shiftStart,
        shiftEnd: shiftEnd ?? this.shiftEnd,
        lunchEnabled: lunchEnabled ?? this.lunchEnabled,
        joinDate: joinDate ?? this.joinDate,
        active: active ?? this.active,
        photo: photo ?? this.photo,
        templates: templates ?? this.templates,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'empId': empId,
        'phone': phone,
        'department': department,
        'designation': designation,
        'locationId': locationId,
        'monthlySalary': monthlySalary,
        'perDaySalary': perDaySalary,
        'shiftStart': shiftStart,
        'shiftEnd': shiftEnd,
        'lunchEnabled': lunchEnabled,
        'joinDate': joinDate,
        'active': active,
        'photo': photo,
        'templates': templates,
        'createdAt': createdAt,
      };

  factory Employee.fromJson(Map<String, dynamic> j) {
    List<List<double>> tpl = [];
    if (j['templates'] is List) {
      tpl = (j['templates'] as List)
          .map<List<double>>(
              (e) => (e as List).map((v) => (v as num).toDouble()).toList())
          .toList();
    }
    return Employee(
      id: j['id'],
      ownerId: j['ownerId'] ?? '',
      name: j['name'] ?? '',
      empId: j['empId'] ?? '',
      phone: j['phone'] ?? '',
      department: j['department'] ?? '',
      designation: j['designation'] ?? '',
      locationId: j['locationId'] ?? '',
      monthlySalary: (j['monthlySalary'] as num?)?.toDouble() ?? 0,
      perDaySalary: (j['perDaySalary'] as num?)?.toDouble() ?? 0,
      shiftStart: j['shiftStart'] ?? '09:00',
      shiftEnd: j['shiftEnd'] ?? '18:00',
      lunchEnabled: j['lunchEnabled'] ?? false,
      joinDate: j['joinDate'] ?? '',
      active: j['active'] ?? true,
      photo: j['photo'] ?? '',
      templates: tpl,
      createdAt: j['createdAt'] ?? 0,
    );
  }
}

class AttEvent {
  final String id;
  final String empId;
  final String ownerId;
  final PunchType type;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm:ss
  final int ts;
  final double? lat;
  final double? lng;
  final bool manual;
  final String note;

  AttEvent({
    required this.id,
    required this.empId,
    required this.ownerId,
    required this.type,
    required this.date,
    required this.time,
    required this.ts,
    this.lat,
    this.lng,
    this.manual = false,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'empId': empId,
        'ownerId': ownerId,
        'type': type.name,
        'date': date,
        'time': time,
        'ts': ts,
        'lat': lat,
        'lng': lng,
        'manual': manual,
        'note': note,
      };

  factory AttEvent.fromJson(Map<String, dynamic> j) => AttEvent(
        id: j['id'],
        empId: j['empId'],
        ownerId: j['ownerId'] ?? '',
        type: punchFromName(j['type'] ?? 'shiftIn'),
        date: j['date'],
        time: j['time'],
        ts: j['ts'] ?? 0,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        manual: j['manual'] ?? false,
        note: j['note'] ?? '',
      );
}

// Session: who is using the app right now
class Session {
  final String role; // 'admin' | 'staff'
  final String ownerId;
  Session(this.role, this.ownerId);
}


// ===== Leave =====
enum LeaveType { casual, sick, paid, unpaid }

String leaveLabel(LeaveType t) {
  switch (t) {
    case LeaveType.casual:
      return 'Casual';
    case LeaveType.sick:
      return 'Sick';
    case LeaveType.paid:
      return 'Paid';
    case LeaveType.unpaid:
      return 'Unpaid';
  }
}

LeaveType leaveFromName(String n) =>
    LeaveType.values.firstWhere((e) => e.name == n, orElse: () => LeaveType.casual);

class LeaveRequest {
  final String id;
  final String ownerId;
  final String empId;
  final LeaveType type;
  final String fromDate; // yyyy-MM-dd
  final String toDate;
  final double days;
  final String reason;
  final String status; // pending | approved | rejected
  final int createdAt;

  LeaveRequest({
    required this.id,
    required this.ownerId,
    required this.empId,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.days,
    this.reason = '',
    this.status = 'pending',
    required this.createdAt,
  });

  LeaveRequest copyWith({String? status}) => LeaveRequest(
        id: id,
        ownerId: ownerId,
        empId: empId,
        type: type,
        fromDate: fromDate,
        toDate: toDate,
        days: days,
        reason: reason,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'empId': empId,
        'type': type.name,
        'fromDate': fromDate,
        'toDate': toDate,
        'days': days,
        'reason': reason,
        'status': status,
        'createdAt': createdAt,
      };

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
        id: j['id'],
        ownerId: j['ownerId'] ?? '',
        empId: j['empId'] ?? '',
        type: leaveFromName(j['type'] ?? 'casual'),
        fromDate: j['fromDate'] ?? '',
        toDate: j['toDate'] ?? '',
        days: (j['days'] as num?)?.toDouble() ?? 1,
        reason: j['reason'] ?? '',
        status: j['status'] ?? 'pending',
        createdAt: j['createdAt'] ?? 0,
      );
}


// ===== Money ledger (khata): advance / bonus / salary paid / expense / deduction =====
enum PayType { advance, bonus, salary, expense, deduction }

String payLabel(PayType t) {
  switch (t) {
    case PayType.advance:
      return 'Advance';
    case PayType.bonus:
      return 'Bonus';
    case PayType.salary:
      return 'Salary Paid';
    case PayType.expense:
      return 'Expense';
    case PayType.deduction:
      return 'Deduction';
  }
}

PayType payFromName(String n) =>
    PayType.values.firstWhere((e) => e.name == n, orElse: () => PayType.advance);

class Payment {
  final String id;
  final String ownerId;
  final String empId;
  final PayType type;
  final double amount;
  final String date; // yyyy-MM-dd
  final String note;
  final int createdAt;

  Payment({
    required this.id,
    required this.ownerId,
    required this.empId,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'empId': empId,
        'type': type.name,
        'amount': amount,
        'date': date,
        'note': note,
        'createdAt': createdAt,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'],
        ownerId: j['ownerId'] ?? '',
        empId: j['empId'] ?? '',
        type: payFromName(j['type'] ?? 'advance'),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: j['date'] ?? '',
        note: j['note'] ?? '',
        createdAt: j['createdAt'] ?? 0,
      );
}


// ===== Shift templates =====
class Shift {
  final String id;
  final String ownerId;
  final String name;
  final String start; // HH:mm
  final String end;
  Shift({required this.id, required this.ownerId, required this.name,
        required this.start, required this.end});
  Map<String, dynamic> toJson() =>
      {'id': id, 'ownerId': ownerId, 'name': name, 'start': start, 'end': end};
  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
      id: j['id'], ownerId: j['ownerId'] ?? '', name: j['name'] ?? '',
      start: j['start'] ?? '09:00', end: j['end'] ?? '18:00');
}
