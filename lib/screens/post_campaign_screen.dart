import 'package:flutter/material.dart';

class PostCampaignScreen extends StatefulWidget {
  const PostCampaignScreen({super.key});

  @override
  State<PostCampaignScreen> createState() => _PostCampaignScreenState();
}

class _PostCampaignScreenState extends State<PostCampaignScreen> {
  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final dateController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post Campaign")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _textField("Campaign Title", titleController),
            _textField("Location", locationController),
            _textField("Date", dateController),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (titleController.text.isNotEmpty &&
                    locationController.text.isNotEmpty &&
                    dateController.text.isNotEmpty) {
                  Navigator.pop(context, {
                    "title": titleController.text,
                    "location": locationController.text,
                    "date": dateController.text,
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text("Add Campaign"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
