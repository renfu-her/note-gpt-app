import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownViewer extends StatelessWidget {
  final String markdownData;
  final ScrollController? scrollController;

  const MarkdownViewer({
    Key? key,
    required this.markdownData,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              maxHeight: constraints.maxHeight,
            ),
            child: Markdown(
              data: markdownData,
              controller: scrollController,
              selectable: true,
              softLineBreak: true,
              shrinkWrap: false,
              physics: const ClampingScrollPhysics(),
              onTapLink: (text, href, title) async {
                if (href != null) {
                  final url = Uri.parse(href);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                }
              },
              styleSheet: MarkdownStyleSheet(
                h1: Theme.of(context).textTheme.headlineLarge,
                h2: Theme.of(context).textTheme.headlineMedium,
                h3: Theme.of(context).textTheme.headlineSmall,
                h4: Theme.of(context).textTheme.titleLarge,
                h5: Theme.of(context).textTheme.titleMedium,
                h6: Theme.of(context).textTheme.titleSmall,
                p: Theme.of(context).textTheme.bodyLarge,
                code: TextStyle(
                  backgroundColor: Colors.grey[200],
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                codeblockPadding: const EdgeInsets.all(8),
                blockquote: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                blockquotePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Colors.grey[400]!,
                      width: 4,
                    ),
                  ),
                ),
                tableHead: TextStyle(fontWeight: FontWeight.bold),
                tableBody: Theme.of(context).textTheme.bodyMedium,
                tableBorder: TableBorder.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                tableCellsPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                listBullet: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        },
      ),
    );
  }
} 