import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'dart:io' hide Category;
import 'package:flutter/foundation.dart' hide Category;
import 'package:hive/hive.dart';
import 'package:ticktask/models.dart';



Future<String> getApplicationDocumentsDirectoryPath() async {
  if (kIsWeb) {
    return '.';
  }

  Directory appDocDir;
  if (Platform.isIOS) {
    appDocDir = await Directory.systemTemp.createTemp();
  } else {
    appDocDir = await Directory('/data/user/0/com.example.my_app/app_flutter')
        .create(recursive: true);
  }
  return appDocDir.path;
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDirectoryPath = await getApplicationDocumentsDirectoryPath();
  Hive.init(appDocumentDirectoryPath);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    _secretPassword = 'your_password'; // Replace this with the user's password
    WidgetsBinding.instance!.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  // ...
  List<Category> _categories = [];
  final storage = FlutterSecureStorage();
  String _secretPassword = '';

  String encryptData(String data, String password) {
    final key = encrypt.Key.fromUtf8('1234567890123456'); // 16-byte key for AES-128
    final iv = encrypt.IV.fromUtf8('abcdefghijklmnop'); // 16-byte IV
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(data, iv: iv);
    return encrypted.base64;
  }

  String decryptData(String encryptedData, String password) {
    final key = encrypt.Key.fromUtf8('1234567890123456');
    final iv = encrypt.IV.fromUtf8('abcdefghijklmnop');
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final decrypted = encrypter.decrypt64(encryptedData, iv: iv);
    return decrypted;
  }



  Future<void> _saveData() async {
    try {
      final encryptedData = encryptData(jsonEncode(_categories), _secretPassword);
      final box = Hive.box('myBox');
      await box.put('data', encryptedData);
    } catch (e) {
      print('Error saving data: $e');
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final box = await Hive.openBox('myBox');
      final encryptedData = box.get('data', defaultValue: '');
      if (encryptedData.isNotEmpty) {
        final decryptedData = decryptData(encryptedData, _secretPassword);
        final List<dynamic> jsonData = jsonDecode(decryptedData);
        setState(() {
          _categories = jsonData.map((e) => Category.fromJson(e)).toList();
        });
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }


  Future<void> _shareData() async {
    String? encryptedData = await storage.read(key: 'todo_list');
    if (encryptedData != null) {
      Share.share(encryptedData);
    }
  }


  void _addCategory(String name) {
    setState(() {
      _categories.add(Category(name: name, items: []));
    });
    _saveData();
  }

  void _addToDoItem(String title, Category category) {
    setState(() {
      category.items.add(ToDoItem(title: title));
    });
    _saveData();
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        Category category = _categories[index];
        // Sort the items so that completed tasks are listed at the end
        category.items.sort((a, b) => a.isDone.toString().compareTo(b.isDone.toString()));
        return ExpansionTile(
          title: Text(category.name),
          children: [
            // Add a button to create a new to-do item
            TextButton(
              onPressed: () async {
                TextEditingController itemNameController =
                    TextEditingController();
                await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Add Item'),
                      content: TextField(
                        controller: itemNameController,
                        decoration:
                            const InputDecoration(labelText: 'Item Name'),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('Add'),
                          onPressed: () {
                            _addToDoItem(
                                itemNameController.text.trim(), category);
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('Add Item'),
            ),
            // Display the list of to-do items with strike-through for completed tasks
            ...category.items.map<Widget>((item) {
              return CheckboxListTile(
                title: Text(
                  item.title,
                  style: item.isDone
                      ? TextStyle(decoration: TextDecoration.lineThrough)
                      : null,
                ),
                value: item.isDone,
                onChanged: (bool? value) {
                  setState(() {
                    item.isDone = value!;
                  });
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List App'),
      ),
      body: Column(
        children: [
          // Add a button to create a new category
          TextButton(
            onPressed: () async {
              TextEditingController categoryNameController = TextEditingController();
              await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Add Category'),
                    content: TextField(
                      controller: categoryNameController,
                      decoration: const InputDecoration(labelText: 'Category Name'),
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('Add'),
                        onPressed: () {
                          _addCategory(categoryNameController.text.trim());
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
            child: const Text('Add Category'),
          ),
          TextButton(
            onPressed: _shareData,
            child: const Text('Share Data'),
          ),
          // Display the list of categories
          Expanded(
            child: _buildCategoryList(),
          ),
        ],
      ),
    );
  }
}