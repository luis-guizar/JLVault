class Account {
  final int? id;
  final String name;
  final String username;
  final String password;

  Account({
    this.id,
    required this.name,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'username': username,
    'password': password,
  };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
    id: map['id'],
    name: map['name'],
    username: map['username'],
    password: map['password'],
  );
}
