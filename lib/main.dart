import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert'; 
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FlashCardApp());
}

class FlashCardApp extends StatelessWidget {
  const FlashCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flashcards with Subject Menu',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SubjectMenuScreen(),
    );
  }
}

class Subject {
  String name;
  List<FlashCard> flashcards;

  Subject({required this.name, required this.flashcards});

  Map<String, dynamic> toJson() => {
        'name': name,
        'flashcards': flashcards.map((f) => f.toJson()).toList(),
      };

  static Subject fromJson(Map<String, dynamic> json) {
    return Subject(
      name: json['name'],
      flashcards: (json['flashcards'] as List)
          .map((f) => FlashCard.fromJson(f))
          .toList(),
    );
  }
}

class FlashCard {
  String? question;
  String? answer;
  String? imageUrl;

  FlashCard({this.question, this.answer, this.imageUrl});

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'imageUrl': imageUrl,
      };

  static FlashCard fromJson(Map<String, dynamic> json) {
    return FlashCard(
      question: json['question'],
      answer: json['answer'],
      imageUrl: json['imageUrl'],
    );
  }
}

class SubjectMenuScreen extends StatefulWidget {
  const SubjectMenuScreen({super.key});

  @override
  _SubjectMenuScreenState createState() => _SubjectMenuScreenState();
}

class _SubjectMenuScreenState extends State<SubjectMenuScreen> {
  List<Subject> subjects = [];
  TextEditingController subjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _saveSubjects() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> subjectJsonList =
        subjects.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('subjects', subjectJsonList);
  }

  Future<void> _loadSubjects() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? subjectJsonList = prefs.getStringList('subjects');
    if (subjectJsonList != null) {
      setState(() {
        subjects = subjectJsonList
            .map((s) => Subject.fromJson(jsonDecode(s)))
            .toList();
      });
    }
  }

  void _addSubject() {
    if (subjectController.text.isNotEmpty) {
      setState(() {
        subjects.add(Subject(name: subjectController.text, flashcards: []));
        subjectController.clear();
        _saveSubjects(); 
      });
    }
  }

  void _deleteSubject(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: const Text('Are you sure you want to delete this subject?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                subjects.removeAt(index);
                _saveSubjects(); 
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose or Add a Subject')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(subjects[index].name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteSubject(index),
                      ),
                      const Icon(Icons.arrow_forward),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FlashCardScreen(
                          subject: subjects[index],
                          onUpdate: _saveSubjects,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'New Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addSubject,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FlashCardScreen extends StatefulWidget {
  final Subject subject;
  final VoidCallback onUpdate;

  const FlashCardScreen({super.key, required this.subject, required this.onUpdate});

  @override
  _FlashCardScreenState createState() => _FlashCardScreenState();
}

class _FlashCardScreenState extends State<FlashCardScreen> {
  TextEditingController questionController = TextEditingController();
  TextEditingController answerController = TextEditingController();
  String? imagePath;
  bool isRandom = false;

  @override
  Widget build(BuildContext context) {
    List<FlashCard> flashcards = widget.subject.flashcards;
    if (isRandom) flashcards.shuffle(Random());

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject.name} Flashcards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddFlashCardDialog,
          ),
          IconButton(
            icon: Icon(isRandom ? Icons.shuffle_on : Icons.shuffle),
            onPressed: () {
              setState(() {
                isRandom = !isRandom;
                widget.onUpdate(); 
              });
            },
          ),
        ],
      ),
      body: flashcards.isEmpty
          ? const Center(child: Text('No flashcards added yet.'))
          : PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: flashcards.length,
              itemBuilder: (context, index) {
                return FlashCardWidget(
                  flashCard: flashcards[index],
                  onEdit: () => _showEditFlashCardDialog(index),
                );
              },
            ),
    );
  }

  void _showAddFlashCardDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Flashcard'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Question (Optional)'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile =
                      await picker.getImage(source: ImageSource.gallery);
                  setState(() {
                    imagePath = pickedFile?.path;
                  });
                },
                child: const Text('Add Image to Question (Optional)'),
              ),
              if (imagePath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(
                    File(imagePath!),
                    height: 150,
                    width: 10,
                    fit: BoxFit.cover,
                  ),
                ),
              TextField(
                controller: answerController,
                decoration: const InputDecoration(labelText: 'Answer (Optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.subject.flashcards.add(FlashCard(
                    question: questionController.text.isNotEmpty
                        ? questionController.text
                        : null,
                    answer: answerController.text.isNotEmpty
                        ? answerController.text
                        : null,
                    imageUrl: imagePath,
                  ));
                  widget.onUpdate();
                  questionController.clear();
                  answerController.clear();
                  imagePath = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditFlashCardDialog(int index) {
    FlashCard flashcard = widget.subject.flashcards[index];
    questionController.text = flashcard.question ?? '';
    answerController.text = flashcard.answer ?? '';
    imagePath = flashcard.imageUrl;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Flashcard'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Question (Optional)'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile =
                      await picker.getImage(source: ImageSource.gallery);
                  setState(() {
                    imagePath = pickedFile?.path;
                  });
                },
                child: const Text('Add Image to Question (Optional)'),
              ),
              if (imagePath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(
                    File(imagePath!),
                    height: 150,
                    width: 10,
                    fit: BoxFit.cover,
                  ),
                ),
              TextField(
                controller: answerController,
                decoration: const InputDecoration(labelText: 'Answer (Optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.subject.flashcards[index] = FlashCard(
                    question: questionController.text.isNotEmpty
                        ? questionController.text
                        : null,
                    answer: answerController.text.isNotEmpty
                        ? answerController.text
                        : null,
                    imageUrl: imagePath,
                  );
                  widget.onUpdate();
                  questionController.clear();
                  answerController.clear();
                  imagePath = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}

class FlashCardWidget extends StatelessWidget {
  final FlashCard flashCard;
  final VoidCallback onEdit;

  const FlashCardWidget({super.key, required this.flashCard, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FlipCard(
        direction: FlipDirection.HORIZONTAL,
        front: SizedBox(
          width: 300,
          height: 400,
          child: Card(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (flashCard.imageUrl != null)
                  Image.file(
                    File(flashCard.imageUrl!),
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                if (flashCard.question != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      flashCard.question!,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
        back: SizedBox(
          width: 300,
          height: 400,
          child: Card(
            child: Stack(
              children: [
                Center(
                  child: Text(
                    flashCard.answer ?? 'No Answer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: onEdit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
