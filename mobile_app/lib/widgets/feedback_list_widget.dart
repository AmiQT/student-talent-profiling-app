import 'package:flutter/material.dart';

class FeedbackListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> feedbackList;

  const FeedbackListWidget({
    super.key,
    required this.feedbackList,
  });

  @override
  Widget build(BuildContext context) {
    if (feedbackList.isEmpty) {
      return const Center(
        child: Text(
          'No feedback available',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: feedbackList.length,
      itemBuilder: (context, index) {
        final feedback = feedbackList[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.feedback,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              feedback['comment'] ?? 'No comment',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feedback['lecturerName'] != null)
                  Text(
                    'By: ${feedback['lecturerName']}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                if (feedback['timestamp'] != null)
                  Text(
                    '${feedback['timestamp']}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (feedback['rating'] != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (starIndex) {
                      return Icon(
                        starIndex < (feedback['rating'] ?? 0)
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
