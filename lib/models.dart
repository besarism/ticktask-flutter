
class Category {
  String name;
  List<ToDoItem> items;

  Category({required this.name, required this.items});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['name'],
      items: List<ToDoItem>.from(
        (json['items'] as List<dynamic>).map(
              (item) => ToDoItem.fromJson(item as Map<String, dynamic>),
        ),
      ),
    );
  }

}

class ToDoItem {
  String title;
  bool isDone;

  ToDoItem({required this.title, this.isDone = false});


  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isDone': isDone,
    };
  }

  factory ToDoItem.fromJson(Map<String, dynamic> json) {
    return ToDoItem(
      title: json['title'],
      isDone: json['isDone'],
    );
  }
}
